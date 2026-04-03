import EventKit
import Foundation

@MainActor
class CalendarService: ObservableObject {
    @Published var freeSlots: [FreeTimeSlot] = []
    @Published var hasCalendarAccess: Bool = false
    @Published var accessDeniedMessage: String?

    private let eventStore = EKEventStore()

    func requestAccess() {
        Task {
            do {
                let granted = try await eventStore.requestFullAccessToEvents()
                hasCalendarAccess = granted
                if !granted {
                    accessDeniedMessage = "Calendar access helps us find the best times for outdoor activities."
                }
            } catch {
                hasCalendarAccess = false
                accessDeniedMessage = "Unable to access calendar."
            }
        }
    }

    func findFreeSlots(forDate date: Date = Date()) -> [FreeTimeSlot] {
        guard hasCalendarAccess else { return generateDefaultSlots(for: date) }

        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return generateDefaultSlots(for: date)
        }

        // Get all events for the day
        let predicate = eventStore.predicateForEvents(withStart: dayStart, end: dayEnd, calendars: nil)
        let events = eventStore.events(matching: predicate)
            .filter { !$0.isAllDay }
            .sorted { $0.startDate < $1.startDate }

        // Define the window we care about: 5am - 11pm
        let wakeHour = 5
        let sleepHour = 23
        guard let windowStart = calendar.date(bySettingHour: wakeHour, minute: 0, second: 0, of: date),
              let windowEnd = calendar.date(bySettingHour: sleepHour, minute: 0, second: 0, of: date)
        else { return generateDefaultSlots(for: date) }

        // Start from now if today, or from wake time if future
        let effectiveStart = calendar.isDateInToday(date) ? max(Date(), windowStart) : windowStart

        // Find gaps between events
        var slots: [FreeTimeSlot] = []
        var cursor = effectiveStart

        for event in events {
            let eventStart = max(event.startDate, effectiveStart)
            let eventEnd = event.endDate ?? eventStart

            if eventStart > cursor {
                let duration = eventStart.timeIntervalSince(cursor)
                if duration >= 1800 { // At least 30 min
                    slots.append(FreeTimeSlot(
                        start: cursor,
                        end: eventStart,
                        source: .calendar
                    ))
                }
            }
            cursor = max(cursor, eventEnd)
        }

        // Remaining time after last event
        if cursor < windowEnd {
            let duration = windowEnd.timeIntervalSince(cursor)
            if duration >= 1800 {
                slots.append(FreeTimeSlot(
                    start: cursor,
                    end: windowEnd,
                    source: .calendar
                ))
            }
        }

        freeSlots = slots
        return slots
    }

    private func generateDefaultSlots(for date: Date) -> [FreeTimeSlot] {
        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(date)
        let now = Date()

        // Without calendar, create time blocks from 5am to 11pm
        let blocks: [(Int, Int)] = [
            (5, 7),    // Early morning
            (7, 9),    // Morning
            (9, 11),   // Late morning
            (11, 13),  // Midday
            (13, 15),  // Early afternoon
            (15, 17),  // Afternoon
            (17, 19),  // Late afternoon
            (19, 21),  // Evening
            (21, 23),  // Night
        ]

        var slots: [FreeTimeSlot] = []
        for (startH, endH) in blocks {
            guard let start = calendar.date(bySettingHour: startH, minute: 0, second: 0, of: date),
                  let end = calendar.date(bySettingHour: endH, minute: 0, second: 0, of: date)
            else { continue }

            if isToday && end <= now { continue }
            let effectiveStart = isToday ? max(start, now) : start

            slots.append(FreeTimeSlot(
                start: effectiveStart,
                end: end,
                source: .default
            ))
        }

        freeSlots = slots
        return slots
    }
}

struct FreeTimeSlot: Identifiable {
    let id = UUID()
    let start: Date
    let end: Date
    let source: SlotSource

    var duration: TimeInterval {
        end.timeIntervalSince(start)
    }

    var durationMinutes: Int {
        Int(duration / 60)
    }

    enum SlotSource {
        case calendar
        case `default`
    }
}
