//
//  WaddiLiveActivityLiveActivity.swift
//  WaddiLiveActivity
//

import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Palette

private enum Waddy {
    static let teal     = Color(red: 0.075, green: 0.306, blue: 0.290) // #134E4A
    static let tealDeep = Color(red: 0.043, green: 0.216, blue: 0.204) // #0B3734
    static let mint     = Color(red: 0.118, green: 0.949, blue: 0.627) // #1EF2A0
    static let inkHigh  = Color.white
    static let inkMid   = Color.white.opacity(0.72)
    static let inkLow   = Color.white.opacity(0.42)
    static let track    = Color.white.opacity(0.16)
}

// MARK: - Widget

@available(iOS 16.2, *)
struct WaddiLiveActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: OrderTrackingAttributes.self) { context in
            LockScreenView(state: context.state, attributes: context.attributes)
                .activityBackgroundTint(Waddy.tealDeep)
                .activitySystemActionForegroundColor(Waddy.inkHigh)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        StoreLogoView(url: context.attributes.storeLogoUrl, size: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(context.state.storeName ?? "Waddy")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Text(context.state.subtitle)
                                .font(.system(size: 11))
                                .foregroundColor(Waddy.inkMid)
                                .lineLimit(1)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(context.state.status == "delivered" ? "STATUS" : "ETA")
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(1.0)
                            .foregroundColor(Waddy.inkLow)
                        Text(context.state.etaText ?? shortStatus(context.state.status))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(Waddy.mint)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    StageBar(status: context.state.status)
                        .padding(.top, 8)
                }
            } compactLeading: {
                Image(systemName: statusIcon(context.state.status, context.state.subStatus))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Waddy.mint)
            } compactTrailing: {
                Text(compactEta(context.state))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(Waddy.mint)
                    .lineLimit(1)
            } minimal: {
                Image(systemName: statusIcon(context.state.status, context.state.subStatus))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Waddy.mint)
            }
            .keylineTint(Waddy.mint)
        }
    }
}

// MARK: - Lock Screen

@available(iOS 16.2, *)
struct LockScreenView: View {
    let state: OrderTrackingAttributes.ContentState
    let attributes: OrderTrackingAttributes

    private var isDelivered: Bool { state.status == "delivered" }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Header: store identity | Waddy wordmark
            HStack(spacing: 6) {
                StoreLogoView(url: attributes.storeLogoUrl, size: 18)
                Text(state.storeName ?? "Waddy")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Waddy.inkMid)
                    .lineLimit(1)
                Spacer()
                Image("WaddyLogo")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(height: 15)
                    .foregroundColor(Waddy.mint)
            }

            // Hero: kicker + big line + subtitle | status chip
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    if !isDelivered, state.etaText != nil {
                        Text("ARRIVING IN")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1.2)
                            .foregroundColor(Waddy.inkLow)
                    }
                    heroLine
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(state.subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(Waddy.inkMid)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                StatusChip(icon: statusIcon(state.status, state.subStatus))
            }

            StageBar(status: state.status)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            LinearGradient(
                colors: [Waddy.teal, Waddy.tealDeep],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var heroLine: Text {
        if isDelivered {
            return Text(state.title.isEmpty ? "Delivered!" : state.title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(Waddy.mint)
        } else if let eta = state.etaText {
            return Text(eta)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(Waddy.mint)
        } else {
            return Text(state.title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(Waddy.inkHigh)
        }
    }
}

// MARK: - Status Chip

struct StatusChip: View {
    let icon: String

    var body: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Waddy.mint.opacity(0.14))
            .frame(width: 46, height: 46)
            .overlay(
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Waddy.mint)
            )
    }
}

// MARK: - Stage Bar (4 segments + labels)

struct StageBar: View {
    let status: String

    private static let labels = ["Placed", "Preparing", "On the way", "Delivered"]

    // 1-based index of the current stage
    private var current: Int {
        switch status {
        case "pending", "accepted", "confirmed": return 1
        case "processing":                       return 2
        case "handover", "picked_up":            return 3
        case "delivered":                        return 4
        default:                                 return 1
        }
    }

    var body: some View {
        VStack(spacing: 5) {
            HStack(spacing: 4) {
                ForEach(0..<4, id: \.self) { i in
                    Capsule()
                        .fill(segmentStyle(i))
                        .frame(height: 4)
                }
            }
            HStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { i in
                    Text(Self.labels[i])
                        .font(.system(size: 10, weight: i == current - 1 ? .semibold : .medium))
                        .foregroundColor(labelColor(i))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: alignment(i))
                }
            }
        }
    }

    private func segmentStyle(_ i: Int) -> AnyShapeStyle {
        if i < current - 1 || status == "delivered" {
            return AnyShapeStyle(Waddy.mint)
        } else if i == current - 1 {
            // Current stage: gradient fade shows "in progress"
            return AnyShapeStyle(LinearGradient(
                colors: [Waddy.mint, Waddy.mint.opacity(0.35)],
                startPoint: .leading, endPoint: .trailing
            ))
        }
        return AnyShapeStyle(Waddy.track)
    }

    private func labelColor(_ i: Int) -> Color {
        if i == current - 1 { return Waddy.mint }
        if i < current - 1  { return Waddy.inkMid }
        return Waddy.inkLow
    }

    private func alignment(_ i: Int) -> Alignment {
        if i == 0 { return .leading }
        if i == 3 { return .trailing }
        return .center
    }
}

// MARK: - Store Logo

struct StoreLogoView: View {
    let url: String?
    let size: CGFloat

    var body: some View {
        Group {
            if let urlString = url, let imageUrl = URL(string: urlString) {
                AsyncImage(url: imageUrl) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    } else { placeholder }
                }
            } else { placeholder }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 0.5))
    }

    private var placeholder: some View {
        Circle().fill(Waddy.mint.opacity(0.18))
            .overlay(
                Text("W")
                    .font(.system(size: size * 0.45, weight: .bold, design: .rounded))
                    .foregroundColor(Waddy.mint)
            )
    }
}

// MARK: - Helpers

private func statusIcon(_ status: String, _ subStatus: String?) -> String {
    switch status {
    case "pending":               return "doc.text.fill"
    case "accepted", "confirmed": return "checkmark.circle.fill"
    case "processing":            return "flame.fill"
    case "handover":              return "shippingbox.fill"
    case "picked_up":
        if subStatus == "nearby" || subStatus == "arrived" { return "location.fill" }
        return "bicycle"
    case "delivered":             return "checkmark.seal.fill"
    default:                      return "clock.fill"
    }
}

private func shortStatus(_ status: String) -> String {
    switch status {
    case "pending":               return "Pending"
    case "accepted", "confirmed": return "Confirmed"
    case "processing":            return "Cooking"
    case "handover":              return "Ready"
    case "picked_up":             return "On way"
    case "delivered":             return "Done"
    default:                      return "..."
    }
}

@available(iOS 16.2, *)
private func compactEta(_ state: OrderTrackingAttributes.ContentState) -> String {
    if state.status == "delivered" { return "Done" }
    if let minutes = state.etaMinutes { return "\(minutes)m" }
    return shortStatus(state.status)
}
