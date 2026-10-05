//
//  WaddiLiveActivityLiveActivity.swift
//  WaddiLiveActivity
//

import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Palette

private enum Waddy {
    static let mint    = Color(hex: 0x1EF2A0)
    static let teal    = Color(hex: 0x134E4A)
    static let coral   = Color(hex: 0xFF6B6B)
    static let card    = Color(hex: 0x1B2322)
    static let inkHigh = Color.white
    static let inkSoft = Color(hex: 0xD5E0DE)
    static let inkMute = Color(hex: 0xB7C8C5)
    /// 3.2:1 on the card — the empty segments still read as a track.
    static let track   = Color.white.opacity(0.35)
}

private extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

// MARK: - Widget

// Layout rule for every presentation: the Waddy mark on the left, the order's
// status on the right.
//
// No `.environment(\.locale)` / `.environment(\.layoutDirection)` overrides:
// widget views are archived and rendered out of process, and regions carrying
// those overrides rendered blank on device. Arabic text still reads right to
// left; the layout mirrors when the phone itself is in Arabic.
@available(iOS 16.2, *)
struct WaddiLiveActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: OrderTrackingAttributes.self) { context in
            let model = TrackingModel(context.state, context.attributes, isStale: context.isStale)
            Group {
                if model.phase == .delivered {
                    DeliveredView(model: model)
                } else {
                    LockScreenView(model: model)
                }
            }
            .activityBackgroundTint(model.phase == .delivered ? Waddy.mint : Waddy.card)
            .activitySystemActionForegroundColor(model.phase == .delivered ? Waddy.teal : Waddy.inkHigh)
            .widgetURL(model.url)
        } dynamicIsland: { context in
            let model = TrackingModel(context.state, context.attributes, isStale: context.isStale)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    LogoTile(size: 44, corner: nil)
                        .padding(.leading, 4)
                }
                // Priority: the status gets its full width first; the centre
                // text truncates before the time ever does.
                DynamicIslandExpandedRegion(.trailing, priority: 1) {
                    StatusStack(model: model, main: .system(size: 22, weight: .heavy, design: .rounded))
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(model.merchant)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Waddy.inkSoft)
                        Text(model.title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(model.phase == .delivered ? Waddy.mint : Waddy.inkHigh)
                    }
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("\(model.emoji) \(model.line)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Waddy.inkMute)
                            .lineLimit(1)
                        StepBar(segments: model.segments, height: 5)
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 6)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(model.spoken)
                }
            } compactLeading: {
                LogoTile(size: 24, corner: nil)
            } compactTrailing: {
                CompactStatus(model: model)
            } minimal: {
                ProgressRing(model: model)
                    .accessibilityLabel(model.spoken)
            }
            .keylineTint(Waddy.mint)
            .widgetURL(model.url)
        }
    }
}

// MARK: - Model

/// Everything the views render, derived from the raw order state. The copy is
/// built here rather than taken from `title`/`subtitle` so the app's local
/// updates and the backend's APNs pushes render identically. Titles match the
/// in-app tracker (`od_title_*`) so the two surfaces never disagree. Lines
/// leave the store out: the merchant row above already names it.
@available(iOS 16.2, *)
struct TrackingModel {
    enum Phase { case live, delivered, ended }

    enum Eta {
        case none
        case arriving(Date)
        /// The promise has passed. Keep the promised time, say it's late.
        case late(Date)
        /// The rider is at the door.
        case here
    }

    enum Segment { case done, current, todo, halted }

    let phase: Phase
    let rtl: Bool
    let merchant: String
    let title: String
    let line: String
    /// Stage emoji, shown before the line and next to the ETA in the island.
    let emoji: String
    let segments: [Segment]
    /// 0…1 for the minimal Dynamic Island ring.
    let ringProgress: Double
    let eta: Eta
    let url: URL?
    /// One VoiceOver sentence for the whole activity.
    let spoken: String

    private let takeAway: Bool

    init(_ state: OrderTrackingAttributes.ContentState, _ attributes: OrderTrackingAttributes, isStale: Bool) {
        let rtl = attributes.language == "ar"
        func tr(_ en: String, _ ar: String) -> String { rtl ? ar : en }

        let store = state.storeName.flatMap { $0.isEmpty ? nil : $0 } ?? tr("Waddy", "واضي")
        let riderName = state.deliveryManName.flatMap { $0.isEmpty ? nil : $0 }
        let rider = riderName ?? tr("Your rider", "المندوب")
        let module = attributes.moduleType ?? "food"
        let food = module == "food"
        let grocery = module == "grocery"
        let takeAway = attributes.orderType == "take_away"

        self.rtl = rtl
        self.takeAway = takeAway
        merchant = store
        url = URL(string: "waddy://order/\(attributes.orderId)")

        // Stage → current segment. Placed, preparing, collecting and on the
        // way each own a segment; delivered fills all four.
        var current = 0
        var ring = 0.1
        var phase = Phase.live
        var promisesTime = true

        switch state.status {
        case "pending":
            title = tr("Waiting for the store", "مستنيين المحل يأكد")
            // Same promise the app makes (od_eta_after_confirm).
            line = tr("Time set once the store confirms", "الوقت هيتحدد لما المحل يأكد")
            emoji = "🧾"
            promisesTime = false // Nothing is promised until the store accepts.
        case "accepted", "confirmed":
            title = tr("Order confirmed", "طلبك اتأكد")
            line = tr("Got it and getting started", "استلموه وبدأوا يجهّزوه")
            emoji = Self.kitchenEmoji(food: food, grocery: grocery)
            current = 1; ring = 0.3
        case "processing":
            title = tr("Preparing your order", "بنحضّر طلبك")
            if state.subStatus == "ready" {
                line = takeAway
                    ? tr("Packed and waiting for you", "جاهز ومستنيك")
                    : tr("Packed and waiting for the rider", "جاهز ومستني المندوب")
            } else if food {
                line = tr("Whipping it up for you", "بيتحضّر بمزاج")
            } else if grocery {
                line = tr("Picking the best ones for you", "بنختارلك أحسن حاجة")
            } else {
                line = tr("Getting it ready", "بيتجهّز")
            }
            emoji = Self.kitchenEmoji(food: food, grocery: grocery)
            current = 1; ring = 0.35
        case "handover":
            if takeAway {
                title = tr("Ready for pickup", "جاهز تستلمه")
                line = tr("Head over and pick it up", "تعالى استلمه")
                emoji = "🛍️"
            } else if riderName != nil {
                // Handover means ready at the store, not yet picked up.
                title = tr("Collecting your order", "المندوب رايح يستلم طلبك")
                line = tr("\(rider) is heading to the store", "\(rider) رايح المحل")
                emoji = "🛍️"
            } else {
                // A store can hand over before any rider exists.
                title = tr("Your order is ready", "طلبك جاهز")
                line = tr("Finding a rider to bring it over", "بندوّر على مندوب يوصّلهولك")
                emoji = "📦"
            }
            current = 2; ring = 0.6
        case "picked_up":
            title = tr("Order is on the way", "طلبك في السكة")
            let tease = food ? tr(" Spoons ready?", " جهّز المعالق!")
                : grocery ? tr(" Fridge space ready?", " فضّي مكان في التلاجة!") : ""
            switch state.subStatus {
            case "arrived":
                line = tr("\(rider) is at your door", "\(rider) على الباب")
                emoji = "🚪"
            case "nearby":
                line = tr("\(rider) is almost there.", "\(rider) قرّب يوصل.") + tease
                emoji = "🛵"
            default:
                line = tr("\(rider) has your order.", "\(rider) معاه طلبك.") + tease
                emoji = "🛵"
            }
            current = 3; ring = 0.85
        case "delivered":
            phase = .delivered
            title = takeAway ? tr("Waddy! Order picked up", "حلو! استلمت طلبك")
                : food ? tr("Waddy! Your food is here", "حلو! أكلك وصل")
                : tr("Waddy! Your order is here", "حلو! طلبك وصل")
            let at = state.arrivalAt.map { Self.clock(Date(timeIntervalSince1970: $0), rtl: rtl, period: true) }
            line = at.map { tr("\(store) · Delivered at \($0)", "\(store) · وصل الساعة \($0)") }
                ?? tr("\(store) · Enjoy your order!", "\(store) · بالهنا والشفا!")
            emoji = grocery ? "🥬" : (food || takeAway) ? "😋" : "🎉"
            current = 4; ring = 1
            promisesTime = false
        case "canceled", "failed", "refund_requested", "refunded":
            phase = .ended
            switch state.status {
            case "failed":
                title = tr("Order failed", "الطلب ما اكتملش")
                line = tr("Tap to see why and what's next", "دوس عشان تعرف السبب واللي جاي")
                emoji = "💬"
            case "refund_requested":
                title = tr("Refund requested", "طلب الاسترجاع اتبعت")
                line = tr("Tap to follow your refund", "دوس عشان تتابع الاسترجاع")
                emoji = "💸"
            case "refunded":
                title = tr("Order refunded", "فلوس الطلب رجعت")
                line = tr("Tap to see the refund details", "دوس عشان تشوف تفاصيل الاسترجاع")
                emoji = "💸"
            default:
                title = tr("Order cancelled", "الطلب اتلغى")
                line = tr("Tap to see why and what's next", "دوس عشان تعرف السبب واللي جاي")
                emoji = "💬"
            }
            ring = 0
            promisesTime = false
        default:
            title = state.title.isEmpty ? tr("Tracking your order", "بنتابع طلبك") : state.title
            line = state.subtitle
            emoji = "⏳"
        }

        self.phase = phase
        ringProgress = ring
        segments = (0..<4).map { i in
            if phase == .ended { return .halted }
            return i < current ? .done : i == current ? .current : .todo
        }

        // ETA: the clock time is the headline because it stays true between
        // pushes; the countdown under it is rendered live by the system.
        let arrival = state.arrivalAt.map { Date(timeIntervalSince1970: $0) }
            ?? state.etaMinutes.map { Date().addingTimeInterval(Double($0) * 60) }
        if !promisesTime || phase != .live {
            eta = .none
        } else if state.status == "picked_up" && state.subStatus == "arrived" {
            eta = .here
        } else if let arrival {
            eta = (isStale || arrival <= Date()) ? .late(arrival) : .arriving(arrival)
        } else {
            eta = .none
        }

        // VoiceOver: title, line, the time, then where it is in the flow.
        var sentence = "\(title). \(line)."
        switch eta {
        case .arriving(let d):
            let t = Self.clock(d, rtl: rtl, period: true)
            sentence += " " + (takeAway ? tr("Ready at \(t).", "هيكون جاهز الساعة \(t).")
                                        : tr("Arrives at \(t).", "هيوصل الساعة \(t)."))
        case .late(let d):
            let t = Self.clock(d, rtl: rtl, period: true)
            sentence += " " + tr("Running a little late, expected at \(t).", "متأخر شوية، المتوقع الساعة \(t).")
        case .here, .none:
            break
        }
        if phase == .live {
            sentence += " " + tr("Step \(min(current + 1, 4)) of 4.", "الخطوة \(min(current + 1, 4)) من 4.")
        }
        spoken = sentence
    }

    private static func kitchenEmoji(food: Bool, grocery: Bool) -> String {
        food ? "👩‍🍳" : grocery ? "🧺" : "📦"
    }

    /// Latin digits in both languages, matching the app.
    static func locale(rtl: Bool) -> Locale {
        Locale(identifier: rtl ? "ar_EG@numbers=latn" : "en_US")
    }

    static func clock(_ date: Date, rtl: Bool, period: Bool) -> String {
        let f = DateFormatter()
        f.locale = locale(rtl: rtl)
        f.dateFormat = period ? "h:mm a" : "h:mm"
        return f.string(from: date)
    }

    func clock(_ date: Date, period: Bool = false) -> String {
        Self.clock(date, rtl: rtl, period: period)
    }

    var lateLabel: String { rtl ? "متأخر شوية" : "A bit late" }
    var hereLabel: String { rtl ? "هنا" : "Here" }
    var isTakeAway: Bool { takeAway }
}

// MARK: - Lock Screen (live and ended)

@available(iOS 16.2, *)
struct LockScreenView: View {
    let model: TrackingModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                LogoTile(size: 44, corner: 12)
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.merchant)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Waddy.inkSoft)
                    Text(model.title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Waddy.inkHigh)
                }
                .lineLimit(1)
                Spacer(minLength: 8)
                StatusStack(model: model, main: .system(size: 22, weight: .heavy, design: .rounded))
            }

            StepBar(segments: model.segments, height: 6)

            HStack(spacing: 8) {
                Text(model.emoji)
                    .font(.system(size: 16))
                Text(model.line)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Waddy.inkSoft)
                    .lineLimit(1)
            }
        }
        .padding(16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.spoken)
    }
}

// MARK: - Delivered (the peak moment)

/// The one frame that should be recognisable from across a table: a full mint
/// field, teal ink, and the brand's own exclamation.
@available(iOS 16.2, *)
struct DeliveredView: View {
    let model: TrackingModel

    var body: some View {
        HStack(spacing: 14) {
            LogoTile(size: 44, corner: 12)

            VStack(alignment: .leading, spacing: 3) {
                Text(model.title)
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundColor(Waddy.teal)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text("\(model.emoji) \(model.line)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Waddy.teal.opacity(0.8))
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            ZStack {
                Circle().fill(Waddy.teal)
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundColor(Waddy.mint)
            }
            .frame(width: 32, height: 32)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.spoken)
    }
}

// MARK: - Pieces

/// The mint Waddy "W" on a teal tile (lock screen) or disc (island).
struct LogoTile: View {
    let size: CGFloat
    /// nil draws a circle.
    let corner: CGFloat?

    var body: some View {
        ZStack {
            if let corner {
                RoundedRectangle(cornerRadius: corner, style: .continuous).fill(Waddy.teal)
            } else {
                Circle().fill(Waddy.teal)
            }
            WaddyMark(height: size * 0.36, color: Waddy.mint)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// The right-hand status: arrival time with a system-rendered countdown,
/// "late" in coral, "Here", or the stage emoji when no time is promised.
@available(iOS 16.2, *)
struct StatusStack: View {
    let model: TrackingModel
    let main: Font

    var body: some View {
        switch model.eta {
        case .arriving(let date):
            VStack(alignment: .trailing, spacing: 2) {
                Text(model.clock(date))
                    .font(main)
                    .foregroundColor(Waddy.mint)
                Countdown(to: date)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Waddy.inkMute)
            }
            .monospacedDigit()
            .lineLimit(1)
            .fixedSize()
        case .late(let date):
            VStack(alignment: .trailing, spacing: 2) {
                Text(model.clock(date))
                    .font(main)
                Text(model.lateLabel)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(Waddy.coral)
            .monospacedDigit()
            .lineLimit(1)
            .fixedSize()
        case .here:
            Text(model.hereLabel)
                .font(main)
                .foregroundColor(Waddy.mint)
                .lineLimit(1)
                .fixedSize()
        case .none:
            switch model.phase {
            case .ended:
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundColor(Waddy.coral)
            case .delivered:
                ZStack {
                    Circle().fill(Waddy.mint)
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundColor(Waddy.teal)
                }
                .frame(width: 32, height: 32)
            case .live:
                // Waiting on the store: no time promised yet.
                Text("⏳")
                    .font(.system(size: 24))
            }
        }
    }
}

/// Time to arrival as a system-ticking timer, updated between pushes.
///
/// Only `Text(timerInterval:)`: the iOS 18 `Text(.currentDate, format:
/// .offset(…))` rendered the whole lock-screen card and expanded island
/// BLANK on device (10-04), leaving only views without a countdown.
struct Countdown: View {
    let to: Date

    var body: some View {
        // The range must not invert, or the timer traps.
        Text(timerInterval: Date.now...max(to, Date.now), countsDown: true, showsHours: true)
            .multilineTextAlignment(.trailing)
            .frame(width: 56, alignment: .trailing)
    }
}

/// Compact island, right side: stage emoji plus the arrival time.
@available(iOS 16.2, *)
struct CompactStatus: View {
    let model: TrackingModel

    var body: some View {
        HStack(spacing: 4) {
            if model.phase == .ended {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(Waddy.coral)
            } else {
                Text(model.emoji)
                    .font(.system(size: 13))
            }
            switch model.eta {
            case .arriving(let date):
                Text(model.clock(date))
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(Waddy.mint)
            case .late(let date):
                Text(model.clock(date))
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(Waddy.coral)
            case .here, .none:
                EmptyView()
            }
        }
        .lineLimit(1)
    }
}

/// Four segments: done ones full, the live one half-filled, the rest a track.
/// An ended order keeps the bar but turns it coral.
@available(iOS 16.2, *)
struct StepBar: View {
    let segments: [TrackingModel.Segment]
    let height: CGFloat

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                switch segment {
                case .done:
                    Capsule().fill(Waddy.mint)
                case .current:
                    Capsule().fill(Waddy.track).overlay(
                        // Half-width fill, mirrored automatically in RTL.
                        HStack(spacing: 0) {
                            Capsule().fill(Waddy.mint)
                            Color.clear
                        }
                    )
                case .todo:
                    Capsule().fill(Waddy.track)
                case .halted:
                    Capsule().fill(Waddy.coral.opacity(0.55))
                }
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// Minimal island: the Waddy mark inside the stage progress ring.
@available(iOS 16.2, *)
struct ProgressRing: View {
    let model: TrackingModel

    var body: some View {
        let tint = model.phase == .ended ? Waddy.coral : Waddy.mint
        ZStack {
            Circle()
                .stroke(Waddy.track, lineWidth: 3)
            Circle()
                .trim(from: 0, to: model.ringProgress)
                .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            WaddyMark(height: 8, color: Waddy.mint)
        }
        .padding(1.5)
    }
}

/// The Waddy "W", template-tinted.
struct WaddyMark: View {
    let height: CGFloat
    let color: Color

    var body: some View {
        Image("WaddyLogo")
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .frame(height: height)
            .foregroundColor(color)
            .accessibilityHidden(true)
    }
}
