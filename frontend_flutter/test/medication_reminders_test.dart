import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salud_now/core/medication_reminders.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Schedules account reminders and cancels them when paused or signed out',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const scheduleChannel = MethodChannel('salud_now/medication_reminders');
    const notifications =
        MethodChannel('dexterous.com/flutter/local_notifications');
    var scheduled = <Map<dynamic, dynamic>>[];
    var permissionGranted = true;
    var fullScreenGranted = true;
    messenger.setMockMethodCallHandler(scheduleChannel, (call) async {
      if (call.method == 'canShowFullScreen') return fullScreenGranted;
      if (call.method == 'refresh') return 'exact';
      if (call.method == 'scheduleScreenTest') return 'scheduled';
      expect(call.method, 'replace');
      scheduled = (call.arguments as List).cast<Map<dynamic, dynamic>>();
      return 'exact';
    });
    messenger.setMockMethodCallHandler(notifications, (call) async {
      expect(call.method, 'requestNotificationsPermission');
      return permissionGranted;
    });
    addTearDown(() async {
      await MedicationReminderService.activate(null);
      messenger.setMockMethodCallHandler(scheduleChannel, null);
      messenger.setMockMethodCallHandler(notifications, null);
      debugDefaultTargetPlatformOverride = null;
    });

    const reminder = MedicationReminder(
      id: 3,
      name: 'Medicamento de prueba',
      hour: 8,
      minute: 30,
      intervalHours: 5,
      firstAt: 1795701000000,
      alarmMode: true,
    );

    await MedicationReminderService.activate('patient-a');
    await MedicationReminderService.save(reminder);
    expect(scheduled.single['intervalHours'], 5);
    expect(scheduled.single['firstAt'], reminder.firstAt);
    expect(scheduled.single['alarmMode'], isTrue);
    expect(await MedicationReminderService.scheduleScreenTest(), 'scheduled');
    expect(scheduled.single['id'], reminder.id);
    expect(MedicationReminderService.fullScreenAllowed.value, isTrue);
    fullScreenGranted = false;
    await MedicationReminderService.refresh();
    expect(MedicationReminderService.fullScreenAllowed.value, isFalse);
    expect(scheduled.single['alarmMode'], isTrue);

    await MedicationReminderService.save(reminder.withEnabled(false));
    expect(scheduled, isEmpty);
    expect(MedicationReminderService.reminders.value.single.enabled, isFalse);
    expect(await MedicationReminderService.scheduleScreenTest(), 'unavailable');
    permissionGranted = false;
    await expectLater(
        MedicationReminderService.save(reminder), throwsStateError);
    expect(scheduled, isEmpty);

    permissionGranted = true;
    await MedicationReminderService.save(reminder);
    await MedicationReminderService.activate(null);
    expect(scheduled, isEmpty);
    expect(MedicationReminderService.reminders.value, isEmpty);

    await MedicationReminderService.activate('patient-b');
    expect(scheduled, isEmpty);
    await MedicationReminderService.activate('patient-a');
    expect(scheduled.single['name'], reminder.name);

    await MedicationReminderService.save(reminder, remove: true);
    expect(scheduled, isEmpty);
    await MedicationReminderService.activate('patient-a');
    expect(MedicationReminderService.reminders.value, isEmpty);
  });

  test('Uses the iPhone alarm permission when AlarmKit is available', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    SharedPreferences.setMockInitialValues({});
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel = MethodChannel('salud_now/medication_reminders');
    var requested = false;
    var scheduled = <Map<dynamic, dynamic>>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'alarmModeAvailable':
          return true;
        case 'requestAlarmPermission':
          requested = true;
          return true;
        case 'replace':
          scheduled = (call.arguments as List).cast<Map<dynamic, dynamic>>();
          return 'standard';
        default:
          fail('Unexpected method ${call.method}');
      }
    });
    addTearDown(() async {
      await MedicationReminderService.activate(null);
      messenger.setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
    });

    await MedicationReminderService.activate('ios-patient');
    expect(MedicationReminderService.alarmModeAvailable, isTrue);
    await MedicationReminderService.save(const MedicationReminder(
      id: 4,
      name: 'Recordatorio de prueba',
      hour: 8,
      minute: 0,
      intervalHours: 8,
      firstAt: 1795701000000,
      alarmMode: true,
    ));
    expect(requested, isTrue);
    expect(scheduled.single['alarmMode'], isTrue);
  });
}
