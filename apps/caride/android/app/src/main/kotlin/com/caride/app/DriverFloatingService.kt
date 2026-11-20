package com.caride.app

import android.animation.ObjectAnimator
import android.animation.PropertyValuesHolder
import android.animation.ValueAnimator
import android.app.Notification
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.Ringtone
import android.media.RingtoneManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.text.TextUtils
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import kotlin.math.abs

class DriverFloatingService : Service() {

    companion object {
        @Volatile
        var isRunning: Boolean = false

        const val ACTION_START = "com.caride.app.ACTION_START_FLOATING"
        const val ACTION_STOP = "com.caride.app.ACTION_STOP_FLOATING"
        const val ACTION_NOTIFY_OFFER = "com.caride.app.ACTION_NOTIFY_OFFER"
        const val ACTION_CLEAR_OFFER = "com.caride.app.ACTION_CLEAR_OFFER"

        const val EXTRA_TITLE = "extra_title"
        const val EXTRA_SUBTITLE = "extra_subtitle"
        const val EXTRA_COUNT = "extra_count"
        const val EXTRA_OPEN_REQUESTS = "open_ride_requests"
        const val EXTRA_RIDE_ID = "extra_ride_id"
        const val EXTRA_PICKUP_LABEL = "extra_pickup_label"
        const val EXTRA_DROPOFF_LABEL = "extra_dropoff_label"
        const val EXTRA_DISTANCE_KM = "extra_distance_km"
        const val EXTRA_PAYMENT_METHOD = "extra_payment_method"
        const val EXTRA_REMAINING_MS = "extra_remaining_ms"

        private const val NOTIFICATION_ID = 4091
    }

    private lateinit var windowManager: WindowManager
    private var rootView: LinearLayout? = null
    private var layoutParams: WindowManager.LayoutParams? = null
    private var badgeView: TextView? = null
    private var offerCardView: LinearLayout? = null
    private var offerTitleView: TextView? = null
    private var offerRouteView: TextView? = null
    private var offerMetaView: TextView? = null
    private var activeRideId: String? = null
    private var pulseAnimator: ObjectAnimator? = null
    private var mediaPlayer: MediaPlayer? = null
    private var activeRingtone: Ringtone? = null
    private val ringtoneHandler = Handler(Looper.getMainLooper())
    private val stopAlertRunnable = Runnable { clearOfferAlert() }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        NotificationChannelRegistrar.registerAll(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                isRunning = false
                removeOverlay()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_NOTIFY_OFFER -> {
                if (!Settings.canDrawOverlays(this)) {
                    isRunning = false
                    stopSelf()
                    return START_NOT_STICKY
                }
                if (rootView == null) {
                    startForeground(NOTIFICATION_ID, buildNotification())
                    isRunning = true
                    showOverlay()
                } else {
                    isRunning = true
                }
                val rideId = intent.getStringExtra(EXTRA_RIDE_ID)?.trim().orEmpty()
                if (rideId.isNotEmpty() && RideAlertStore.isDeclined(this, rideId)) {
                    return START_STICKY
                }
                val title = intent.getStringExtra(EXTRA_TITLE) ?: "New Ride Offer"
                val count = intent.getIntExtra(EXTRA_COUNT, 1)
                val pickupLabel = intent.getStringExtra(EXTRA_PICKUP_LABEL)?.trim().orEmpty()
                val dropoffLabel = intent.getStringExtra(EXTRA_DROPOFF_LABEL)?.trim().orEmpty()
                val distanceKm = intent.getStringExtra(EXTRA_DISTANCE_KM)?.trim().orEmpty()
                val paymentMethod = intent.getStringExtra(EXTRA_PAYMENT_METHOD)?.trim().orEmpty()
                val remainingMs = intent.getLongExtra(EXTRA_REMAINING_MS, 45_000L).coerceIn(5_000L, 60_000L)
                showOfferAlert(
                    rideId = rideId.ifEmpty { null },
                    title = title,
                    count = count,
                    pickupLabel = pickupLabel,
                    dropoffLabel = dropoffLabel,
                    distanceKm = distanceKm,
                    paymentMethod = paymentMethod,
                    remainingMs = remainingMs,
                )
                return START_STICKY
            }
            ACTION_CLEAR_OFFER -> {
                val cancelRideId = intent.getStringExtra(EXTRA_RIDE_ID)?.trim().orEmpty()
                if (cancelRideId.isEmpty() || activeRideId == null || cancelRideId == activeRideId) {
                    clearOfferAlert()
                }
                return START_STICKY
            }
            else -> {
                if (!Settings.canDrawOverlays(this)) {
                    isRunning = false
                    stopSelf()
                    return START_NOT_STICKY
                }
                startForeground(NOTIFICATION_ID, buildNotification())
                isRunning = true
                if (rootView == null) {
                    showOverlay()
                }
                return START_STICKY
            }
        }
    }

    override fun onDestroy() {
        isRunning = false
        removeOverlay()
        super.onDestroy()
    }

    private fun dp(value: Int): Int =
        TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            value.toFloat(),
            resources.displayMetrics
        ).toInt()

    private fun showOverlay() {
        if (!Settings.canDrawOverlays(this)) return

        val container = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }

        val bubbleFrame = FrameLayout(this)
        val bubbleSize = dp(58)

        val circleBg = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(Color.WHITE)
            setStroke(dp(2), Color.parseColor("#16A34A"))
        }

        val logoImage = ImageView(this).apply {
            setImageResource(R.drawable.caride_floating_icon)
            scaleType = ImageView.ScaleType.CENTER_CROP
            background = circleBg
            setPadding(dp(6), dp(6), dp(6), dp(6))
            clipToOutline = true
        }

        val badgeBg = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(Color.parseColor("#E53935"))
            setStroke(dp(2), Color.WHITE)
        }

        val badge = TextView(this).apply {
            background = badgeBg
            setTextColor(Color.WHITE)
            textSize = 11f
            setTypeface(null, Typeface.BOLD)
            gravity = Gravity.CENTER
            visibility = View.GONE
        }

        bubbleFrame.addView(logoImage, FrameLayout.LayoutParams(bubbleSize, bubbleSize))
        val badgeSize = dp(22)
        val badgeParams = FrameLayout.LayoutParams(badgeSize, badgeSize).apply {
            gravity = Gravity.TOP or Gravity.END
        }
        bubbleFrame.addView(badge, badgeParams)

        val cardBg = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = dp(16).toFloat()
            setColor(Color.parseColor("#111827"))
            setStroke(dp(1), Color.parseColor("#16A34A"))
        }

        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            background = cardBg
            setPadding(dp(12), dp(10), dp(12), dp(10))
            visibility = View.GONE
            setOnClickListener { openAppToRequests(activeRideId) }
        }

        val titleView = TextView(this).apply {
            setTextColor(Color.WHITE)
            textSize = 13f
            setTypeface(null, Typeface.BOLD)
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.END
        }

        val routeView = TextView(this).apply {
            setTextColor(Color.parseColor("#E5E7EB"))
            textSize = 12f
            maxLines = 2
            ellipsize = TextUtils.TruncateAt.END
            visibility = View.GONE
        }
        val routeParams = LinearLayout.LayoutParams(
            dp(220),
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            topMargin = dp(2)
        }

        val metaView = TextView(this).apply {
            setTextColor(Color.parseColor("#86EFAC"))
            textSize = 11f
            setTypeface(null, Typeface.BOLD)
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.END
            visibility = View.GONE
        }
        val metaParams = LinearLayout.LayoutParams(
            dp(220),
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            topMargin = dp(3)
        }

        val actionsRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        val actionsParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.WRAP_CONTENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            topMargin = dp(8)
        }

        val openBtnBg = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = dp(10).toFloat()
            setColor(Color.parseColor("#16A34A"))
        }
        val openBtn = TextView(this).apply {
            text = "Open & Bid"
            background = openBtnBg
            setTextColor(Color.WHITE)
            textSize = 12f
            setTypeface(null, Typeface.BOLD)
            setPadding(dp(12), dp(6), dp(12), dp(6))
            setOnClickListener { openAppToRequests(activeRideId) }
        }

        val dismissBtnBg = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = dp(10).toFloat()
            setColor(Color.parseColor("#1F2937"))
            setStroke(dp(1), Color.parseColor("#374151"))
        }
        val dismissBtn = TextView(this).apply {
            text = "Dismiss"
            background = dismissBtnBg
            setTextColor(Color.parseColor("#D1D5DB"))
            textSize = 12f
            setTypeface(null, Typeface.BOLD)
            setPadding(dp(12), dp(6), dp(12), dp(6))
            setOnClickListener { dismissCurrentOffer() }
        }
        val dismissParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.WRAP_CONTENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            marginStart = dp(8)
        }

        actionsRow.addView(openBtn)
        actionsRow.addView(dismissBtn, dismissParams)

        card.addView(titleView)
        card.addView(routeView, routeParams)
        card.addView(metaView, metaParams)
        card.addView(actionsRow, actionsParams)

        val cardParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.WRAP_CONTENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            marginStart = dp(8)
        }

        container.addView(bubbleFrame)
        container.addView(card, cardParams)

        val overlayType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            overlayType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = dp(16)
            y = dp(180)
        }

        attachDragAndTapListener(bubbleFrame, container, params)

        rootView = container
        layoutParams = params
        badgeView = badge
        offerCardView = card
        offerTitleView = titleView
        offerRouteView = routeView
        offerMetaView = metaView

        windowManager.addView(container, params)
    }

    private fun attachDragAndTapListener(
        dragTarget: View,
        container: View,
        params: WindowManager.LayoutParams,
    ) {
        var initialX = 0
        var initialY = 0
        var initialTouchX = 0f
        var initialTouchY = 0f
        var moved = false

        dragTarget.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialX = params.x
                    initialY = params.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    moved = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = (event.rawX - initialTouchX).toInt()
                    val dy = (event.rawY - initialTouchY).toInt()
                    if (abs(dx) > 8 || abs(dy) > 8) {
                        moved = true
                    }
                    params.x = initialX + dx
                    params.y = initialY + dy
                    windowManager.updateViewLayout(container, params)
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (!moved) {
                        openAppToRequests(activeRideId)
                    }
                    true
                }
                else -> false
            }
        }
    }

    private fun showOfferAlert(
        rideId: String?,
        title: String,
        count: Int,
        pickupLabel: String,
        dropoffLabel: String,
        distanceKm: String,
        paymentMethod: String,
        remainingMs: Long,
    ) {
        activeRideId = rideId
        badgeView?.apply {
            text = if (count > 9) "9+" else count.toString()
            visibility = View.VISIBLE
        }
        offerTitleView?.text = title

        val routeText = when {
            pickupLabel.isNotEmpty() && dropoffLabel.isNotEmpty() -> "$pickupLabel -> $dropoffLabel"
            pickupLabel.isNotEmpty() -> pickupLabel
            dropoffLabel.isNotEmpty() -> dropoffLabel
            else -> ""
        }
        offerRouteView?.apply {
            if (routeText.isNotEmpty()) {
                text = routeText
                visibility = View.VISIBLE
            } else {
                visibility = View.GONE
            }
        }

        val metaParts = mutableListOf<String>()
        if (distanceKm.isNotEmpty()) {
            metaParts.add("$distanceKm km away")
        }
        if (paymentMethod.isNotEmpty()) {
            metaParts.add(paymentMethod.replaceFirstChar { it.uppercaseChar() })
        }
        val metaText = metaParts.joinToString(" • ")
        offerMetaView?.apply {
            if (metaText.isNotEmpty()) {
                text = metaText
                visibility = View.VISIBLE
            } else {
                visibility = View.GONE
            }
        }

        offerCardView?.visibility = View.VISIBLE

        rootView?.let { target ->
            pulseAnimator?.cancel()
            pulseAnimator = ObjectAnimator.ofPropertyValuesHolder(
                target,
                PropertyValuesHolder.ofFloat(View.SCALE_X, 1f, 1.06f, 1f),
                PropertyValuesHolder.ofFloat(View.SCALE_Y, 1f, 1.06f, 1f)
            ).apply {
                duration = 700
                repeatCount = ValueAnimator.INFINITE
                start()
            }
        }
        playRingtone(remainingMs)
    }

    private fun playRingtone(durationMs: Long) {
        stopRingtone()
        val ringAttrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

        var started = false
        try {
            val afd = resources.openRawResourceFd(R.raw.ride_ringtone)
            mediaPlayer = MediaPlayer().apply {
                setAudioAttributes(ringAttrs)
                setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                isLooping = true
                prepare()
                start()
            }
            afd.close()
            started = true
        } catch (_: Exception) {
            try {
                mediaPlayer?.release()
            } catch (_: Exception) {
            }
            mediaPlayer = null
        }

        if (!started) {
            try {
                val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
                    ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                activeRingtone = RingtoneManager.getRingtone(applicationContext, uri)?.apply {
                    audioAttributes = ringAttrs
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                        isLooping = true
                    }
                    play()
                }
            } catch (_: Exception) {
            }
        }

        ringtoneHandler.postDelayed(stopAlertRunnable, durationMs.coerceIn(5_000L, 60_000L))
    }

    private fun stopRingtone() {
        ringtoneHandler.removeCallbacks(stopAlertRunnable)
        try {
            mediaPlayer?.let { mp ->
                if (mp.isPlaying) mp.stop()
                mp.release()
            }
        } catch (_: Exception) {
        }
        mediaPlayer = null
        try {
            activeRingtone?.stop()
        } catch (_: Exception) {
        }
        activeRingtone = null
    }

    private fun clearOfferAlert() {
        stopRingtone()
        activeRideId = null
        pulseAnimator?.cancel()
        pulseAnimator = null
        rootView?.apply {
            scaleX = 1f
            scaleY = 1f
        }
        badgeView?.visibility = View.GONE
        offerCardView?.visibility = View.GONE
    }

    private fun dismissCurrentOffer() {
        val rideId = activeRideId
        if (!rideId.isNullOrEmpty()) {
            RideAlertStore.markDeclined(this, rideId)
            NotificationManagerCompat.from(this)
                .cancel(RideAlertStore.notificationIdForRide(rideId))
        }
        clearOfferAlert()
    }

    private fun openAppToRequests(rideId: String?) {
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(EXTRA_OPEN_REQUESTS, true)
            if (!rideId.isNullOrEmpty()) {
                putExtra(CarideFirebaseMessagingService.EXTRA_RIDE_ID, rideId)
                putExtra(CarideFirebaseMessagingService.EXTRA_ALERT_TYPE, "ride_request")
            }
        }
        startActivity(launchIntent)
        clearOfferAlert()
    }

    private fun removeOverlay() {
        stopRingtone()
        activeRideId = null
        pulseAnimator?.cancel()
        pulseAnimator = null
        rootView?.let {
            try {
                windowManager.removeView(it)
            } catch (_: Exception) {
            }
        }
        rootView = null
        badgeView = null
        offerCardView = null
        offerTitleView = null
        offerRouteView = null
        offerMetaView = null
    }

    private fun buildNotification(): Notification {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(EXTRA_OPEN_REQUESTS, true)
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, NotificationChannelRegistrar.CHANNEL_DRIVER_ONLINE)
            .setContentTitle("CaRide Driver Online")
            .setContentText("Floating bubble ready for incoming ride requests")
            .setSmallIcon(R.drawable.ic_stat_caride)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }
}
