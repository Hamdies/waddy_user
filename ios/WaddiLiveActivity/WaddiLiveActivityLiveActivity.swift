//
//  WaddiLiveActivityLiveActivity.swift
//  WaddiLiveActivity
//

import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Widget

@available(iOS 16.2, *)
struct WaddiLiveActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: OrderTrackingAttributes.self) { context in
            LockScreenView(state: context.state, attributes: context.attributes)
                .activityBackgroundTint(Color.white)
                .activitySystemActionForegroundColor(Color.black)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        StoreLogoView(url: context.attributes.storeLogoUrl, size: 30)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(context.state.storeName ?? "Waddy")
                                .font(.caption).fontWeight(.semibold)
                                .foregroundColor(.primary).lineLimit(1)
                            Text(context.state.subtitle)
                                .font(.caption2).foregroundColor(.secondary).lineLimit(1)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let eta = context.state.etaText {
                        Text(eta).font(.caption).fontWeight(.bold).foregroundColor(waddiGreen)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    StepTrack(status: context.state.status, step: context.state.step)
                        .padding(.top, 4)
                }
            } compactLeading: {
                StoreLogoView(url: context.attributes.storeLogoUrl, size: 20)
            } compactTrailing: {
                Text(context.state.etaText ?? shortStatus(context.state.status))
                    .font(.caption2).fontWeight(.bold).foregroundColor(waddiGreen)
            } minimal: {
                Image(systemName: statusIcon(context.state.status, context.state.subStatus))
                    .font(.caption2).foregroundColor(waddiGreen)
            }
        }
    }
}

// MARK: - Lock Screen View

@available(iOS 16.2, *)
struct LockScreenView: View {
    let state: OrderTrackingAttributes.ContentState
    let attributes: OrderTrackingAttributes

    var body: some View {
        // VStack with zero spacing so the top bar touches the edge
        VStack(alignment: .leading, spacing: 0) {

            // ── Top accent bar (no padding, flush to card top) ────────
            Rectangle()
                .fill(waddiGreen)
                .frame(height: 3)
                .frame(maxWidth: .infinity)

            // ── Main content ──────────────────────────────────────────
            VStack(alignment: .leading, spacing: 0) {

                // Row 1: Store logo + name  |  Waddy logo
                HStack(alignment: .center) {
                    StoreLogoView(url: attributes.storeLogoUrl, size: 20)
                        .padding(.trailing, 4)
                    Text(state.storeName ?? "Restaurant")
                        .font(.caption2).fontWeight(.medium)
                        .foregroundColor(Color(.systemGray))
                        .lineLimit(1)
                    Spacer()
                    Image("WaddyLogo")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(height: 20)
                        .foregroundColor(waddiGreen)
                }
                .padding(.bottom, 9)

                // Row 2: Status subtitle + ETA  |  emoji
                HStack(alignment: .center, spacing: 0) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(state.subtitle)
                            .font(.caption)
                            .foregroundColor(Color(.systemGray))
                            .lineLimit(1)
                        etaLine(state: state)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    Text(statusEmoji(state.status, state.subStatus))
                        .font(.system(size: 44))
                        .frame(width: 54, height: 52, alignment: .center)
                }
                .padding(.bottom, 10)

                // Row 3: 4-step track
                StepTrack(status: state.status, step: state.step)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
    }

    // "Arriving in" (black) + "22–32 min" (green bold) — only for active statuses
    private func etaLine(state: OrderTrackingAttributes.ContentState) -> Text {
        if state.status == "delivered" {
            return Text("Order delivered! ")
                .font(.title3).fontWeight(.bold).foregroundColor(.black)
            + Text("Enjoy your meal")
                .font(.caption).foregroundColor(Color(.systemGray))
        } else if let eta = state.etaText {
            return Text("Arriving in ")
                .font(.title3).fontWeight(.bold).foregroundColor(.black)
            + Text(eta)
                .font(.title3).fontWeight(.bold).foregroundColor(waddiGreen)
        } else {
            // No ETA yet — show title only (e.g. "Order Placed", "Order Confirmed")
            return Text(state.title)
                .font(.title3).fontWeight(.bold).foregroundColor(.black)
        }
    }
}

// MARK: - 4-Node Step Track

struct StepTrack: View {
    let status: String
    let step: Int

    // 1 = Order placed (node 1 active), 2 = Cooking, 3 = On Way, 4 = Done
    private var activeCount: Int {
        switch status {
        case "pending":               return 1
        case "accepted", "confirmed": return 1
        case "processing":            return 2
        case "handover":              return 3
        case "picked_up":             return 3
        case "delivered":             return 4
        default:                      return 1
        }
    }

    private let nodes: [(icon: String, label: String)] = [
        ("fork.knife",   "Order"),
        ("flame.fill",   "Cook"),
        ("bicycle",      "Ride"),
        ("house.fill",   "Done"),
    ]

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(0..<nodes.count, id: \.self) { i in
                let isActive  = i < activeCount
                let isCurrent = i == activeCount - 1

                // Node + label stacked
                VStack(spacing: 4) {
                    ZStack {
                        if isCurrent {
                            Circle()
                                .fill(waddiGreen.opacity(0.13))
                                .frame(width: 34, height: 34)
                        }
                        Circle()
                            .fill(isActive ? waddiGreen : Color(white: 0.88))
                            .frame(width: 24, height: 24)
                        Image(systemName: nodes[i].icon)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(isActive ? .white : Color(white: 0.65))
                    }
                    .frame(width: 34, height: 34)

                    Text(nodes[i].label)
                        .font(.system(size: 9, weight: isCurrent ? .bold : .regular))
                        .foregroundColor(isActive ? (isCurrent ? .black : Color(.systemGray)) : Color(white: 0.75))
                        .frame(width: 34, alignment: .center)
                }

                // Connecting line between nodes (vertically centered with the 24pt circle inside 34pt frame)
                if i < nodes.count - 1 {
                    Rectangle()
                        .fill(i < activeCount - 1 ? waddiGreen : Color(white: 0.88))
                        .frame(height: 2.5)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 16) // center of 34pt node frame
                }
            }
        }
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
        .overlay(Circle().stroke(Color(white: 0.88), lineWidth: 0.5))
    }

    private var placeholder: some View {
        Circle().fill(waddiGreen.opacity(0.12))
            .overlay(
                Text("W")
                    .font(.system(size: size * 0.45, weight: .bold))
                    .foregroundColor(waddiGreen)
            )
    }
}

// MARK: - Helpers

private var waddiGreen: Color { Color(red: 0.075, green: 0.306, blue: 0.290) }

private func statusEmoji(_ status: String, _ subStatus: String?) -> String {
    switch status {
    case "pending":               return "📋"
    case "accepted", "confirmed": return "✅"
    case "processing":            return "🧑‍🍳"
    case "handover":              return "📦"
    case "picked_up":
        if subStatus == "nearby" || subStatus == "arrived" { return "🏠" }
        return "🛵"
    case "delivered":             return "🎉"
    default:                      return "⏱️"
    }
}

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
