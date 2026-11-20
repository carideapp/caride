package com.caride.app

import android.app.Application
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.graphics.Color
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner

object AppForegroundTracker {
    @Volatile
    var isForeground: Boolean = false
}

object NotificationChannelRegistrar {
    const val CHANNEL_RIDE_REQUESTS = "caride_ride_requests_v2"
    const val CHANNEL_RIDE_ASSIGNED = "caride_ride_assigned_v1"
    const val CHANNEL_CUSTOMER_ALERTS = "caride_customer_alerts"
    const val CHANNEL_FLEET_ALERTS = "caride_fleet_alerts"
    const val CHANNEL_DRIVER_ONLINE = "caride_driver_online"

    fun registerAll(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        val pkg = context.packageName

        val ringtoneAttrs = AudioAttributes.Builder()
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
            .build()

        val rideRequestSoundUri = Uri.parse("android.resource://$pkg/${R.raw.ride_ringtone}")
        val rideRequestChannel = NotificationChannel(
            CHANNEL_RIDE_REQUESTS,
            "Incoming Ride Requests",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Loud ringtone alerts for incoming nearby ride offers"
            setSound(rideRequestSoundUri, ringtoneAttrs)
            enableVibration(true)
            vibrationPattern = longArrayOf(0L, 600L, 300L, 600L, 300L, 800L)
            enableLights(true)
            lightColor = Color.parseColor("#16A34A")
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            setBypassDnd(false)
        }

        val rideAssignedSoundUri = Uri.parse("android.resource://$pkg/${R.raw.ride_assigned}")
        val rideAssignedChannel = NotificationChannel(
            CHANNEL_RIDE_ASSIGNED,
            "Trip Assigned Alerts",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "High-priority alerts when a customer accepts your bid"
            setSound(rideAssignedSoundUri, ringtoneAttrs)
            enableVibration(true)
            vibrationPattern = longArrayOf(0L, 350L, 200L, 350L)
            enableLights(true)
            lightColor = Color.parseColor("#16A34A")
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }

        val customerChannel = NotificationChannel(
            CHANNEL_CUSTOMER_ALERTS,
            "CaRide Alerts",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Ride status notifications"
            enableVibration(true)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }

        val fleetChannel = NotificationChannel(
            CHANNEL_FLEET_ALERTS,
            "CaRide Fleet Alerts",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Fleet manager booking and payment notifications"
            enableVibration(true)
        }

        val driverOnlineChannel = NotificationChannel(
            CHANNEL_DRIVER_ONLINE,
            "CaRide Driver Online",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Keeps CaRide ready for incoming ride requests while you are online"
            setShowBadge(false)
        }

        val driverGeneralChannel = NotificationChannel(
            "caride_alerts",
            "CaRide Driver Alerts",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "General high-priority driver alerts and updates"
            enableVibration(true)
        }

        manager.createNotificationChannels(
            listOf(
                rideRequestChannel,
                rideAssignedChannel,
                customerChannel,
                fleetChannel,
                driverOnlineChannel,
                driverGeneralChannel,
            )
        )
    }
}

class CarideApplication : Application(), DefaultLifecycleObserver {

    override fun onCreate() {
        super<Application>.onCreate()
        NotificationChannelRegistrar.registerAll(this)
        ProcessLifecycleOwner.get().lifecycle.addObserver(this)
    }

    override fun onStart(owner: LifecycleOwner) {
        AppForegroundTracker.isForeground = true
    }

    override fun onStop(owner: LifecycleOwner) {
        AppForegroundTracker.isForeground = false
    }
}
