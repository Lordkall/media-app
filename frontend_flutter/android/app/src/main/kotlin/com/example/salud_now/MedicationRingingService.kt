package com.saludnow.app

import android.app.KeyguardManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.provider.Settings

class MedicationRingingService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private val pending = linkedSetOf<Int>()
    private var ringingId: Int? = null
    private var player: MediaPlayer? = null
    private val timeout = Runnable { completeCurrent() }

    override fun onCreate() {
        super.onCreate()
        running = this
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val id = intent?.getIntExtra("id", -1) ?: -1
        val reminder = MedicationAlarmReceiver.reminder(this, id)
        if (reminder?.optBoolean("alarmMode") == true && ringingId != id) pending.add(id)
        if (ringingId == null) ringNext()
        return START_NOT_STICKY
    }

    private fun ringNext() {
        while (pending.isNotEmpty()) {
            val id = pending.first()
            pending.remove(id)
            val reminder = MedicationAlarmReceiver.reminder(this, id) ?: continue
            if (!reminder.optBoolean("alarmMode")) continue
            ringingId = id
            try {
                startForeground(NOTIFICATION_ID, notification(id, reminder.getString("name")))
            } catch (_: RuntimeException) {
                ringingId = null
                MedicationAlarmReceiver.showNotification(this, reminder)
                continue
            }
            launchAlarmScreenIfActiveOrPermitted(id)
            startSoundAndVibration()
            val duration = if (id == MedicationAlarmReceiver.TEST_ID) 30_000L else RING_DURATION
            handler.postDelayed(timeout, duration)
            return
        }
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun launchAlarmScreenIfActiveOrPermitted(id: Int) {
        val keyguard = getSystemService(KeyguardManager::class.java)
        val power = getSystemService(PowerManager::class.java)
        val isScreenLockedOrOff = keyguard.isKeyguardLocked || !power.isInteractive
        // Full-screen intent handles locked/off screens; when unlocked/in-use (inside app or with overlay permission),
        // explicitly bring MedicationAlarmActivity to screen so it doesn't stay just as a banner notification.
        if (!isScreenLockedOrOff || Settings.canDrawOverlays(this)) {
            val activityIntent = Intent(this, MedicationAlarmActivity::class.java)
                .putExtra("id", id)
                .addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP or
                        Intent.FLAG_ACTIVITY_REORDER_TO_FRONT,
                )
            try {
                startActivity(activityIntent)
            } catch (_: Exception) {
                // Background Activity Launch restriction when overlay is disabled while in another app.
            }
        }
    }

    private fun notification(id: Int, name: String): Notification {
        val activity = Intent(this, MedicationAlarmActivity::class.java)
            .putExtra("id", id)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        val display = PendingIntent.getActivity(
            this, id, activity, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val title = if (id == MedicationAlarmReceiver.TEST_ID) {
            "Prueba de alarma"
        } else {
            "Hora de tomar tu medicamento"
        }
        val publicAlert = Notification.Builder(this, CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_salud_now)
            .setContentTitle(title)
        MedicationAlarmReceiver.addAlarmActions(publicAlert, this, id)
        val builder = Notification.Builder(this, CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_salud_now)
            .setContentTitle(title)
            .setContentText(name)
            .setCategory(Notification.CATEGORY_ALARM)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .setPublicVersion(publicAlert.build())
            .setOngoing(true)
            .setContentIntent(display)
        MedicationAlarmReceiver.addAlarmActions(builder, this, id)
        if (canShowFullScreen(this)) builder.setFullScreenIntent(display, true)
        return builder.build()
    }

    private fun startSoundAndVibration() {
        val notifications = getSystemService(NotificationManager::class.java)
        val filter = notifications.currentInterruptionFilter
        if (filter != NotificationManager.INTERRUPTION_FILTER_ALL &&
            filter != NotificationManager.INTERRUPTION_FILTER_ALARMS
        ) return

        val sound = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
        if (sound != null) {
            val playback = MediaPlayer()
            player = playback
            try {
                playback.setAudioAttributes(AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build())
                playback.setWakeMode(this, PowerManager.PARTIAL_WAKE_LOCK)
                playback.setDataSource(this, sound)
                playback.isLooping = true
                playback.setOnPreparedListener {
                    if (player === it) {
                        try {
                            it.start()
                        } catch (_: IllegalStateException) {
                            releasePlayer()
                        }
                    }
                }
                playback.setOnErrorListener { source, _, _ ->
                    if (source === player) releasePlayer()
                    true
                }
                playback.prepareAsync()
            } catch (_: Exception) {
                releasePlayer()
            }
        }
        if (notifications.getNotificationChannel(CHANNEL)?.shouldVibrate() == true) {
            val pattern = LongArray(30) { index ->
                if (index % 2 == 0) 3_450L else 550L
            }
            pattern[0] = 0
            getSystemService(Vibrator::class.java).vibrate(
                VibrationEffect.createWaveform(pattern, -1)
            )
        }
    }

    private fun releasePlayer() {
        player?.release()
        player = null
    }

    private fun completeCurrent() {
        handler.removeCallbacks(timeout)
        releasePlayer()
        getSystemService(Vibrator::class.java).cancel()
        ringingId = null
        ringNext()
    }

    override fun onDestroy() {
        running = null
        handler.removeCallbacks(timeout)
        releasePlayer()
        getSystemService(Vibrator::class.java).cancel()
        super.onDestroy()
    }

    companion object {
        private const val CHANNEL = "salud_now_medications_alarm"
        private const val NOTIFICATION_ID = 701040
        private const val RING_DURATION = 60_000L
        private var running: MedicationRingingService? = null

        fun start(context: Context, id: Int): Boolean {
            val notifications = context.getSystemService(NotificationManager::class.java)
            val channel = NotificationChannel(CHANNEL, "Alarmas de medicamentos", NotificationManager.IMPORTANCE_HIGH)
            channel.description = "Avisos de medicamentos con sonido repetido"
            channel.setSound(null, null)
            channel.enableVibration(true)
            notifications.createNotificationChannel(channel)
            if (notifications.getNotificationChannel(CHANNEL)?.importance == NotificationManager.IMPORTANCE_NONE) return false
            return try {
                context.startForegroundService(Intent(context, MedicationRingingService::class.java).putExtra("id", id))
                true
            } catch (_: RuntimeException) {
                false
            }
        }

        fun canShowFullScreen(context: Context): Boolean =
            Build.VERSION.SDK_INT < 34 ||
                context.getSystemService(NotificationManager::class.java).canUseFullScreenIntent()

        fun isRinging(id: Int): Boolean = running?.ringingId == id

        fun dismiss(id: Int) {
            val service = running ?: return
            service.pending.remove(id)
            if (service.ringingId == id) service.completeCurrent()
        }
    }
}
