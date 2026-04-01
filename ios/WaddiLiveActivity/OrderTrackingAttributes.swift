import Foundation

#if canImport(ActivityKit)
import ActivityKit

@available(iOS 16.2, *)
struct OrderTrackingAttributes: ActivityAttributes {
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
    }

    var orderId: Int
    var orderType: String
    var storeLogoUrl: String?
}
#endif
