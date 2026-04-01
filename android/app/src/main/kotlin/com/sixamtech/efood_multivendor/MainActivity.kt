package com.hamdiesolutions.waddi

import android.Manifest
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.hamdiesolutions.waddi/permissions"
    private val LIVE_ACTIVITY_CHANNEL = "com.hamdiesolutions.waddi/live_activity"
    private val MIC_PERMISSION_CODE = 200
    private var permissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Permissions channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkMicPermission" -> {
                    when {
                        ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED -> {
                            result.success("granted")
                        }
                        !ActivityCompat.shouldShowRequestPermissionRationale(this, Manifest.permission.RECORD_AUDIO) && ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED -> {
                            // First time or denied forever — we check after request to distinguish
                            result.success("denied")
                        }
                        else -> {
                            result.success("denied")
                        }
                    }
                }
                "requestMicPermission" -> {
                    if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {
                        result.success("granted")
                    } else {
                        permissionResult = result
                        ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.RECORD_AUDIO), MIC_PERMISSION_CODE)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Live Activity (order tracking notification) channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LIVE_ACTIVITY_CHANNEL).setMethodCallHandler { call, result ->
            val manager = OrderTrackingNotificationManager.getInstance(this)
            when (call.method) {
                "isLiveActivitySupported" -> {
                    result.success(true)
                }
                "startLiveActivity" -> {
                    val orderId = call.argument<Int>("orderId") ?: run { result.error("INVALID", "Missing orderId", null); return@setMethodCallHandler }
                    val status = call.argument<String>("status") ?: ""
                    val subStatus = call.argument<String>("subStatus")
                    val title = call.argument<String>("title") ?: ""
                    val subtitle = call.argument<String>("subtitle") ?: ""
                    val etaText = call.argument<String>("etaText")
                    val progress = call.argument<Double>("progress") ?: 0.0
                    val step = call.argument<Int>("step") ?: 0
                    val storeName = call.argument<String>("storeName")
                    val deliveryManName = call.argument<String>("deliveryManName")
                    manager.start(orderId, status, subStatus, title, subtitle, etaText, progress, step, storeName, deliveryManName)
                    result.success(null) // No push token on Android
                }
                "updateLiveActivity" -> {
                    val orderId = call.argument<Int>("orderId") ?: run { result.error("INVALID", "Missing orderId", null); return@setMethodCallHandler }
                    val status = call.argument<String>("status") ?: ""
                    val subStatus = call.argument<String>("subStatus")
                    val title = call.argument<String>("title") ?: ""
                    val subtitle = call.argument<String>("subtitle") ?: ""
                    val etaText = call.argument<String>("etaText")
                    val progress = call.argument<Double>("progress") ?: 0.0
                    val step = call.argument<Int>("step") ?: 0
                    val storeName = call.argument<String>("storeName")
                    val deliveryManName = call.argument<String>("deliveryManName")
                    manager.update(orderId, status, subStatus, title, subtitle, etaText, progress, step, storeName, deliveryManName)
                    result.success(null)
                }
                "endLiveActivity" -> {
                    val orderId = call.argument<Int>("orderId") ?: run { result.error("INVALID", "Missing orderId", null); return@setMethodCallHandler }
                    manager.stop(orderId)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == MIC_PERMISSION_CODE) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                permissionResult?.success("granted")
            } else if (!ActivityCompat.shouldShowRequestPermissionRationale(this, Manifest.permission.RECORD_AUDIO)) {
                permissionResult?.success("denied_forever")
            } else {
                permissionResult?.success("denied")
            }
            permissionResult = null
        }
    }
}
