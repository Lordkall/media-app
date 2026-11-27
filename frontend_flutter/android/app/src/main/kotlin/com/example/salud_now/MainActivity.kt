package com.saludnow.app

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "salud_now/medication_reminders")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "replace" -> {
                            val reminders = call.arguments as? List<*> ?: emptyList<Any>()
                            result.success(MedicationAlarmReceiver.replace(applicationContext, JSONArray(reminders)))
                        }
                        "scheduleScreenTest" -> result.success(MedicationAlarmReceiver.scheduleTest(applicationContext))
                        "refresh" -> result.success(MedicationAlarmReceiver.refresh(applicationContext))
                        "canShowFullScreen" -> result.success(MedicationRingingService.canShowFullScreen(this))
                        "requestFullScreen" -> {
                            if (Build.VERSION.SDK_INT >= 34 && !MedicationRingingService.canShowFullScreen(this)) {
                                startActivity(Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT,
                                    Uri.parse("package:$packageName")))
                            }
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (_: Exception) {
                    result.error("medication_schedule", "No se pudieron programar los avisos.", null)
                }
            }
    }
}
