import SwiftUI

struct WeatherWarningsView: View {
    let nwsAlerts: [NWSAlert]
    let smartWarnings: [SmartWarning]
    @State private var expandedAlertId: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // NWS Official Alerts (highest priority)
            if !nwsAlerts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.shield.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                        Text("OFFICIAL ALERTS")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.red)
                            .tracking(1)
                    }

                    ForEach(nwsAlerts) { alert in
                        NWSAlertRow(
                            alert: alert,
                            isExpanded: expandedAlertId == alert.id,
                            onTap: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    expandedAlertId = expandedAlertId == alert.id ? nil : alert.id
                                }
                            }
                        )
                    }
                }
            }

            // Smart Warnings
            if !smartWarnings.isEmpty {
                if !nwsAlerts.isEmpty {
                    Divider().background(.white.opacity(0.15))
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "brain.head.profile")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        Text("SMART ALERTS")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                            .tracking(1)
                    }

                    ForEach(smartWarnings) { warning in
                        SmartWarningRow(warning: warning)
                    }
                }
            }
        }
    }
}

// MARK: - NWS Alert Row

struct NWSAlertRow: View {
    let alert: NWSAlert
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header (always visible)
            HStack(spacing: 10) {
                Image(systemName: alert.severity.icon)
                    .font(.body)
                    .foregroundStyle(Color(hex: alert.severity.color))
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(alert.event)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    if let headline = alert.headline {
                        Text(headline)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(isExpanded ? nil : 2)
                    }
                }

                Spacer()

                // Severity badge
                Text(alert.severity.rawValue)
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: alert.severity.color).opacity(0.2))
                    .clipShape(Capsule())
                    .foregroundStyle(Color(hex: alert.severity.color))

                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)

            // Expanded details
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    if let description = alert.description {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let instruction = alert.instruction {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "hand.raised.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                            Text(instruction)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(.orange.opacity(0.08))
                        )
                    }

                    // Timing
                    HStack(spacing: 12) {
                        if let onset = alert.onset {
                            Label(WeatherFormatters.shortTime(onset), systemImage: "clock")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if let expires = alert.expires {
                            Label("Expires \(WeatherFormatters.shortTime(expires))", systemImage: "clock.badge.xmark")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if let sender = alert.senderName {
                            Text(sender)
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .padding(.leading, 34) // Align with text above
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(hex: alert.severity.color).opacity(0.06))
        )
    }
}

// MARK: - Smart Warning Row

struct SmartWarningRow: View {
    let warning: SmartWarning

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: warning.icon)
                .font(.body)
                .symbolRenderingMode(.multicolor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(warning.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(warning.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            // Severity indicator
            Circle()
                .fill(Color(hex: warning.severity.color))
                .frame(width: 8, height: 8)
        }
        .padding(.vertical, 4)
    }
}
