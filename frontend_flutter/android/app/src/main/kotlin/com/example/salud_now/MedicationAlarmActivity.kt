package com.saludnow.app

import android.animation.ValueAnimator
import android.app.Activity
import android.app.KeyguardManager
import android.content.res.ColorStateList
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.text.format.DateFormat
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.view.animation.LinearInterpolator
import android.widget.Button
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import java.util.Date

class MedicationAlarmActivity : Activity() {
    private val handler = Handler(Looper.getMainLooper())
    private var reminderId = -1
    private var handlingAction = false
    private lateinit var time: TextView
    private lateinit var artwork: AlarmArtwork
    private var pulseAnimator: ValueAnimator? = null

    private val check = object : Runnable {
        override fun run() {
            if (!MedicationRingingService.isRinging(reminderId)) {
                finish()
                return
            }
            val displayTime = DateFormat.getTimeFormat(this@MedicationAlarmActivity).format(Date())
            if (time.text.toString() != displayTime) time.text = displayTime
            handler.postDelayed(this, 500)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT < 27) {
            @Suppress("DEPRECATION")
            window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)
        }
        reminderId = intent.getIntExtra("id", -1)
        if (!MedicationRingingService.isRinging(reminderId)) {
            finish()
            return
        }
        val isTest = reminderId == MedicationAlarmReceiver.TEST_ID
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        window.statusBarColor = BLUE_LIGHT
        window.navigationBarColor = SURFACE
        @Suppress("DEPRECATION")
        window.decorView.systemUiVisibility =
            android.view.View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR or
                android.view.View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR

        val body = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(24), dp(28), dp(24), dp(24))
            background = GradientDrawable(
                GradientDrawable.Orientation.TOP_BOTTOM,
                intArrayOf(BLUE_LIGHT, SURFACE, Color.WHITE),
            )
        }
        body.addView(brandLogo(), LinearLayout.LayoutParams(dp(56), dp(56)).apply {
            gravity = Gravity.CENTER_HORIZONTAL
        })
        time = label(DateFormat.getTimeFormat(this).format(Date()), 56f, INK, true)
        body.addView(time, row(12))
        body.addView(label(if (isTest) "Prueba de alarma" else "Alarma de medicamento", 24f, INK, true), row(4))

        artwork = AlarmArtwork(this)
        body.addView(artwork, LinearLayout.LayoutParams(dp(148), dp(122)).apply {
            gravity = Gravity.CENTER_HORIZONTAL
            topMargin = dp(12)
        })
        body.addView(label("Sonando", 14f, BLUE, true), row(8))

        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(16), dp(16), dp(16), dp(16))
            background = pill(Color.WHITE, 24, BLUE_BORDER)
        }
        val locked = getSystemService(KeyguardManager::class.java).isDeviceLocked
        val name = if (locked || isTest) null else MedicationAlarmReceiver.reminder(this, reminderId)?.optString("name")
        val message = if (isTest) "Este aviso es solo para probar la pantalla bloqueada."
            else "Es hora de tomar tu medicamento"
        card.addView(label(message, 17f, INK, true))
        if (!name.isNullOrBlank()) card.addView(label(name, 16f, BLUE, false), row(6))
        body.addView(card, row(22))

        val controls = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
        }
        if (!isTest) {
            controls.addView(button("Posponer\n10 minutos", false),
                LinearLayout.LayoutParams(0, -2, 1f).apply { marginEnd = dp(6) })
        }
        controls.addView(button("Detener", true),
            LinearLayout.LayoutParams(0, -2, 1f).apply { if (!isTest) marginStart = dp(6) })
        body.addView(controls, row(22))
        setContentView(ScrollView(this).apply {
            isFillViewport = true
            addView(body)
        })
        handler.post(check)
    }

    override fun onStart() {
        super.onStart()
        if (!::artwork.isInitialized || !ValueAnimator.areAnimatorsEnabled()) return
        pulseAnimator = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 1_600L
            repeatCount = ValueAnimator.INFINITE
            interpolator = LinearInterpolator()
            addUpdateListener { artwork.setPulse(it.animatedValue as Float) }
            start()
        }
    }

    override fun onStop() {
        pulseAnimator?.cancel()
        pulseAnimator = null
        super.onStop()
    }

    private fun brandLogo() = ImageView(this).apply {
        contentDescription = "Salud Now"
        scaleType = ImageView.ScaleType.FIT_CENTER
        val logo = runCatching {
            // Reuse the same transparent mark bundled by the Flutter app.
            assets.open("flutter_assets/assets/logo_icon.png").use {
                BitmapFactory.decodeStream(it, null, BitmapFactory.Options().apply { inSampleSize = 4 })
            }
        }.getOrNull()
        if (logo == null) setImageResource(R.mipmap.ic_launcher) else setImageBitmap(logo)
    }

    private fun button(label: String, stop: Boolean) = Button(this).apply {
        text = label
        contentDescription = label.replace('\n', ' ')
        isAllCaps = false
        textSize = 16f
        setTypeface(typeface, Typeface.BOLD)
        setTextColor(if (stop) Color.WHITE else BLUE)
        minHeight = dp(64)
        setPadding(dp(10), dp(8), dp(10), dp(8))
        background = RippleDrawable(
            ColorStateList.valueOf(if (stop) Color.argb(45, 255, 255, 255) else BLUE_BORDER),
            pill(if (stop) BLUE else Color.WHITE, 24, BLUE),
            null,
        )
        setOnClickListener {
            if (handlingAction || !MedicationRingingService.isRinging(reminderId)) return@setOnClickListener
            handlingAction = true
            try {
                MedicationAlarmReceiver.handleAction(this@MedicationAlarmActivity, reminderId, snooze = !stop)
                finish()
            } catch (_: RuntimeException) {
                handlingAction = false
                Toast.makeText(this@MedicationAlarmActivity, "No se pudo posponer la alarma.", Toast.LENGTH_SHORT).show()
            }
        }
    }

    private fun label(value: String, size: Float, color: Int, bold: Boolean) = TextView(this).apply {
        text = value
        textSize = size
        gravity = Gravity.CENTER
        setTextColor(color)
        if (bold) setTypeface(typeface, Typeface.BOLD)
    }

    private fun row(top: Int) = LinearLayout.LayoutParams(-1, -2).apply { topMargin = dp(top) }

    private fun pill(fill: Int, radius: Int, stroke: Int) = GradientDrawable().apply {
        setColor(fill)
        cornerRadius = dp(radius).toFloat()
        setStroke(dp(1), stroke)
    }

    private fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()

    override fun onDestroy() {
        handler.removeCallbacks(check)
        super.onDestroy()
    }

    private class AlarmArtwork(context: android.content.Context) : View(context) {
        private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        private val density = resources.displayMetrics.density
        private var phase = 0f

        init {
            importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_NO
        }

        fun setPulse(value: Float) {
            phase = value
            invalidate()
        }

        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)
            canvas.save()
            canvas.translate(width / 2f, height / 2f)
            canvas.scale(density, density)

            paint.style = Paint.Style.STROKE
            paint.strokeWidth = 1.5f
            paint.color = BLUE
            for (ring in 0..1) {
                val progress = (phase + ring * 0.5f) % 1f
                paint.alpha = ((1f - progress) * 115).toInt()
                canvas.drawCircle(0f, 0f, 44f + progress * 15f, paint)
            }

            paint.color = BLUE_LIGHT
            paint.style = Paint.Style.FILL
            canvas.drawCircle(0f, 0f, 43f, paint)
            paint.color = BLUE_BORDER
            paint.style = Paint.Style.STROKE
            canvas.drawCircle(0f, 0f, 43f, paint)

            paint.color = BLUE
            paint.strokeWidth = 3f
            paint.strokeCap = Paint.Cap.ROUND
            canvas.drawCircle(0f, 0f, 17f, paint)
            canvas.drawLine(0f, -9f, 0f, 0f, paint)
            canvas.drawLine(0f, 0f, 7f, 5f, paint)
            canvas.drawArc(-25f, -25f, 25f, 25f, 194f, 45f, false, paint)
            canvas.drawArc(-25f, -25f, 25f, 25f, 301f, 45f, false, paint)
            canvas.drawLine(-12f, 13f, -16f, 18f, paint)
            canvas.drawLine(12f, 13f, 16f, 18f, paint)

            canvas.translate(42f, 31f)
            paint.color = Color.WHITE
            paint.style = Paint.Style.FILL
            canvas.drawCircle(0f, 0f, 19f, paint)
            paint.color = BLUE_BORDER
            paint.strokeWidth = 1f
            paint.style = Paint.Style.STROKE
            canvas.drawCircle(0f, 0f, 19f, paint)

            canvas.rotate(-38f)
            paint.style = Paint.Style.FILL
            paint.color = BLUE_LIGHT
            canvas.drawRoundRect(-12f, -5.5f, 12f, 5.5f, 5.5f, 5.5f, paint)
            canvas.save()
            canvas.clipRect(0f, -6f, 13f, 6f)
            paint.color = BLUE
            canvas.drawRoundRect(-12f, -5.5f, 12f, 5.5f, 5.5f, 5.5f, paint)
            canvas.restore()
            paint.color = BLUE
            paint.style = Paint.Style.STROKE
            canvas.drawRoundRect(-12f, -5.5f, 12f, 5.5f, 5.5f, 5.5f, paint)

            canvas.restore()
        }
    }

    companion object {
        private val INK = Color.rgb(11, 37, 69)
        private val BLUE = Color.rgb(7, 86, 164)
        private val BLUE_LIGHT = Color.rgb(226, 241, 248)
        private val BLUE_BORDER = Color.rgb(190, 216, 235)
        private val SURFACE = Color.rgb(248, 250, 252)
    }
}
