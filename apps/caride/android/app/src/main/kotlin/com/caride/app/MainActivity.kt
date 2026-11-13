package com.caride.app

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.activity.enableEdgeToEdge
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    companion object {
        private const val CHANNEL = "com.caride.app/floating_overlay"
    }

    private var overlayChannel: MethodChannel? = null
    private var pendingOpenRequests = false

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        if (intent?.getBooleanExtra(DriverFloatingService.EXTRA_OPEN_REQUESTS, false) == true) {
            pendingOpenRequests = true
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.getBooleanExtra(DriverFloatingService.EXTRA_OPEN_REQUESTS, false)) {
            overlayChannel?.invokeMethod("onOverlayTapped", null)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        overlayChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
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
                        val serviceIntent = Intent(this@MainActivity, DriverFloatingService::class.java).apply {
                            action = DriverFloatingService.ACTION_STOP
                        }
                        startService(serviceIntent)
                        result.success(true)
                    }
                    "notifyRideOffer" -> {
                        if (!Settings.canDrawOverlays(this@MainActivity)) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        val title = call.argument<String>("title") ?: "New Ride Offer"
                        val count = call.argument<Int>("count") ?: 1
                        val serviceIntent = Intent(this@MainActivity, DriverFloatingService::class.java).apply {
                            action = DriverFloatingService.ACTION_NOTIFY_OFFER
                            putExtra(DriverFloatingService.EXTRA_TITLE, title)
                            putExtra(DriverFloatingService.EXTRA_COUNT, count)
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(serviceIntent)
                        } else {
                            startService(serviceIntent)
                        }
                        result.success(true)
                    }
                    "clearRideOffer" -> {
                        val serviceIntent = Intent(this@MainActivity, DriverFloatingService::class.java).apply {
                            action = DriverFloatingService.ACTION_CLEAR_OFFER
                        }
                        startService(serviceIntent)
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
    }
}
