package com.caride.app

import android.Manifest
import android.app.KeyguardManager
import android.app.Notification
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService
import java.text.NumberFormat
import java.util.Locale

class CarideFirebaseMessagingService : FlutterFirebaseMessagingService() {

    companion object {
        const val ACTION_FOREGROUND_RIDE_ALERT = "com.caride.app.ACTION_FOREGROUND_RIDE_ALERT"
        const val ACTION_FOREGROUND_RIDE_CANCEL = "com.caride.app.ACTION_FOREGROUND_RIDE_CANCEL"

        const val EXTRA_RIDE_ID = "extra_ride_id"
        const val EXTRA_ALERT_TYPE = "extra_alert_type"
        const val EXTRA_PICKUP_LABEL = "extra_pickup_label"
        const val EXTRA_DROPOFF_LABEL = "extra_dropoff_label"
        const val EXTRA_RIDE_TYPE = "extra_ride_type"
        const val EXTRA_CUSTOMER_OFFER = "extra_customer_offer"
        const val EXTRA_PAYMENT_METHOD = "extra_payment_method"
        const val EXTRA_DISTANCE_KM = "extra_distance_km"
        const val EXTRA_EXPIRES_AT_MS = "extra_expires_at_ms"
    }

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        val data = remoteMessage.data
        val type = data["type"]?.trim()?.lowercase(Locale.US) ?: ""

        when (type) {
            "ride_request", "new_ride", "ride_offer" -> {
                handleIncomingRideRequest(data)
                return
            }
            "ride_alert_cancel" -> {
                handleRideAlertCancel(data)
                return
            }
            else -> super.onMessageReceived(remoteMessage)
        }
    }

    private fun handleIncomingRideRequest(data: Map<String, String>) {
        val rideId = data["rideId"]?.trim().orEmpty()
        if (!isValidRideId(rideId)) return

        val nowMs = System.currentTimeMillis()
        val expiresAtMs = data["expiresAtMs"]?.toLongOrNull() ?: 0L
        if (expiresAtMs > 0L && nowMs >= expiresAtMs) {
            return
        }

        if (RideAlertStore.isHandledOrDeclined(this, rideId)) {
            return
        }
        RideAlertStore.markSeen(this, rideId)

        val pickupLabel = data["pickupLabel"]?.trim().orEmpty().ifEmpty { "Pickup" }
        val dropoffLabel = data["dropoffLabel"]?.trim().orEmpty().ifEmpty { "Destination" }
        val rideType = data["rideType"]?.trim().orEmpty().ifEmpty { "Regular" }
        val customerOffer = data["customerOffer"]?.trim().orEmpty().ifEmpty { "0" }
        val paymentMethod = data["paymentMethod"]?.trim().orEmpty().ifEmpty { "cash" }
        val distanceKm = data["distanceKm"]?.trim().orEmpty()
        val remainingMs = if (expiresAtMs > 0L) {
            (expiresAtMs - nowMs).coerceIn(10_000L, 45_000L)
        } else {
            45_000L
        }

        if (AppForegroundTracker.isForeground) {
            val fgIntent = Intent(ACTION_FOREGROUND_RIDE_ALERT).apply {
                setPackage(packageName)
                putExtra(EXTRA_RIDE_ID, rideId)
                putExtra(EXTRA_ALERT_TYPE, "ride_request")
                putExtra(EXTRA_PICKUP_LABEL, pickupLabel)
                putExtra(EXTRA_DROPOFF_LABEL, dropoffLabel)
                putExtra(EXTRA_RIDE_TYPE, rideType)
                putExtra(EXTRA_CUSTOMER_OFFER, customerOffer)
                putExtra(EXTRA_PAYMENT_METHOD, paymentMethod)
                putExtra(EXTRA_DISTANCE_KM, distanceKm)
                putExtra(EXTRA_EXPIRES_AT_MS, expiresAtMs)
            }
            sendBroadcast(fgIntent)
            return
        }

        NotificationChannelRegistrar.registerAll(this)

        val keyguard = getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
        val isUnlocked = keyguard == null || !keyguard.isKeyguardLocked
        val canUseFloatingOverlay =
            isUnlocked && Settings.canDrawOverlays(this) && DriverFloatingService.isRunning

        var overlayShown = false
        if (canUseFloatingOverlay) {
            val overlayIntent = Intent(this, DriverFloatingService::class.java).apply {
                action = DriverFloatingService.ACTION_NOTIFY_OFFER
                putExtra(DriverFloatingService.EXTRA_RIDE_ID, rideId)
                putExtra(DriverFloatingService.EXTRA_TITLE, buildOfferTitle(rideType, customerOffer))
                putExtra(DriverFloatingService.EXTRA_PICKUP_LABEL, pickupLabel)
                putExtra(DriverFloatingService.EXTRA_DROPOFF_LABEL, dropoffLabel)
                putExtra(DriverFloatingService.EXTRA_DISTANCE_KM, distanceKm)
                putExtra(DriverFloatingService.EXTRA_PAYMENT_METHOD, paymentMethod)
                putExtra(DriverFloatingService.EXTRA_REMAINING_MS, remainingMs)
                putExtra(DriverFloatingService.EXTRA_COUNT, 1)
            }
            try {
                startService(overlayIntent)
                overlayShown = true
            } catch (_: Exception) {
                overlayShown = false
            }
        }

        postRideRequestNotification(
            rideId = rideId,
            pickupLabel = pickupLabel,
            dropoffLabel = dropoffLabel,
            rideType = rideType,
            customerOffer = customerOffer,
            paymentMethod = paymentMethod,
            distanceKm = distanceKm,
            remainingMs = remainingMs,
            silent = overlayShown,
        )
    }

    private fun handleRideAlertCancel(data: Map<String, String>) {
        val rideId = data["rideId"]?.trim().orEmpty()
        if (!isValidRideId(rideId)) return

        NotificationManagerCompat.from(this)
            .cancel(RideAlertStore.notificationIdForRide(rideId))

        if (DriverFloatingService.isRunning) {
            val clearIntent = Intent(this, DriverFloatingService::class.java).apply {
                action = DriverFloatingService.ACTION_CLEAR_OFFER
                putExtra(DriverFloatingService.EXTRA_RIDE_ID, rideId)
            }
            try {
                startService(clearIntent)
            } catch (_: Exception) {
            }
        }

        if (AppForegroundTracker.isForeground) {
            val cancelIntent = Intent(ACTION_FOREGROUND_RIDE_CANCEL).apply {
                setPackage(packageName)
                putExtra(EXTRA_RIDE_ID, rideId)
            }
            sendBroadcast(cancelIntent)
        }
    }

    private fun postRideRequestNotification(
        rideId: String,
        pickupLabel: String,
        dropoffLabel: String,
        rideType: String,
        customerOffer: String,
        paymentMethod: String,
        distanceKm: String,
        remainingMs: Long,
        silent: Boolean,
    ) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val granted = ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
            if (!granted) return
        }

        val notifId = RideAlertStore.notificationIdForRide(rideId)
        val openIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(EXTRA_RIDE_ID, rideId)
            putExtra(EXTRA_ALERT_TYPE, "ride_request")
        }
        val contentPendingIntent = PendingIntent.getActivity(
            this,
            notifId,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val declineIntent = Intent(this, RideAlertActionReceiver::class.java).apply {
            action = RideAlertActionReceiver.ACTION_DECLINE_RIDE
            putExtra(RideAlertActionReceiver.EXTRA_RIDE_ID, rideId)
        }
        val declinePendingIntent = PendingIntent.getBroadcast(
            this,
            notifId + 1,
            declineIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val title = buildOfferTitle(rideType, customerOffer)
        val distSegment = if (distanceKm.isNotEmpty()) "$distanceKm km away • " else ""
        val payLabel = if (paymentMethod.equals("wallet", ignoreCase = true)) "Wallet" else "Cash"
        val shortBody = "${distSegment}$payLabel • $pickupLabel"
        val expandedBody =
            "${distSegment}$payLabel\nPickup: $pickupLabel\nDropoff: $dropoffLabel"

        val builder = NotificationCompat.Builder(this, NotificationChannelRegistrar.CHANNEL_RIDE_REQUESTS)
            .setSmallIcon(R.drawable.ic_stat_caride)
            .setColor(ContextCompat.getColor(this, R.color.caride_brand_green))
            .setContentTitle(title)
            .setContentText(shortBody)
            .setStyle(NotificationCompat.BigTextStyle().bigText(expandedBody))
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_TRANSPORT)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setTimeoutAfter(remainingMs)
            .setContentIntent(contentPendingIntent)
            .addAction(0, "View & Bid", contentPendingIntent)
            .addAction(0, "Decline", declinePendingIntent)
            .setSilent(silent)

        val notification = builder.build()
        if (!silent) {
            notification.flags = notification.flags or Notification.FLAG_INSISTENT
        }

        NotificationManagerCompat.from(this).notify(notifId, notification)
    }

    private fun buildOfferTitle(rideType: String, rawOffer: String): String {
        val numeric = rawOffer.toDoubleOrNull()?.toLong()
        val formatted = if (numeric != null && numeric > 0) {
            "₦" + NumberFormat.getNumberInstance(Locale.US).format(numeric)
        } else {
            ""
        }
        return if (formatted.isNotEmpty()) {
            "New $rideType Ride • $formatted"
        } else {
            "New $rideType Ride Request"
        }
    }

    private fun isValidRideId(rideId: String): Boolean {
        return rideId.isNotEmpty() && rideId.length <= 128 &&
            rideId.all { it.isLetterOrDigit() || it == '_' || it == '-' }
    }
}
