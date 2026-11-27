package com.saludnow.app

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.drawable.Icon
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject

class MedicationAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra("id", -1)
        when (intent.action) {
            STOP, SNOOZE -> {
                handleAction(context, id, intent.action == SNOOZE)
                return
            }
            ACTION, SNOOZED, TEST -> Unit
            else -> {
                replace(context, saved(context))
                return
            }
        }

        val reminder = reminder(context, id) ?: return
        val now = System.currentTimeMillis()
        val expected = intent.getLongExtra("scheduledAt", 0)
        if (intent.action == TEST) {
            if (id != TEST_ID || now - expected !in 0L..120_000L) return
        } else if (intent.action == SNOOZED) {
            val scheduled = prefs(context).getLong(snoozeKey(id), 0)
            if (scheduled == 0L || scheduled != expected || expected > now) return
            prefs(context).edit().remove(snoozeKey(id)).commit()
        } else {
            val firstAt = reminder.getLong("firstAt")
            if (expected < firstAt || expected > now || (expected - firstAt) % interval(reminder) != 0L) return
            schedule(context, reminder, now)
        }

        val notifications = context.getSystemService(NotificationManager::class.java)
        if (!notifications.areNotificationsEnabled()) return
        if (reminder.optBoolean("alarmMode") && MedicationRingingService.start(context, id)) return
        showNotification(context, reminder)
    }

    companion object {
        fun showNotification(context: Context, reminder: JSONObject) {
            val id = reminder.getInt("id")
            val notifications = context.getSystemService(NotificationManager::class.java)
            if (!notifications.areNotificationsEnabled()) return
            createChannel(notifications)
            val app = PendingIntent.getActivity(
                context, id, Intent(context, MainActivity::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            val title = if (id == TEST_ID) "Prueba de alarma" else "Recordatorio de medicamento"
            val publicAlert = Notification.Builder(context, CHANNEL)
                .setSmallIcon(R.drawable.ic_stat_salud_now)
                .setContentTitle(title)
            val notification = Notification.Builder(context, CHANNEL)
                .setSmallIcon(R.drawable.ic_stat_salud_now)
                .setContentTitle(title)
                .setContentText(reminder.getString("name"))
                .setCategory(Notification.CATEGORY_REMINDER)
                .setVisibility(Notification.VISIBILITY_PRIVATE)
                .setContentIntent(app)
                .setAutoCancel(true)
            if (reminder.optBoolean("alarmMode")) {
                addAlarmActions(notification, context, id)
                addAlarmActions(publicAlert, context, id)
            }
            notifications.notify(TAG, id, notification.setPublicVersion(publicAlert.build()).build())
        }

        private const val ACTION = "com.saludnow.app.MEDICATION_REMINDER"
        private const val TEST = "com.saludnow.app.MEDICATION_TEST"
        const val TEST_ID = -2
        private const val SNOOZED = "com.saludnow.app.MEDICATION_SNOOZED"
        const val STOP = "com.saludnow.app.MEDICATION_STOP"
        const val SNOOZE = "com.saludnow.app.MEDICATION_SNOOZE"
        private const val SNOOZE_MILLIS = 10 * 60 * 1000L
        private const val CHANNEL = "salud_now_medications"
        private const val TAG = "medication_reminder"

        fun reminder(context: Context, id: Int): JSONObject? =
            if (id == TEST_ID) {
                JSONObject().put("id", TEST_ID)
                    .put("name", "Esta es una prueba. No corresponde a una toma.")
                    .put("alarmMode", true)
            } else {
                items(saved(context)).firstOrNull { it.getInt("id") == id }
            }

        fun scheduleTest(context: Context): String {
            val alarms = context.getSystemService(AlarmManager::class.java)
            val notifications = context.getSystemService(NotificationManager::class.java)
            if (!notifications.areNotificationsEnabled()) return "disabled"
            if (!MedicationRingingService.canShowFullScreen(context)) return "fullScreen"
            if (!canScheduleExactly(alarms)) return "approximate"
            cancelTest(context)
            val at = System.currentTimeMillis() + 15_000L
            val intent = alarmIntent(context, TEST_ID, at, TEST)
            return try {
                alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, intent)
                "scheduled"
            } catch (_: SecurityException) {
                "approximate"
            }
        }

        private fun cancelTest(context: Context) {
            val alarms = context.getSystemService(AlarmManager::class.java)
            alarms.cancel(alarmIntent(context, TEST_ID, 0, TEST))
            context.getSystemService(NotificationManager::class.java).cancel(TAG, TEST_ID)
            MedicationRingingService.dismiss(TEST_ID)
        }

        fun addAlarmActions(builder: Notification.Builder, context: Context, id: Int) {
            builder.addAction(Notification.Action.Builder(
                Icon.createWithResource(context, android.R.drawable.ic_menu_close_clear_cancel),
                "Detener",
                alarmIntent(context, id, 0, STOP),
            ).build())
            if (id == TEST_ID) return
            builder.addAction(Notification.Action.Builder(
                Icon.createWithResource(context, android.R.drawable.ic_menu_recent_history),
                "Posponer 10 min",
                alarmIntent(context, id, 0, SNOOZE),
            ).build())
        }

        fun handleAction(context: Context, id: Int, snooze: Boolean) {
            if (id == TEST_ID) {
                cancelTest(context)
                return
            }
            if (snooze && reminder(context, id)?.optBoolean("alarmMode") == true) {
                val at = System.currentTimeMillis() + SNOOZE_MILLIS
                check(prefs(context).edit().putLong(snoozeKey(id), at).commit())
                scheduleAt(context, id, at, SNOOZED)
            }
            MedicationRingingService.dismiss(id)
            context.getSystemService(NotificationManager::class.java).cancel(TAG, id)
        }

        private fun snoozeKey(id: Int) = "snooze_$id"

        fun replace(context: Context, updated: JSONArray): String {
            val previous = items(saved(context)).associateBy { it.getInt("id") }
            val incoming = items(updated)
            val alarms = context.getSystemService(AlarmManager::class.java)
            val notifications = context.getSystemService(NotificationManager::class.java)
            createChannel(notifications)

            check(prefs(context).edit().putString("items", updated.toString()).commit())
            if (incoming.none { it.optBoolean("alarmMode") }) cancelTest(context)
            val incomingById = incoming.associateBy { it.getInt("id") }
            for ((id, old) in previous) {
                val new = incomingById[id]
                if (new == null || new.optBoolean("alarmMode") != old.optBoolean("alarmMode") ||
                    new.getLong("firstAt") != old.getLong("firstAt") ||
                    interval(new) != interval(old)
                ) {
                    alarms.cancel(alarmIntent(context, id, 0, ACTION))
                    alarms.cancel(alarmIntent(context, id, 0, SNOOZED))
                    prefs(context).edit().remove(snoozeKey(id)).commit()
                    notifications.cancel(TAG, id)
                    MedicationRingingService.dismiss(id)
                }
            }

            val now = System.currentTimeMillis()
            var exact = true
            for (reminder in incoming) {
                val id = reminder.getInt("id")
                if (!schedule(context, reminder, now)) exact = false
                val snoozedUntil = prefs(context).getLong(snoozeKey(id), 0)
                if (snoozedUntil > now) {
                    scheduleAt(context, id, snoozedUntil, SNOOZED)
                } else if (snoozedUntil != 0L) {
                    prefs(context).edit().remove(snoozeKey(id)).apply()
                }
            }
            prefs(context).edit().putBoolean("exact", canScheduleExactly(alarms)).apply()
            return status(notifications, exact)
        }

        fun refresh(context: Context): String {
            val alarms = context.getSystemService(AlarmManager::class.java)
            val exact = canScheduleExactly(alarms)
            if (exact != prefs(context).getBoolean("exact", false)) {
                return replace(context, saved(context))
            }
            val notifications = context.getSystemService(NotificationManager::class.java)
            return status(notifications, exact)
        }

        private fun status(notifications: NotificationManager, exact: Boolean): String =
            when {
                !notifications.areNotificationsEnabled() ||
                    notifications.getNotificationChannel(CHANNEL)?.importance == NotificationManager.IMPORTANCE_NONE ->
                    "disabled"
                exact -> "exact"
                else -> "approximate"
            }

        private fun canScheduleExactly(alarms: AlarmManager) =
            Build.VERSION.SDK_INT < 31 || alarms.canScheduleExactAlarms()

        private fun prefs(context: Context) =
            context.getSharedPreferences("medication_alarms", Context.MODE_PRIVATE)

        private fun saved(context: Context) =
            JSONArray(prefs(context).getString("items", "[]"))

        private fun items(array: JSONArray) =
            (0 until array.length()).map { array.getJSONObject(it) }

        private fun interval(reminder: JSONObject) =
            reminder.getLong("intervalHours") * 60 * 60 * 1000

        private fun alarmIntent(context: Context, id: Int, scheduledAt: Long, action: String) =
            PendingIntent.getBroadcast(
                context, id,
                Intent(context, MedicationAlarmReceiver::class.java)
                    .setAction(action)
                    .setData(Uri.parse("saludnow://medication/$id/$action"))
                    .putExtra("id", id)
                    .putExtra("scheduledAt", scheduledAt),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

        private fun schedule(context: Context, reminder: JSONObject, now: Long): Boolean {
            val id = reminder.getInt("id")
            val first = reminder.getLong("firstAt")
            val every = interval(reminder)
            val next = if (first > now) first else first + ((now - first) / every + 1) * every
            return scheduleAt(context, id, next, ACTION)
        }

        private fun scheduleAt(context: Context, id: Int, next: Long, action: String): Boolean {
            val alarms = context.getSystemService(AlarmManager::class.java)
            val intent = alarmIntent(context, id, next, action)
            if (canScheduleExactly(alarms)) {
                try {
                    alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next, intent)
                    return true
                } catch (_: SecurityException) {
                    // Permission may be revoked between checking and scheduling.
                }
            }
            alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next, intent)
            return false
        }

        private fun createChannel(notifications: NotificationManager) {
            val channel = NotificationChannel(CHANNEL, "Medicamentos", NotificationManager.IMPORTANCE_HIGH)
            channel.description = "Avisos para tomar medicamentos"
            channel.enableVibration(true)
            channel.setSound(
                RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM),
                AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).build(),
            )
            notifications.createNotificationChannel(channel)
        }
    }
}
