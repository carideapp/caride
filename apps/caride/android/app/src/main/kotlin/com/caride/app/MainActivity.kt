package com.caride.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import androidx.activity.enableEdgeToEdge
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    companion object {
        private const val FLOATING_CHANNEL = "com.caride.app/floating_overlay"
        private const val RIDE_ALERTS_CHANNEL = "com.caride.app/ride_alerts"
    }

    private var overlayChannel: MethodChannel? = null
    private var rideAlertsChannel: MethodChannel? = null
    private var pendingOpenRequests = false
    private var pendingRideIntent: Map<String, String>? = null
    private var isDartRideAlertsReady = false
    private var receiverRegistered = false

    private val foregroundAlertReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                CarideFirebaseMessagingService.ACTION_FOREGROUND_RIDE_ALERT -> {
                    val rideId = intent.getStringExtra(CarideFirebaseMessagingService.EXTRA_RIDE_ID)?.trim().orEmpty()
                    if (rideId.isEmpty()) return
                    val payload = mapOf<String, Any?>(
                        "rideId" to rideId,
                        "type" to (intent.getStringExtra(CarideFirebaseMessagingService.EXTRA_ALERT_TYPE) ?: "ride_request"),
                        "pickupLabel" to intent.getStringExtra(CarideFirebaseMessagingService.EXTRA_PICKUP_LABEL),
                        "dropoffLabel" to intent.getStringExtra(CarideFirebaseMessagingService.EXTRA_DROPOFF_LABEL),
                        "rideType" to intent.getStringExtra(CarideFirebaseMessagingService.EXTRA_RIDE_TYPE),
                        "customerOffer" to intent.getStringExtra(CarideFirebaseMessagingService.EXTRA_CUSTOMER_OFFER),
                        "paymentMethod" to intent.getStringExtra(CarideFirebaseMessagingService.EXTRA_PAYMENT_METHOD),
                        "distanceKm" to intent.getStringExtra(CarideFirebaseMessagingService.EXTRA_DISTANCE_KM),
                        "expiresAtMs" to intent.getLongExtra(CarideFirebaseMessagingService.EXTRA_EXPIRES_AT_MS, 0L),
                    )
                    rideAlertsChannel?.invokeMethod("onForegroundRideAlert", payload)
                }
                CarideFirebaseMessagingService.ACTION_FOREGROUND_RIDE_CANCEL -> {
                    val rideId = intent.getStringExtra(CarideFirebaseMessagingService.EXTRA_RIDE_ID)?.trim().orEmpty()
                    if (rideId.isEmpty()) return
                    rideAlertsChannel?.invokeMethod("onRideAlertCancelled", mapOf("rideId" to rideId))
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        registerForegroundAlertReceiver()
        captureLaunchIntent(intent)
    }

    override fun onDestroy() {
        unregisterForegroundAlertReceiver()
        super.onDestroy()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val ridePayload = extractRideIntent(intent)
        if (ridePayload != null) {
            if (isDartRideAlertsReady && rideAlertsChannel != null) {
                rideAlertsChannel?.invokeMethod("onRideNotificationTapped", ridePayload)
            } else {
                pendingRideIntent = ridePayload
            }
            return
        }
        if (intent.getBooleanExtra(DriverFloatingService.EXTRA_OPEN_REQUESTS, false)) {
            if (overlayChannel != null) {
                overlayChannel?.invokeMethod("onOverlayTapped", null)
            } else {
                pendingOpenRequests = true
            }
        }
    }

    private fun captureLaunchIntent(launchIntent: Intent?) {
        val ridePayload = extractRideIntent(launchIntent)
        if (ridePayload != null) {
            pendingRideIntent = ridePayload
            return
        }
        if (launchIntent?.getBooleanExtra(DriverFloatingService.EXTRA_OPEN_REQUESTS, false) == true) {
            pendingOpenRequests = true
        }
    }

    private fun extractRideIntent(intent: Intent?): Map<String, String>? {
        if (intent == null) return null
        val rideId = (intent.getStringExtra(CarideFirebaseMessagingService.EXTRA_RIDE_ID)
            ?: intent.getStringExtra("rideId"))?.trim().orEmpty()
        if (rideId.isEmpty()) return null
        val type = (intent.getStringExtra(CarideFirebaseMessagingService.EXTRA_ALERT_TYPE)
            ?: intent.getStringExtra("type"))?.trim().orEmpty().ifEmpty { "ride_request" }
        return mapOf(
            "rideId" to rideId,
            "type" to type,
            "action" to "open",
        )
    }

    private fun registerForegroundAlertReceiver() {
        if (receiverRegistered) return
        val filter = IntentFilter().apply {
            addAction(CarideFirebaseMessagingService.ACTION_FOREGROUND_RIDE_ALERT)
            addAction(CarideFirebaseMessagingService.ACTION_FOREGROUND_RIDE_CANCEL)
        }
        ContextCompat.registerReceiver(
            this,
            foregroundAlertReceiver,
            filter,
            ContextCompat.RECEIVER_NOT_EXPORTED,
        )
        receiverRegistered = true
    }

    private fun unregisterForegroundAlertReceiver() {
        if (!receiverRegistered) return
        try {
            unregisterReceiver(foregroundAlertReceiver)
        } catch (_: Exception) {
        }
        receiverRegistered = false
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        overlayChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FLOATING_CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasOverlayPermission" -> {
                        result.success(Settings.canDrawOverlays(this@MainActivity))
                    }
                    "requestOverlayPermission" -> {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        )
                        startActivity(intent)
                        result.success(true)
                    }
                    "startFloatingOverlay" -> {
                        if (!Settings.canDrawOverlays(this@MainActivity)) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        val serviceIntent = Intent(this@MainActivity, DriverFloatingService::class.java).apply {
                            action = DriverFloatingService.ACTION_START
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(serviceIntent)
                        } else {
                            startService(serviceIntent)
                        }
                        result.success(true)
                    }
                    "stopFloatingOverlay" -> {
                        if (DriverFloatingService.isRunning) {
                            val serviceIntent = Intent(this@MainActivity, DriverFloatingService::class.java).apply {
                                action = DriverFloatingService.ACTION_STOP
                            }
                            try {
                                startService(serviceIntent)
                            } catch (_: Exception) {
                            }
                        }
                        result.success(true)
                    }
                    "notifyRideOffer" -> {
                        if (!Settings.canDrawOverlays(this@MainActivity)) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        val title = call.argument<String>("title") ?: "New Ride Offer"
                        val count = call.argument<Int>("count") ?: 1
                        val rideId = call.argument<String>("rideId")
                        val pickupLabel = call.argument<String>("pickupLabel")
                        val dropoffLabel = call.argument<String>("dropoffLabel")
                        val distanceKm = call.argument<String>("distanceKm")
                        val paymentMethod = call.argument<String>("paymentMethod")
                        val remainingMs = call.argument<Number>("remainingMs")?.toLong()
                        val serviceIntent = Intent(this@MainActivity, DriverFloatingService::class.java).apply {
                            action = DriverFloatingService.ACTION_NOTIFY_OFFER
                            putExtra(DriverFloatingService.EXTRA_TITLE, title)
                            putExtra(DriverFloatingService.EXTRA_COUNT, count)
                            if (!rideId.isNullOrBlank()) {
                                putExtra(DriverFloatingService.EXTRA_RIDE_ID, rideId)
                            }
                            if (!pickupLabel.isNullOrBlank()) {
                                putExtra(DriverFloatingService.EXTRA_PICKUP_LABEL, pickupLabel)
                            }
                            if (!dropoffLabel.isNullOrBlank()) {
                                putExtra(DriverFloatingService.EXTRA_DROPOFF_LABEL, dropoffLabel)
                            }
                            if (!distanceKm.isNullOrBlank()) {
                                putExtra(DriverFloatingService.EXTRA_DISTANCE_KM, distanceKm)
                            }
                            if (!paymentMethod.isNullOrBlank()) {
                                putExtra(DriverFloatingService.EXTRA_PAYMENT_METHOD, paymentMethod)
                            }
                            if (remainingMs != null) {
                                putExtra(DriverFloatingService.EXTRA_REMAINING_MS, remainingMs)
                            }
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(serviceIntent)
                        } else {
                            startService(serviceIntent)
                        }
                        result.success(true)
                    }
                    "clearRideOffer" -> {
                        if (DriverFloatingService.isRunning) {
                            val rideId = call.argument<String>("rideId")
                            val serviceIntent = Intent(this@MainActivity, DriverFloatingService::class.java).apply {
                                action = DriverFloatingService.ACTION_CLEAR_OFFER
                                if (!rideId.isNullOrBlank()) {
                                    putExtra(DriverFloatingService.EXTRA_RIDE_ID, rideId)
                                }
                            }
                            try {
                                startService(serviceIntent)
                            } catch (_: Exception) {
                            }
                        }
                        result.success(true)
                    }
                    "consumePendingOpenRequests" -> {
                        val pending = pendingOpenRequests
                        pendingOpenRequests = false
                        result.success(pending)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        rideAlertsChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, RIDE_ALERTS_CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "consumePendingRideIntent" -> {
                        isDartRideAlertsReady = true
                        val payload = pendingRideIntent ?: RideAlertStore.consumePendingIntent(this@MainActivity)
                        pendingRideIntent = null
                        result.success(payload)
                    }
                    "cancelRideNotification" -> {
                        val rideId = call.argument<String>("rideId")?.trim().orEmpty()
                        if (rideId.isNotEmpty()) {
                            NotificationManagerCompat.from(this@MainActivity)
                                .cancel(RideAlertStore.notificationIdForRide(rideId))
                            if (DriverFloatingService.isRunning) {
                                val clearIntent = Intent(this@MainActivity, DriverFloatingService::class.java).apply {
                                    action = DriverFloatingService.ACTION_CLEAR_OFFER
                                    putExtra(DriverFloatingService.EXTRA_RIDE_ID, rideId)
                                }
                                try {
                                    startService(clearIntent)
                                } catch (_: Exception) {
                                }
                            }
                        }
                        result.success(true)
                    }
                    "markRideDeclined" -> {
                        val rideId = call.argument<String>("rideId")?.trim().orEmpty()
                        if (rideId.isNotEmpty()) {
                            RideAlertStore.markDeclined(this@MainActivity, rideId)
                            NotificationManagerCompat.from(this@MainActivity)
                                .cancel(RideAlertStore.notificationIdForRide(rideId))
                            if (DriverFloatingService.isRunning) {
                                val clearIntent = Intent(this@MainActivity, DriverFloatingService::class.java).apply {
                                    action = DriverFloatingService.ACTION_CLEAR_OFFER
                                    putExtra(DriverFloatingService.EXTRA_RIDE_ID, rideId)
                                }
                                try {
                                    startService(clearIntent)
                                } catch (_: Exception) {
                                }
                            }
                        }
                        result.success(true)
                    }
                    "getDeclinedRideIds" -> {
                        result.success(RideAlertStore.getDeclinedIds(this@MainActivity))
                    }
                    "isBatteryOptimizationIgnored" -> {
                        val ignored = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
                            pm?.isIgnoringBatteryOptimizations(packageName) ?: true
                        } else {
                            true
                        }
                        result.success(ignored)
                    }
                    "openBatterySettings" -> {
                        val opened = try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                            } else {
                                startActivity(Intent(Settings.ACTION_SETTINGS))
                            }
                            true
                        } catch (_: Exception) {
                            try {
                                val fallback = Intent(
                                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                    Uri.parse("package:$packageName")
                                )
                                startActivity(fallback)
                                true
                            } catch (_: Exception) {
                                false
                            }
                        }
                        result.success(opened)
                    }
                    "openNotificationChannelSettings" -> {
                        val channelId = call.argument<String>("channelId")?.trim().orEmpty()
                            .ifEmpty { NotificationChannelRegistrar.CHANNEL_RIDE_REQUESTS }
                        val opened = try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                val intent = Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS).apply {
                                    putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                                    putExtra(Settings.EXTRA_CHANNEL_ID, channelId)
                                }
                                startActivity(intent)
                            } else {
                                val intent = Intent(
                                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                    Uri.parse("package:$packageName")
                                )
                                startActivity(intent)
                            }
                            true
                        } catch (_: Exception) {
                            false
                        }
                        result.success(opened)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }
}
