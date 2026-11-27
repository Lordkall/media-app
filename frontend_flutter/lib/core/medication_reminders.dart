import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MedicationReminder {
  const MedicationReminder({
    required this.id,
    required this.name,
    required this.hour,
    required this.minute,
    required this.intervalHours,
    required this.firstAt,
    this.enabled = true,
    this.alarmMode = false,
  });

  factory MedicationReminder.fromJson(Map<String, dynamic> data) =>
      MedicationReminder(
        id: data['id'] as int,
        name: data['name'] as String,
        hour: data['hour'] as int,
        minute: data['minute'] as int,
        intervalHours: data['intervalHours'] as int,
        firstAt: data['firstAt'] as int,
        enabled: data['enabled'] as bool,
        alarmMode: data['alarmMode'] == true,
      );

  final int id;
  final String name;
  final int hour;
  final int minute;
  final int intervalHours;
  final int firstAt;
  final bool enabled;
  final bool alarmMode;

  MedicationReminder withEnabled(bool value) => MedicationReminder(
        id: id,
        name: name,
        hour: hour,
        minute: minute,
        intervalHours: intervalHours,
        firstAt: firstAt,
        enabled: value,
        alarmMode: alarmMode,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'hour': hour,
        'minute': minute,
        'intervalHours': intervalHours,
        'firstAt': firstAt,
        'enabled': enabled,
        'alarmMode': alarmMode,
      };
}

class MedicationReminderService {
  static const _deviceOwnerKey = 'medication_device_owner';
  static const _channel = MethodChannel('salud_now/medication_reminders');
  static final reminders = ValueNotifier<List<MedicationReminder>>(const []);
  static final status = ValueNotifier<String?>(null);
  static final fullScreenAllowed = ValueNotifier<bool>(false);
  static bool alarmModeAvailable = false;
  static String? _userId;
  static Future<void> _queue = Future<void>.value();

  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static String _key(String user) => 'medication_reminders_v1_$user';

  static Future<void> _run(Future<void> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  static Future<void> activate(String? account) => _run(() async {
        if (!supported) return;
        alarmModeAvailable = defaultTargetPlatform == TargetPlatform.android ||
            (await _channel.invokeMethod<bool>('alarmModeAvailable') ?? false);
        final user = account == 'guest' ? null : account;
        final prefs = await SharedPreferences.getInstance();
        final deviceOwner = prefs.getString(_deviceOwnerKey);
        if (user == null || (_userId ?? deviceOwner) != user) {
          _userId = null;
          reminders.value = const [];
          status.value = null;
          fullScreenAllowed.value = false;
          await prefs.remove(_deviceOwnerKey);
          await _apply(const []);
        }
        if (user == null) return;

        final raw = prefs.getString(_key(user));
        final items = raw == null
            ? <MedicationReminder>[]
            : (jsonDecode(raw) as List)
                .map((item) => MedicationReminder.fromJson(
                      Map<String, dynamic>.from(item as Map),
                    ))
                .toList();
        await _apply(items);
        await prefs.setString(_deviceOwnerKey, user);
        _userId = user;
        reminders.value = List.unmodifiable(items);
      });

  static Future<void> refresh() => _run(() async {
        if (!supported || _userId == null) return;
        if (defaultTargetPlatform == TargetPlatform.android) {
          status.value = await _channel.invokeMethod<String>('refresh');
          await _readFullScreenPermission(reminders.value);
        } else {
          await _apply(reminders.value);
        }
      });

  static Future<void> save(
    MedicationReminder item, {
    bool remove = false,
  }) {
    final user = _userId;
    return _run(() async {
      if (user == null || _userId != user) {
        throw StateError('Inicia sesión para administrar los recordatorios.');
      }
      if (!remove && item.enabled && !await _requestPermission(item)) {
        throw StateError('Permite las notificaciones para activar el aviso.');
      }
      final current = reminders.value;
      final items = [
        for (final saved in current)
          if (saved.id != item.id) saved,
        if (!remove) item,
      ]..sort((a, b) => a.id.compareTo(b.id));

      final prefs = await SharedPreferences.getInstance();
      try {
        await _apply(items);
        if (status.value == 'capacity') {
          throw StateError('Hay demasiados avisos programados en este iPhone.');
        }
        if (!await prefs.setString(_key(user),
            jsonEncode(items.map((item) => item.toJson()).toList()))) {
          throw StateError('No se pudieron guardar los recordatorios.');
        }
      } catch (_) {
        await _apply(current);
        rethrow;
      }
      reminders.value = List.unmodifiable(items);
    });
  }

  static Future<String> scheduleScreenTest() async {
    if (defaultTargetPlatform != TargetPlatform.android ||
        kIsWeb ||
        _userId == null ||
        !reminders.value.any((item) => item.enabled && item.alarmMode)) {
      return 'unavailable';
    }
    final result = await _channel.invokeMethod<String>('scheduleScreenTest');
    if (result == 'fullScreen') fullScreenAllowed.value = false;
    if (result == 'approximate' || result == 'disabled') status.value = result;
    return result ?? 'unavailable';
  }

  static Future<void> requestFullScreen() =>
      _channel.invokeMethod<void>('requestFullScreen');

  static Future<bool> canDrawOverlays() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return true;
    try {
      return await _channel.invokeMethod<bool>('canDrawOverlays') ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> requestDrawOverlays() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('requestDrawOverlays');
    } catch (_) {}
  }

  static Future<void> _readFullScreenPermission(
      List<MedicationReminder> items) async {
    fullScreenAllowed.value = defaultTargetPlatform == TargetPlatform.android &&
        items.any((item) => item.enabled && item.alarmMode) &&
        (await _channel.invokeMethod<bool>('canShowFullScreen') ?? false);
  }

  static Future<void> requestExactAlarms() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final android = FlutterLocalNotificationsPlugin()
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestExactAlarmsPermission();
    await refresh();
  }

  static Future<bool> _requestPermission(MedicationReminder item) async {
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        alarmModeAvailable &&
        item.alarmMode &&
        (await _channel.invokeMethod<bool>('requestAlarmPermission') ??
            false)) {
      return true;
    }
    final plugin = FlutterLocalNotificationsPlugin();
    if (defaultTargetPlatform == TargetPlatform.android) {
      final platform = plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await platform?.requestNotificationsPermission() ?? false;
    }
    final platform = plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    return await platform?.requestPermissions(alert: true, sound: true) ??
        false;
  }

  static Future<void> _apply(List<MedicationReminder> items) async {
    status.value = await _channel.invokeMethod<String>(
      'replace',
      [
        for (final item in items)
          if (item.enabled) item.toJson()
      ],
    );
    await _readFullScreenPermission(items);
  }
}
