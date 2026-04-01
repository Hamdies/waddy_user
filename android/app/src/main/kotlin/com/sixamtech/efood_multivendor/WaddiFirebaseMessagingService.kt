package com.hamdiesolutions.waddi

import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class WaddiFirebaseMessagingService : FirebaseMessagingService() {

    override fun onMessageReceived(message: RemoteMessage) {
        val data = message.data
        val type = data["type"]

        if (type == "order_status") {
            handleOrderStatusUpdate(data)
        }

        // Let Flutter's default handler process the message too
        super.onMessageReceived(message)
    }

    private fun handleOrderStatusUpdate(data: Map<String, String>) {
        val orderId = data["order_id"]?.toIntOrNull() ?: return
        val status = data["status"] ?: return
        val subStatus = data["sub_status"]
        val title = data["title"] ?: getDefaultTitle(status)
        val subtitle = data["body"] ?: getDefaultSubtitle(status, subStatus)
        val etaText = data["eta_text"]
        val etaMinutes = data["eta_minutes"]?.toIntOrNull()
        val storeName = data["store_name"]
        val deliveryManName = data["delivery_man_name"]

        val progress = getProgressForStatus(status)
        val step = getStepForStatus(status)

        val manager = OrderTrackingNotificationManager.getInstance(applicationContext)

        val isTerminal = status in listOf("delivered", "failed", "canceled", "refund_requested", "refunded")

        if (isTerminal) {
            if (status == "delivered") {
                manager.update(orderId, status, subStatus, title, subtitle,
                    etaText ?: "Done", progress, step, storeName, deliveryManName)
            } else {
                manager.stop(orderId)
            }
        } else {
            val displayEta = etaText ?: if (etaMinutes != null) "Arriving in $etaMinutes mins" else null
            manager.update(orderId, status, subStatus, title, subtitle,
                displayEta, progress, step, storeName, deliveryManName)
        }
    }

    private fun getDefaultTitle(status: String): String = when (status) {
        "pending" -> "Order Placed"
        "accepted", "confirmed" -> "Order Confirmed"
        "processing" -> "Preparing Order"
        "handover" -> "Ready for Delivery"
        "picked_up" -> "On The Way"
        "delivered" -> "Delivered!"
        else -> "Processing"
    }

    private fun getDefaultSubtitle(status: String, subStatus: String?): String = when (status) {
        "pending" -> "Waiting for restaurant to confirm"
        "accepted", "confirmed" -> "Restaurant is preparing your order"
        "processing" -> when (subStatus) {
            "packaging" -> "Packaging your order"
            "ready" -> "Order ready for pickup"
            else -> "Your order is being prepared"
        }
        "handover" -> "Waiting for driver"
        "picked_up" -> when (subStatus) {
            "nearby" -> "Driver is nearby!"
            "arrived" -> "Driver has arrived!"
            else -> "Driver is on the way"
        }
        "delivered" -> "Enjoy your meal!"
        else -> "Please wait..."
    }

    private fun getProgressForStatus(status: String): Double = when (status) {
        "pending" -> 0.2
        "accepted", "confirmed" -> 0.35
        "processing" -> 0.5
        "handover" -> 0.65
        "picked_up" -> 0.8
        "delivered" -> 1.0
        else -> 0.1
    }

    private fun getStepForStatus(status: String): Int = when (status) {
        "pending" -> 1
        "accepted", "confirmed" -> 2
        "processing" -> 3
        "handover" -> 4
        "picked_up" -> 4
        "delivered" -> 5
        else -> 0
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
    }
}
