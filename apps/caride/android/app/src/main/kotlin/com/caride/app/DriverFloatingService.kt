package com.caride.app

import android.animation.ObjectAnimator
import android.animation.PropertyValuesHolder
import android.animation.ValueAnimator
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.IBinder
import android.provider.Settings
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
import kotlin.math.abs

class DriverFloatingService : Service() {

    companion object {
        const val ACTION_START = "com.caride.app.ACTION_START_FLOATING"
        const val ACTION_STOP = "com.caride.app.ACTION_STOP_FLOATING"
        const val ACTION_NOTIFY_OFFER = "com.caride.app.ACTION_NOTIFY_OFFER"
        const val ACTION_CLEAR_OFFER = "com.caride.app.ACTION_CLEAR_OFFER"

        const val EXTRA_TITLE = "extra_title"
        const val EXTRA_SUBTITLE = "extra_subtitle"
        const val EXTRA_COUNT = "extra_count"
        const val EXTRA_OPEN_REQUESTS = "open_ride_requests"

        private const val CHANNEL_ID = "caride_floating_driver"
        private const val NOTIFICATION_ID = 4091
    }

    private lateinit var windowManager: WindowManager
    private var rootView: LinearLayout? = null
    private var layoutParams: WindowManager.LayoutParams? = null
    private var badgeView: TextView? = null
    private var bannerView: TextView? = null
    private var pulseAnimator: ObjectAnimator? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                removeOverlay()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_NOTIFY_OFFER -> {
                if (rootView == null) {
                    startForeground(NOTIFICATION_ID, buildNotification())
                    showOverlay()
                }
                val title = intent.getStringExtra(EXTRA_TITLE) ?: "New Ride Offer"
                val count = intent.getIntExtra(EXTRA_COUNT, 1)
                showOfferAlert(title, count)
                return START_STICKY
            }
            ACTION_CLEAR_OFFER -> {
                clearOfferAlert()
                return START_STICKY
            }
            else -> {
                startForeground(NOTIFICATION_ID, buildNotification())
                if (rootView == null) {
                    showOverlay()
                }
                return START_STICKY
            }
        }
    }

    override fun onDestroy() {
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
            setStroke(dp(2), Color.parseColor("#0A8754"))
        }

        val logoImage = ImageView(this).apply {
            setImageResource(R.drawable.caride_driver_logo)
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

        val bannerBg = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = dp(16).toFloat()
            setColor(Color.parseColor("#111827"))
            setStroke(dp(1), Color.parseColor("#0A8754"))
        }

        val banner = TextView(this).apply {
            background = bannerBg
            setTextColor(Color.WHITE)
            textSize = 12f
            setTypeface(null, Typeface.BOLD)
            setPadding(dp(12), dp(8), dp(12), dp(8))
            visibility = View.GONE
        }

        val bannerParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.WRAP_CONTENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            marginStart = dp(8)
        }

        container.addView(bubbleFrame)
        container.addView(banner, bannerParams)

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

        attachDragAndTapListener(container, params)

        rootView = container
        layoutParams = params
        badgeView = badge
        bannerView = banner

        windowManager.addView(container, params)
    }

    private fun attachDragAndTapListener(view: View, params: WindowManager.LayoutParams) {
        var initialX = 0
        var initialY = 0
        var initialTouchX = 0f
        var initialTouchY = 0f
        var moved = false

        view.setOnTouchListener { _, event ->
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
                    windowManager.updateViewLayout(view, params)
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (!moved) {
                        openAppToRequests()
                    }
                    true
                }
                else -> false
            }
        }
    }

    private fun showOfferAlert(title: String, count: Int) {
        badgeView?.apply {
            text = if (count > 9) "9+" else count.toString()
            visibility = View.VISIBLE
        }
        bannerView?.apply {
            text = "$title • Tap to view"
            visibility = View.VISIBLE
        }
        rootView?.let { target ->
            pulseAnimator?.cancel()
            pulseAnimator = ObjectAnimator.ofPropertyValuesHolder(
                target,
                PropertyValuesHolder.ofFloat(View.SCALE_X, 1f, 1.08f, 1f),
                PropertyValuesHolder.ofFloat(View.SCALE_Y, 1f, 1.08f, 1f)
            ).apply {
                duration = 700
                repeatCount = ValueAnimator.INFINITE
                start()
            }
        }
    }

    private fun clearOfferAlert() {
        pulseAnimator?.cancel()
        pulseAnimator = null
        rootView?.apply {
            scaleX = 1f
            scaleY = 1f
        }
        badgeView?.visibility = View.GONE
        bannerView?.visibility = View.GONE
    }

    private fun openAppToRequests() {
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(EXTRA_OPEN_REQUESTS, true)
        }
        startActivity(launchIntent)
        clearOfferAlert()
    }

    private fun removeOverlay() {
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
        bannerView = null
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "CaRide Driver Online",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps the CaRide floating driver icon active while you are online."
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
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

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("CaRide Driver Online")
            .setContentText("Floating icon active for incoming ride offers")
            .setSmallIcon(R.drawable.caride_driver_logo)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }
}

