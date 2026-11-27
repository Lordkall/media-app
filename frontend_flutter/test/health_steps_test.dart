import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:salud_now/core/health_module_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Keeps daily readings and totals separate across accounts', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() async {
      await HealthModuleHelper.onLogout();
      debugDefaultTargetPlatformOverride = null;
    });

    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final date = yesterday.toIso8601String().substring(0, 10);
    SharedPreferences.setMockInitialValues({
      'user_admin_health_module_enabled': true,
      'user_other_health_module_enabled': true,
      'health_sensor_owner_v2': 'admin',
      'user_admin_health_sensor_reading_v2': '$date:5000',
      'user_admin_health_daily_steps_v2_$date': 3400,
    });

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      (_) async => 1,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('step_count'),
      (_) async => null,
    );

    Future<void> reading(int steps) async {
      await messenger.handlePlatformMessage(
        'step_count',
        const StandardMethodCodec().encodeSuccessEnvelope(steps),
        (_) {},
      );
      await HealthModuleHelper.onAppPaused();
    }

    int today() => HealthModuleHelper.metricsNotifier.value.steps;

    await HealthModuleHelper.loadForUser('admin');
    await HealthModuleHelper.initializePedometer();
    await reading(10000);
    expect(today(), 0);
    await reading(10011);
    await reading(10011);
    expect(today(), 11);

    final monday = DateTime(
        yesterday.year, yesterday.month, yesterday.day - yesterday.weekday + 1);
    final week = await HealthModuleHelper.loadStepWeek(monday);
    expect(week[yesterday.weekday - 1], 3400);

    await HealthModuleHelper.onLogout();
    await HealthModuleHelper.loadForUser('other');
    await HealthModuleHelper.initializePedometer();
    await reading(12000);
    expect(today(), 0);
    await reading(12003);
    expect(today(), 3);

    await HealthModuleHelper.loadForUser('admin');
    await HealthModuleHelper.initializePedometer();
    await reading(12500);
    expect(today(), 11);
    await reading(2);
    await reading(7);
    expect(today(), 16);
  });

  test(
      'Restores Android background totals for yesterday and today without adding the live reading twice',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    String date(DateTime value) => value.toIso8601String().substring(0, 10);
    final claims = base64Url.encode(utf8.encode(jsonEncode({'id': 'walker'})));
    SharedPreferences.setMockInitialValues({
      'access_token': 'header.$claims.signature',
      'user_walker_health_module_enabled': true,
      'user_walker_health_daily_steps_v2_${date(now)}': 100,
    });

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel = MethodChannel('salud_now/background_steps');
    var stopped = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'stop') {
        stopped = true;
        return null;
      }
      expect(call.method, 'refresh');
      expect(call.arguments['account'], 'walker');
      expect(call.arguments['history'], true);
      return {date(yesterday): 1800, date(now): 600};
    });
    final synced = Completer<void>();
    final client = MockClient((request) async {
      if (request.method == 'PUT' &&
          request.url.path.endsWith('/users/me/steps')) {
        final totals = (jsonDecode(request.body) as Map)['totals'] as Map;
        if (totals[date(now)] == 600 &&
            totals[date(yesterday)] == 1800 &&
            !synced.isCompleted) {
          synced.complete();
        }
      }
      return http.Response('{}', 200);
    });

    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
    });
    await http.runWithClient(() async {
      await HealthModuleHelper.loadForUser('walker');
      await HealthModuleHelper.initializePedometer();
      await synced.future.timeout(const Duration(seconds: 5));
      expect(HealthModuleHelper.metricsNotifier.value.steps, 600);
      final monday = DateTime(yesterday.year, yesterday.month,
          yesterday.day - yesterday.weekday + 1);
      final weekly = await HealthModuleHelper.loadStepWeek(monday);
      expect(weekly[yesterday.weekday - 1], 1800);
      await HealthModuleHelper.onLogout();
      expect(stopped, isTrue);
    }, () => client);
  });
}
