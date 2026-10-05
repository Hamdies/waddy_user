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

    @available(iOS 16.2, *)
    private static func contentState(from args: [String: Any]) -> OrderTrackingAttributes.ContentState {
        OrderTrackingAttributes.ContentState(
            status: args["status"] as? String ?? "pending",
            subStatus: args["subStatus"] as? String,
            etaMinutes: args["etaMinutes"] as? Int,
            etaText: args["etaText"] as? String,
            progress: args["progress"] as? Double ?? 0.0,
            deliveryManName: args["deliveryManName"] as? String,
            storeName: args["storeName"] as? String,
            title: args["title"] as? String ?? "",
            subtitle: args["subtitle"] as? String ?? "",
            step: args["step"] as? Int ?? 0,
            arrivalAt: args["arrivalAt"] as? Double
        )
    }

    /// Past the promised arrival the widget re-renders as late.
    @available(iOS 16.2, *)
    private static func staleDate(_ state: OrderTrackingAttributes.ContentState) -> Date? {
        guard state.status != "delivered", let arrival = state.arrivalAt else { return nil }
        return Date(timeIntervalSince1970: arrival + 60)
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
            let moduleType = args["moduleType"] as? String
            let language = args["language"] as? String

            let attributes = OrderTrackingAttributes(
                orderId: orderId,
                orderType: orderType,
                storeLogoUrl: storeLogoUrl,
                moduleType: moduleType,
                language: language
            )

            let contentState = Self.contentState(from: args)

            do {
                let activityContent = ActivityContent(state: contentState, staleDate: Self.staleDate(contentState))
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

            let incoming = Self.contentState(from: args)

            Task {
                for activity in Activity<OrderTrackingAttributes>.activities {
                    if activity.attributes.orderId == orderId {
                        // A push that leaves a name out must not blank it.
                        var contentState = incoming
                        let last = activity.content.state
                        if contentState.storeName?.isEmpty ?? true { contentState.storeName = last.storeName }
                        if contentState.deliveryManName?.isEmpty ?? true { contentState.deliveryManName = last.deliveryManName }
                        let activityContent = ActivityContent(state: contentState, staleDate: Self.staleDate(contentState))
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
            let status = args["status"] as? String ?? "delivered"
            let delivered = status == "delivered"

            Task {
                for activity in Activity<OrderTrackingAttributes>.activities {
                    if activity.attributes.orderId == orderId {
                        // Keep the store/rider from the last update; the widget
                        // builds the final copy from the status.
                        let last = activity.content.state
                        let finalState = OrderTrackingAttributes.ContentState(
                            status: status,
                            subStatus: nil,
                            etaMinutes: nil,
                            etaText: nil,
                            progress: delivered ? 1.0 : last.progress,
                            deliveryManName: last.deliveryManName,
                            storeName: last.storeName,
                            title: last.title,
                            subtitle: last.subtitle,
                            step: delivered ? 5 : last.step,
                            arrivalAt: delivered ? Date().timeIntervalSince1970 : nil
                        )
                        let finalContent = ActivityContent(state: finalState, staleDate: nil)
                        // Delivered stays long enough to be seen after the
                        // doorbell; a problem ending stays until the system
                        // clears it (up to 4h), matching the backend.
                        await activity.end(
                            finalContent,
                            dismissalPolicy: delivered ? .after(.now + 30 * 60) : .default
                        )
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
