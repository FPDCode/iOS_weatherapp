import Foundation
import AuthenticationServices

/// Service for Google Calendar integration.
/// Uses Google's OAuth 2.0 to sign in, then fetches calendar events
/// via the Google Calendar REST API.
@MainActor
class GoogleCalendarService: ObservableObject {
    static let shared = GoogleCalendarService()

    @Published var isSignedIn: Bool = false
    @Published var userEmail: String?
    @Published var events: [GoogleCalendarEvent] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // OAuth config — user must set these in Settings or via a plist
    private let clientID: String = "" // Set via GoogleService-Info.plist or Settings
    private let redirectURI = "com.weatherapp.WeatherBetter:/oauth2callback"
    private let scopes = "https://www.googleapis.com/auth/calendar.readonly"

    private var accessToken: String? {
        get { UserDefaults.standard.string(forKey: "google_access_token") }
        set { UserDefaults.standard.set(newValue, forKey: "google_access_token") }
    }

    private var refreshToken: String? {
        get { UserDefaults.standard.string(forKey: "google_refresh_token") }
        set { UserDefaults.standard.set(newValue, forKey: "google_refresh_token") }
    }

    private var tokenExpiry: Date? {
        get { UserDefaults.standard.object(forKey: "google_token_expiry") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "google_token_expiry") }
    }

    init() {
        isSignedIn = accessToken != nil && refreshToken != nil
        if let email = UserDefaults.standard.string(forKey: "google_user_email") {
            userEmail = email
        }
    }

    // MARK: - Sign In via ASWebAuthenticationSession

    func signIn(from anchor: ASPresentationAnchor) {
        guard !clientID.isEmpty else {
            errorMessage = "Google Client ID not configured. Add it in Settings."
            return
        }

        let authURL = buildAuthURL()
        guard let url = URL(string: authURL) else { return }

        let session = ASWebAuthenticationSession(url: url, callbackURLScheme: "com.weatherapp.WeatherBetter") { [weak self] callbackURL, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                guard let callbackURL,
                      let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                        .queryItems?.first(where: { $0.name == "code" })?.value else {
                    self.errorMessage = "Failed to get authorization code"
                    return
                }
                await self.exchangeCodeForTokens(code)
            }
        }
        session.prefersEphemeralWebBrowserSession = false
        session.start()
    }

    // MARK: - Sign Out

    func signOut() {
        accessToken = nil
        refreshToken = nil
        tokenExpiry = nil
        userEmail = nil
        UserDefaults.standard.removeObject(forKey: "google_user_email")
        isSignedIn = false
        events = []
    }

    // MARK: - Fetch Events

    func fetchTodayEvents() async {
        guard let token = await validAccessToken() else {
            errorMessage = "Not signed in to Google"
            return
        }

        isLoading = true
        defer { isLoading = false }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        guard let endOfDay = calendar.date(byAdding: .day, value: 2, to: startOfDay) else { return }

        let dateFormatter = ISO8601DateFormatter()
        let timeMin = dateFormatter.string(from: startOfDay)
        let timeMax = dateFormatter.string(from: endOfDay)

        var urlComponents = URLComponents(string: "https://www.googleapis.com/calendar/v3/calendars/primary/events")!
        urlComponents.queryItems = [
            URLQueryItem(name: "timeMin", value: timeMin),
            URLQueryItem(name: "timeMax", value: timeMax),
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime"),
            URLQueryItem(name: "maxResults", value: "50"),
        ]

        guard let url = urlComponents.url else { return }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                errorMessage = "Failed to fetch calendar events"
                return
            }

            let decoded = try JSONDecoder().decode(GoogleCalendarResponse.self, from: data)
            events = decoded.items?.compactMap { item in
                guard let start = item.start?.dateTime ?? item.start?.date,
                      let end = item.end?.dateTime ?? item.end?.date else { return nil }

                let dateFmt = ISO8601DateFormatter()
                dateFmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

                let startDate = dateFmt.date(from: start) ?? ISO8601DateFormatter().date(from: start)
                let endDate = dateFmt.date(from: end) ?? ISO8601DateFormatter().date(from: end)

                guard let s = startDate, let e = endDate else { return nil }

                return GoogleCalendarEvent(
                    id: item.id ?? UUID().uuidString,
                    title: item.summary ?? "Untitled",
                    startDate: s,
                    endDate: e,
                    isAllDay: item.start?.date != nil
                )
            } ?? []
        } catch {
            errorMessage = "Calendar error: \(error.localizedDescription)"
        }
    }

    // MARK: - Token Management

    private func validAccessToken() async -> String? {
        if let token = accessToken, let expiry = tokenExpiry, Date() < expiry {
            return token
        }
        // Try refresh
        guard let refresh = refreshToken else { return nil }
        return await refreshAccessToken(refresh)
    }

    private func exchangeCodeForTokens(_ code: String) async {
        guard let url = URL(string: "https://oauth2.googleapis.com/token") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = "code=\(code)&client_id=\(clientID)&redirect_uri=\(redirectURI)&grant_type=authorization_code"
        request.httpBody = body.data(using: .utf8)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let tokenResponse = try JSONDecoder().decode(GoogleTokenResponse.self, from: data)

            accessToken = tokenResponse.accessToken
            refreshToken = tokenResponse.refreshToken ?? refreshToken
            tokenExpiry = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn ?? 3600))
            isSignedIn = true

            // Fetch user email
            await fetchUserEmail()
            await fetchTodayEvents()
        } catch {
            errorMessage = "Token exchange failed: \(error.localizedDescription)"
        }
    }

    private func refreshAccessToken(_ refreshToken: String) async -> String? {
        guard let url = URL(string: "https://oauth2.googleapis.com/token") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = "refresh_token=\(refreshToken)&client_id=\(clientID)&grant_type=refresh_token"
        request.httpBody = body.data(using: .utf8)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let tokenResponse = try JSONDecoder().decode(GoogleTokenResponse.self, from: data)

            accessToken = tokenResponse.accessToken
            tokenExpiry = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn ?? 3600))
            return tokenResponse.accessToken
        } catch {
            isSignedIn = false
            return nil
        }
    }

    private func fetchUserEmail() async {
        guard let token = accessToken else { return }
        guard let url = URL(string: "https://www.googleapis.com/oauth2/v2/userinfo") else { return }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let email = json["email"] as? String {
                userEmail = email
                UserDefaults.standard.set(email, forKey: "google_user_email")
            }
        } catch {}
    }

    // MARK: - Helpers

    private func buildAuthURL() -> String {
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scopes),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
        ]
        return components.url!.absoluteString
    }

    /// Convert Google Calendar events to FreeTimeSlots by finding gaps
    func freeSlots(forDate date: Date = Date()) -> [FreeTimeSlot] {
        let calendar = Calendar.current
        let wakeHour = 6, sleepHour = 22

        guard let windowStart = calendar.date(bySettingHour: wakeHour, minute: 0, second: 0, of: date),
              let windowEnd = calendar.date(bySettingHour: sleepHour, minute: 0, second: 0, of: date) else { return [] }

        let effectiveStart = calendar.isDateInToday(date) ? max(Date(), windowStart) : windowStart
        let todayEvents = events.filter { !$0.isAllDay && calendar.isDate($0.startDate, inSameDayAs: date) }
            .sorted { $0.startDate < $1.startDate }

        var slots: [FreeTimeSlot] = []
        var cursor = effectiveStart

        for event in todayEvents {
            let eventStart = max(event.startDate, effectiveStart)
            if eventStart > cursor {
                let duration = eventStart.timeIntervalSince(cursor)
                if duration >= 1800 {
                    slots.append(FreeTimeSlot(start: cursor, end: eventStart, source: .calendar))
                }
            }
            cursor = max(cursor, event.endDate)
        }

        if cursor < windowEnd {
            let duration = windowEnd.timeIntervalSince(cursor)
            if duration >= 1800 {
                slots.append(FreeTimeSlot(start: cursor, end: windowEnd, source: .calendar))
            }
        }

        return slots
    }
}

// MARK: - Google API Models

struct GoogleCalendarResponse: Codable {
    let items: [GoogleCalendarItem]?
}

struct GoogleCalendarItem: Codable {
    let id: String?
    let summary: String?
    let start: GoogleDateTime?
    let end: GoogleDateTime?
}

struct GoogleDateTime: Codable {
    let dateTime: String?
    let date: String?
}

struct GoogleTokenResponse: Codable {
    let accessToken: String?
    let refreshToken: String?
    let expiresIn: Int?
    let tokenType: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
}

struct GoogleCalendarEvent: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
}
