import Foundation

#if canImport(ActivityKit)
import ActivityKit

@available(iOS 16.2, *)
struct OrderTrackingAttributes: ActivityAttributes {
    // Decoded from APNs `content-state` pushes as well as local updates, so
    // every field added after launch must stay optional.
    public struct ContentState: Codable, Hashable {
        var status: String
        var subStatus: String?
        var etaMinutes: Int?
        var etaText: String?
        var progress: Double
        var deliveryManName: String?
        var storeName: String?
        var title: String
        var subtitle: String
        var step: Int
        /// Unix seconds. The promised arrival while the order is live, the
        /// actual arrival once it is delivered.
        var arrivalAt: Double?
    }

    var orderId: Int
    var orderType: String
    var storeLogoUrl: String?
    /// The order's module (`food`, `grocery`, …). Picks the copy voice.
    var moduleType: String?
    /// The app's language (`en`/`ar`). Chosen in-app, so the device locale
    /// can't be used.
    var language: String?
}
#endif
