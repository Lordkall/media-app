import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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

  static Future<void> scheduleWaterReminder({required int intervalHours}) async {
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

      await cancelWaterReminder();

      await _plugin.periodicallyShowWithDuration(
        999,
        '💧 Momento de hidratarte',
        'Toma un vaso de agua (250 ml) para mantener tu cuerpo hidratado y saludable.',
        Duration(hours: intervalHours),
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
      );
    } catch (_) {}
  }

  static Future<void> cancelWaterReminder() async {
    try {
      await _plugin.cancel(999);
    } catch (_) {}
  }

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

      await _plugin.periodicallyShow(
        998,
        '🧘 Momento de pausar y respirar',
        '¿Día agitado o con estrés? Tómate 2 minutos para realizar respiración guiada (4-4-4) en tu Módulo de Salud.',
        RepeatInterval.weekly,
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
      );
    } catch (_) {}
  }

  static Future<void> cancelWeeklyBreathingReminder() async {
    try {
      await _plugin.cancel(998);
    } catch (_) {}
  }
}
