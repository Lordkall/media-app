import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'notification_navigation.dart';

class LocalNotificationService {
  LocalNotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'salud_now_notifications_v2',
    'Salud Now',
    description: 'Notificaciones de Salud Now',
    importance: Importance.max,
  );

  static Future<void> initialize() async {
    try {
      tz.initializeTimeZones();
    } catch (_) {}

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_salud_now'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        NotificationNavigation.open(response.payload);
      },
    );
    final androidImplementation = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.createNotificationChannel(_channel);
    await androidImplementation?.requestNotificationsPermission();
    await androidImplementation?.requestExactAlarmsPermission();
  }

  static Future<void> showRemoteMessage(RemoteMessage message) async {
    final title = message.notification?.title ?? 'Salud Now';
    final body = message.notification?.body ?? 'Tienes una nueva notificación';
    await _plugin.show(
      message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'salud_now_notifications_v2',
          'Salud Now',
          channelDescription: 'Notificaciones de Salud Now',
          importance: Importance.max,
          priority: Priority.high,
          icon: 'ic_stat_salud_now',
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: message.data['action_url']?.toString(),
    );
  }

  static Future<void> showWaterReminderNow({
    String title = '💧 Momento de hidratarte',
    String body =
        'Toma un vaso de agua (250 ml) para mantener tu cuerpo hidratado y saludable.',
  }) async {
    final now = DateTime.now();
    // Solo enviar entre 6:00 AM y 10:00 PM
    if (now.hour < 6 || now.hour >= 22) return;

    try {
      const channel = AndroidNotificationChannel(
        'salud_now_water_reminders',
        'Recordatorios de Hidratación',
        description: 'Notificaciones periódicas para beber agua',
        importance: Importance.high,
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      await _plugin.show(
        999,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'salud_now_water_reminders',
            'Recordatorios de Hidratación',
            channelDescription: 'Notificaciones periódicas para beber agua',
            importance: Importance.high,
            priority: Priority.high,
            icon: 'ic_stat_salud_now',
            playSound: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: '/health',
      );
    } catch (_) {}
  }

  /// Programa los recordatorios de hidratación a partir de [fromTime] (cuando sumó un vaso de agua)
  /// respetando el intervalo elegido ([intervalHours]) y restringido a la franja de 6:00 AM a 10:00 PM.
  static Future<void> scheduleWaterReminder({
    required int intervalHours,
    DateTime? fromTime,
  }) async {
    try {
      const channel = AndroidNotificationChannel(
        'salud_now_water_reminders',
        'Recordatorios de Hidratación',
        description: 'Notificaciones periódicas para beber agua',
        importance: Importance.high,
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // Cancelar todos los recordatorios previos de agua (990..999)
      await cancelWaterReminder();

      if (intervalHours <= 0) return;

      final start = fromTime ?? DateTime.now();
      DateTime nextCandidate = start.add(Duration(hours: intervalHours));

      // Programar slots para el resto del día activo (hasta las 10:00 PM)
      int slotId = 990;
      while (slotId <= 997) {
        if (nextCandidate.hour >= 22) {
          // Ya es noche (10:00 PM o posterior), no molestar
          break;
        }

        if (nextCandidate.hour >= 6 && nextCandidate.isAfter(DateTime.now())) {
          final tzTime = tz.TZDateTime.from(nextCandidate, tz.local);
          await _plugin.zonedSchedule(
            slotId,
            '💧 Momento de hidratarte',
            'Toma un vaso de agua (250 ml) para mantener tu cuerpo hidratado y saludable.',
            tzTime,
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'salud_now_water_reminders',
                'Recordatorios de Hidratación',
                channelDescription: 'Notificaciones periódicas para beber agua',
                importance: Importance.high,
                priority: Priority.high,
                icon: 'ic_stat_salud_now',
                playSound: true,
              ),
              iOS: DarwinNotificationDetails(
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
              ),
            ),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            payload: '/health',
          );
          slotId++;
        }

        nextCandidate = nextCandidate.add(Duration(hours: intervalHours));
      }

      // Slot para la mañana siguiente a las 8:00 AM (entre 6:00 AM y 10:00 PM)
      final tomorrowMorning = DateTime(
        start.year,
        start.month,
        start.day + 1,
        8,
        0,
      );
      if (tomorrowMorning.isAfter(DateTime.now())) {
        final tomorrowTz = tz.TZDateTime.from(tomorrowMorning, tz.local);
        await _plugin.zonedSchedule(
          998,
          '💧 Momento de hidratarte',
          'Comienza tu día hidratándote con un vaso de agua fresca.',
          tomorrowTz,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'salud_now_water_reminders',
              'Recordatorios de Hidratación',
              channelDescription: 'Notificaciones periódicas para beber agua',
              importance: Importance.high,
              priority: Priority.high,
              icon: 'ic_stat_salud_now',
              playSound: true,
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: '/health',
        );
      }
    } catch (e) {
      debugPrint('Error programando recordatorio de agua: $e');
    }
  }

  static Future<void> cancelWaterReminder() async {
    try {
      for (int id = 990; id <= 999; id++) {
        await _plugin.cancel(id);
      }
    } catch (_) {}
  }

  /// Recordatorio semanal antiestrés programado los miércoles a las 11:00 AM (dentro de 6:00 AM - 10:00 PM).
  static Future<void> scheduleWeeklyBreathingReminder() async {
    try {
      const channel = AndroidNotificationChannel(
        'salud_now_wellness_reminders',
        'Bienestar y Respiración',
        description:
            'Recordatorios semanales para calmar la mente y realizar respiración guiada',
        importance: Importance.high,
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      await cancelWeeklyBreathingReminder();

      final now = tz.TZDateTime.now(tz.local);
      tz.TZDateTime scheduled = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        11,
        0,
      );
      while (scheduled.weekday != DateTime.wednesday ||
          scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      await _plugin.zonedSchedule(
        985,
        '🧘 Momento de pausar y respirar',
        '¿Día agitado o con estrés? Tómate 2 minutos para realizar respiración guiada (4-4-4) en tu Módulo de Salud.',
        scheduled,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'salud_now_wellness_reminders',
            'Bienestar y Respiración',
            channelDescription:
                'Recordatorios semanales para calmar la mente y realizar respiración guiada',
            importance: Importance.high,
            priority: Priority.high,
            icon: 'ic_stat_salud_now',
            playSound: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: '/health',
      );
    } catch (_) {}
  }

  static Future<void> cancelWeeklyBreathingReminder() async {
    try {
      await _plugin.cancel(985);
      await _plugin.cancel(998);
    } catch (_) {}
  }

  /// Notificación Push al completar la meta diaria de pasos (solo entre 6:00 AM y 10:00 PM).
  static Future<void> showStepGoalCompleted({
    required int steps,
    required int goal,
  }) async {
    final now = DateTime.now();
    if (now.hour < 6 || now.hour >= 22) return;

    try {
      const channel = AndroidNotificationChannel(
        'salud_now_step_reminders',
        'Recordatorios de Pasos',
        description: 'Notificaciones de progreso y meta diaria de pasos',
        importance: Importance.high,
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      await _plugin.show(
        980,
        '🎉 ¡Meta diaria de pasos completada!',
        '¡Felicidades! Has alcanzado $steps de $goal pasos hoy. ¡Excelente trabajo por tu salud!',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'salud_now_step_reminders',
            'Recordatorios de Pasos',
            channelDescription:
                'Notificaciones de progreso y meta diaria de pasos',
            importance: Importance.high,
            priority: Priority.high,
            icon: 'ic_stat_salud_now',
            playSound: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: '/health',
      );
    } catch (_) {}
  }

  /// Notificaciones Push periódicas de progreso de pasos (solo entre 6:00 AM y 10:00 PM).
  static Future<void> showStepProgressReminder({
    required int notificationId,
    required String title,
    required int steps,
    required int goal,
    required String message,
  }) async {
    final now = DateTime.now();
    if (now.hour < 6 || now.hour >= 22) return;

    try {
      const channel = AndroidNotificationChannel(
        'salud_now_step_reminders',
        'Recordatorios de Pasos',
        description: 'Notificaciones de progreso y meta diaria de pasos',
        importance: Importance.high,
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      await _plugin.show(
        notificationId,
        title,
        message,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'salud_now_step_reminders',
            'Recordatorios de Pasos',
            channelDescription:
                'Notificaciones de progreso y meta diaria de pasos',
            importance: Importance.high,
            priority: Priority.high,
            icon: 'ic_stat_salud_now',
            playSound: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: '/health',
      );
    } catch (_) {}
  }

  /// Programa los recordatorios diarios de progreso de pasos a las 10:00 AM, 3:00 PM y 8:00 PM.
  /// Al usar zonedSchedule con matchDateTimeComponents.time, el sistema operativo (AlarmManager en Android)
  /// los dispara puntualmente todos los días incluso con la app cerrada.
  static Future<void> scheduleDailyStepReminders() async {
    try {
      const channel = AndroidNotificationChannel(
        'salud_now_step_reminders',
        'Recordatorios de Pasos',
        description: 'Notificaciones de progreso y meta diaria de pasos',
        importance: Importance.high,
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      await cancelStepReminders();

      final now = tz.TZDateTime.now(tz.local);

      final reminders = [
        (
          id: 981,
          hour: 10,
          minute: 0,
          title: '🚶‍♂️ Tus pasos de hoy',
          body:
              '¡Comienza tu día en movimiento! Revisa tus pasos en el Módulo de Salud.',
        ),
        (
          id: 982,
          hour: 15,
          minute: 0,
          title: '🏃‍♂️ Progreso de pasos',
          body:
              '¡Mitad del día! Sigue activo para alcanzar tu meta diaria en el Módulo de Salud.',
        ),
        (
          id: 983,
          hour: 20,
          minute: 0,
          title: '👟 Cierre del día',
          body:
              'Revisa tu resumen diario de pasos y bienestar en tu Módulo de Salud.',
        ),
      ];

      for (final r in reminders) {
        var scheduled = tz.TZDateTime(
          tz.local,
          now.year,
          now.month,
          now.day,
          r.hour,
          r.minute,
        );
        if (scheduled.isBefore(now)) {
          scheduled = scheduled.add(const Duration(days: 1));
        }

        await _plugin.zonedSchedule(
          r.id,
          r.title,
          r.body,
          scheduled,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'salud_now_step_reminders',
              'Recordatorios de Pasos',
              channelDescription:
                  'Notificaciones de progreso y meta diaria de pasos',
              importance: Importance.high,
              priority: Priority.high,
              icon: 'ic_stat_salud_now',
              playSound: true,
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: '/health',
        );
      }
    } catch (e) {
      debugPrint('Error programando recordatorios diarios de pasos: $e');
    }
  }

  static Future<void> cancelStepReminders() async {
    try {
      await _plugin.cancel(980);
      await _plugin.cancel(981);
      await _plugin.cancel(982);
      await _plugin.cancel(983);
    } catch (_) {}
  }
}
