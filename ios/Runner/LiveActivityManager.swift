import Foundation
import Flutter

#if canImport(ActivityKit)
import ActivityKit
#endif

class LiveActivityManager: NSObject {

    static let shared = LiveActivityManager()

    private override init() {
        super.init()
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isLiveActivitySupported":
            result(isSupported())
        case "startLiveActivity":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "INVALID", message: "Invalid arguments", details: nil))
                return
            }
            startActivity(args: args, result: result)
        case "updateLiveActivity":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "INVALID", message: "Invalid arguments", details: nil))
                return
            }
            updateActivity(args: args, result: result)
        case "endLiveActivity":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "INVALID", message: "Invalid arguments", details: nil))
                return
            }
            endActivity(args: args, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func isSupported() -> Bool {
        if #available(iOS 16.1, *) {
            return ActivityAuthorizationInfo().areActivitiesEnabled
        }
        return false
    }

    private func startActivity(args: [String: Any], result: @escaping FlutterResult) {
        if #available(iOS 16.2, *) {
            guard ActivityAuthorizationInfo().areActivitiesEnabled else {
                result(nil)
                return
            }

            let orderId = args["orderId"] as? Int ?? 0
            let orderType = args["orderType"] as? String ?? "delivery"
            let storeLogoUrl = args["storeLogoUrl"] as? String

            let attributes = OrderTrackingAttributes(
                orderId: orderId,
                orderType: orderType,
                storeLogoUrl: storeLogoUrl
            )

            let contentState = OrderTrackingAttributes.ContentState(
                status: args["status"] as? String ?? "pending",
                subStatus: args["subStatus"] as? String,
                etaMinutes: args["etaMinutes"] as? Int,
                etaText: args["etaText"] as? String,
                progress: args["progress"] as? Double ?? 0.0,
                deliveryManName: args["deliveryManName"] as? String,
                storeName: args["storeName"] as? String,
                title: args["title"] as? String ?? "",
                subtitle: args["subtitle"] as? String ?? "",
                step: args["step"] as? Int ?? 0
            )

            do {
                let activityContent = ActivityContent(state: contentState, staleDate: nil)
                let activity = try Activity<OrderTrackingAttributes>.request(
                    attributes: attributes,
                    content: activityContent,
                    pushType: .token
                )

                // Get push token asynchronously
                Task {
                    for await pushToken in activity.pushTokenUpdates {
                        let tokenString = pushToken.map { String(format: "%02x", $0) }.joined()
                        // Return the push token on the main thread
                        DispatchQueue.main.async {
                            result(tokenString)
                        }
                        break // Only need the first token
                    }
                }
            } catch {
                debugPrint("LiveActivityManager: Failed to start activity - \(error)")
                result(nil)
            }
        } else {
            result(nil)
        }
    }

    private func updateActivity(args: [String: Any], result: @escaping FlutterResult) {
        if #available(iOS 16.2, *) {
            let orderId = args["orderId"] as? Int ?? 0

            let contentState = OrderTrackingAttributes.ContentState(
                status: args["status"] as? String ?? "pending",
                subStatus: args["subStatus"] as? String,
                etaMinutes: args["etaMinutes"] as? Int,
                etaText: args["etaText"] as? String,
                progress: args["progress"] as? Double ?? 0.0,
                deliveryManName: args["deliveryManName"] as? String,
                storeName: args["storeName"] as? String,
                title: args["title"] as? String ?? "",
                subtitle: args["subtitle"] as? String ?? "",
                step: args["step"] as? Int ?? 0
            )

            Task {
                for activity in Activity<OrderTrackingAttributes>.activities {
                    if activity.attributes.orderId == orderId {
                        let activityContent = ActivityContent(state: contentState, staleDate: nil)
                        await activity.update(activityContent)
                        break
                    }
                }
                DispatchQueue.main.async {
                    result(nil)
                }
            }
        } else {
            result(nil)
        }
    }

    private func endActivity(args: [String: Any], result: @escaping FlutterResult) {
        if #available(iOS 16.2, *) {
            let orderId = args["orderId"] as? Int ?? 0

            Task {
                for activity in Activity<OrderTrackingAttributes>.activities {
                    if activity.attributes.orderId == orderId {
                        let finalState = OrderTrackingAttributes.ContentState(
                            status: "delivered",
                            subStatus: nil,
                            etaMinutes: nil,
                            etaText: "Done",
                            progress: 1.0,
                            deliveryManName: nil,
                            storeName: nil,
                            title: "Delivered!",
                            subtitle: "Enjoy your meal!",
                            step: 5
                        )
                        let finalContent = ActivityContent(state: finalState, staleDate: nil)
                        await activity.end(finalContent, dismissalPolicy: .after(.now + 30))
                        break
                    }
                }
                DispatchQueue.main.async {
                    result(nil)
                }
            }
        } else {
            result(nil)
        }
    }
}
