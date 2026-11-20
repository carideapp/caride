package com.caride.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationManagerCompat

class RideAlertActionReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_DECLINE_RIDE = "com.caride.app.ACTION_DECLINE_RIDE"
        const val EXTRA_RIDE_ID = "extra_ride_id"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_DECLINE_RIDE) return
        val rideId = intent.getStringExtra(EXTRA_RIDE_ID)?.trim().orEmpty()
        if (rideId.isEmpty()) return

        RideAlertStore.markDeclined(context, rideId)

        NotificationManagerCompat.from(context)
            .cancel(RideAlertStore.notificationIdForRide(rideId))

        if (DriverFloatingService.isRunning) {
            val clearIntent = Intent(context, DriverFloatingService::class.java).apply {
                action = DriverFloatingService.ACTION_CLEAR_OFFER
                putExtra(DriverFloatingService.EXTRA_RIDE_ID, rideId)
            }
            try {
                context.startService(clearIntent)
            } catch (_: Exception) {
            }
        }
    }
}
