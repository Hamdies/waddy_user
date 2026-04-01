package com.hamdiesolutions.waddi

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat

class OrderTrackingNotificationManager(private val context: Context) {

    companion object {
        private const val CHANNEL_ID = "waddi_order_tracking"
        private const val CHANNEL_NAME = "Order Tracking"
        private const val NOTIFICATION_ID_BASE = 90000

        @Volatile
        private var instance: OrderTrackingNotificationManager? = null

        fun getInstance(context: Context): OrderTrackingNotificationManager {
            return instance ?: synchronized(this) {
                instance ?: OrderTrackingNotificationManager(context.applicationContext).also {
                    instance = it
                }
            }
        }
    }

    private val notificationManager =
        context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    init {
        createNotificationChannel()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Live order tracking updates"
                setShowBadge(false)
                enableVibration(false)
                setSound(null, null)
            }
            notificationManager.createNotificationChannel(channel)
        }
    }

    fun start(
        orderId: Int,
        status: String,
        subStatus: String?,
        title: String,
        subtitle: String,
        etaText: String?,
        progress: Double,
        step: Int,
        storeName: String?,
        deliveryManName: String?
    ) {
        showNotification(orderId, status, subStatus, title, subtitle, etaText, progress, step, storeName, deliveryManName)
    }

    fun update(
        orderId: Int,
        status: String,
        subStatus: String?,
        title: String,
        subtitle: String,
        etaText: String?,
        progress: Double,
        step: Int,
        storeName: String?,
        deliveryManName: String?
    ) {
        showNotification(orderId, status, subStatus, title, subtitle, etaText, progress, step, storeName, deliveryManName)
    }

    fun stop(orderId: Int) {
        notificationManager.cancel(NOTIFICATION_ID_BASE + orderId)
    }

    private fun showNotification(
        orderId: Int,
        status: String,
        subStatus: String?,
        title: String,
        subtitle: String,
        etaText: String?,
        progress: Double,
        step: Int,
        storeName: String?,
        deliveryManName: String?
    ) {
        val packageName = context.packageName
        val isDelivered = status == "delivered"

        // Collapsed view
        val collapsedView = RemoteViews(packageName, R.layout.notification_order_tracking).apply {
            setTextViewText(R.id.tv_status_subtitle, subtitle)
            setTextViewText(R.id.tv_eta, etaText ?: title)
            setImageViewResource(R.id.iv_status_icon, getStatusIcon(status, subStatus))

            // Set progress bar width as percentage using layout weight workaround:
            // We use a FrameLayout, so we set the fill view's width proportionally
            // RemoteViews doesn't support layout_weight, so we use ViewStub-like approach
            // Instead, we'll use setInt to adjust width via LayoutParams
        }

        // Expanded view
        val expandedView = RemoteViews(packageName, R.layout.notification_order_tracking_expanded).apply {
            setTextViewText(R.id.tv_status_subtitle, subtitle)
            setTextViewText(R.id.tv_eta, etaText ?: title)
            setImageViewResource(R.id.iv_status_icon, getStatusIcon(status, subStatus))

            // Store name
            if (!storeName.isNullOrEmpty()) {
                setTextViewText(R.id.tv_store_name, storeName)
                setViewVisibility(R.id.tv_store_name, View.VISIBLE)
            } else {
                setViewVisibility(R.id.tv_store_name, View.GONE)
            }

            // Delivery man
            if (!deliveryManName.isNullOrEmpty()) {
                setTextViewText(R.id.tv_delivery_man, "Driver: $deliveryManName")
                setViewVisibility(R.id.tv_delivery_man, View.VISIBLE)
            } else {
                setViewVisibility(R.id.tv_delivery_man, View.GONE)
            }

            // Rate order button
            if (isDelivered) {
                setViewVisibility(R.id.btn_rate_order, View.VISIBLE)
            } else {
                setViewVisibility(R.id.btn_rate_order, View.GONE)
            }
        }

        // Tap intent — opens the app
        val launchIntent = context.packageManager.getLaunchIntentForPackage(packageName)?.apply {
            putExtra("order_id", orderId.toString())
            putExtra("from_notification", true)
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }

        val pendingIntent = PendingIntent.getActivity(
            context,
            orderId,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_package)
            .setCustomContentView(collapsedView)
            .setCustomBigContentView(expandedView)
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setOngoing(!isDelivered)
            .setOnlyAlertOnce(true)
            .setAutoCancel(isDelivered)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .build()

        notificationManager.notify(NOTIFICATION_ID_BASE + orderId, notification)

        // Auto-dismiss after 30 seconds if delivered
        if (isDelivered) {
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                notificationManager.cancel(NOTIFICATION_ID_BASE + orderId)
            }, 30000)
        }
    }

    private fun getStatusIcon(status: String, subStatus: String?): Int {
        return when (status) {
            "pending" -> R.drawable.ic_order_confirmed
            "accepted", "confirmed" -> R.drawable.ic_order_confirmed
            "processing" -> R.drawable.ic_package
            "handover" -> R.drawable.ic_package
            "picked_up" -> R.drawable.ic_delivery_scooter
            "delivered" -> R.drawable.ic_checkmark_circle
            else -> R.drawable.ic_package
        }
    }
}
