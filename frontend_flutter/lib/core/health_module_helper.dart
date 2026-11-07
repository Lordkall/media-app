import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'local_notification_service.dart';

class HealthMetrics {
  final int heartRate; // bpm (default: 72)
  final int steps; // steps (default: 0 daily steps)
  final double sleepHours; // hours (default: 7.3)
  final String sleepQuality; // "Excelente", "Bueno", "Regular", "Bajo"
  final int waterMilliliters; // current ml drunk (e.g. 1250)
  final int waterGoalMilliliters; // daily goal (default: 2000)
  final bool waterReminderEnabled; // reminder switch
  final int waterReminderIntervalHours; // e.g. 2 hours
  final bool isNativePedometerActive; // steps tracked natively
  final List<int> weeklySteps; // Mon-Sun daily steps (7 days)
  final bool breathingWeeklyReminderEnabled; // weekly breathing & anti-stress reminder

  const HealthMetrics({
    this.heartRate = 72,
    this.steps = 0,
    this.sleepHours = 7.3,
    this.sleepQuality = 'Bueno',
    this.waterMilliliters = 1250,
    this.waterGoalMilliliters = 2000,
    this.waterReminderEnabled = false,
    this.waterReminderIntervalHours = 2,
    this.isNativePedometerActive = true,
    this.weeklySteps = const [4200, 6800, 5100, 9000, 3400, 1800, 0],
    this.breathingWeeklyReminderEnabled = true,
  });

  HealthMetrics copyWith({
    int? heartRate,
    int? steps,
    double? sleepHours,
    String? sleepQuality,
    int? waterMilliliters,
    int? waterGoalMilliliters,
    bool? waterReminderEnabled,
    int? waterReminderIntervalHours,
    bool? isNativePedometerActive,
    List<int>? weeklySteps,
    bool? breathingWeeklyReminderEnabled,
  }) {
    return HealthMetrics(
      heartRate: heartRate ?? this.heartRate,
      steps: steps ?? this.steps,
      sleepHours: sleepHours ?? this.sleepHours,
      sleepQuality: sleepQuality ?? this.sleepQuality,
      waterMilliliters: waterMilliliters ?? this.waterMilliliters,
      waterGoalMilliliters: waterGoalMilliliters ?? this.waterGoalMilliliters,
      waterReminderEnabled: waterReminderEnabled ?? this.waterReminderEnabled,
      waterReminderIntervalHours:
          waterReminderIntervalHours ?? this.waterReminderIntervalHours,
      isNativePedometerActive:
          isNativePedometerActive ?? this.isNativePedometerActive,
      weeklySteps: weeklySteps ?? this.weeklySteps,
      breathingWeeklyReminderEnabled:
          breathingWeeklyReminderEnabled ?? this.breathingWeeklyReminderEnabled,
    );
  }

  static String calculateSleepQuality(double hours) {
    if (hours >= 8.0) return 'Excelente';
    if (hours >= 7.0) return 'Bueno';
    if (hours >= 5.5) return 'Regular';
    return 'Bajo';
  }
}

class HealthModuleHelper {
  static const String _enabledKey = 'health_module_enabled';
  static const String _heartRateKey = 'health_metric_heart_rate';
  static const String _stepsKey = 'health_metric_steps';
  static const String _sleepHoursKey = 'health_metric_sleep_hours';
  static const String _waterMlKey = 'health_metric_water_ml';
  static const String _waterGoalKey = 'health_metric_water_goal';
  static const String _waterReminderKey = 'health_water_reminder_enabled';
  static const String _waterIntervalKey = 'health_water_interval_hours';
  static const String _breathingWeeklyReminderKey =
      'health_breathing_weekly_reminder_enabled';

  /// Default disabled (false) as requested by user.
  static final ValueNotifier<bool> isEnabledNotifier = ValueNotifier<bool>(false);
  static final ValueNotifier<HealthMetrics> metricsNotifier =
      ValueNotifier<HealthMetrics>(const HealthMetrics());

  static Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isEnabled = prefs.getBool(_enabledKey) ?? false;
      isEnabledNotifier.value = isEnabled;

      final hr = prefs.getInt(_heartRateKey) ?? 72;
      final st = prefs.getInt(_stepsKey) ?? 0;
      final sl = prefs.getDouble(_sleepHoursKey) ?? 7.3;
      final quality = HealthMetrics.calculateSleepQuality(sl);
      final water = prefs.getInt(_waterMlKey) ?? 1250;
      final goal = prefs.getInt(_waterGoalKey) ?? 2000;
      final reminder = prefs.getBool(_waterReminderKey) ?? false;
      final interval = prefs.getInt(_waterIntervalKey) ?? 2;
      final breathingWeekly =
          prefs.getBool(_breathingWeeklyReminderKey) ?? true;

      metricsNotifier.value = HealthMetrics(
        heartRate: hr,
        steps: st,
        sleepHours: sl,
        sleepQuality: quality,
        waterMilliliters: water,
        waterGoalMilliliters: goal,
        waterReminderEnabled: reminder,
        waterReminderIntervalHours: interval,
        isNativePedometerActive: true,
        weeklySteps: [4200, 6800, 5100, 9000, 3400, 1800, st],
        breathingWeeklyReminderEnabled: breathingWeekly,
      );

      if (reminder && !kIsWeb) {
        await LocalNotificationService.scheduleWaterReminder(
            intervalHours: interval);
      }
      if (breathingWeekly && isEnabled && !kIsWeb) {
        await LocalNotificationService.scheduleWeeklyBreathingReminder();
      }
    } catch (_) {}
  }

  static Future<void> setEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, enabled);
      if (!kIsWeb) {
        if (enabled && metricsNotifier.value.breathingWeeklyReminderEnabled) {
          await LocalNotificationService.scheduleWeeklyBreathingReminder();
        } else if (!enabled) {
          await LocalNotificationService.cancelWeeklyBreathingReminder();
          await LocalNotificationService.cancelWaterReminder();
        }
      }
    } catch (_) {}
    isEnabledNotifier.value = enabled;
  }

  static Future<void> updateMetrics({
    required int heartRate,
    required double sleepHours,
    int? steps,
  }) async {
    final currentSteps = steps ?? metricsNotifier.value.steps;
    final quality = HealthMetrics.calculateSleepQuality(sleepHours);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_heartRateKey, heartRate);
      if (steps != null) await prefs.setInt(_stepsKey, steps);
      await prefs.setDouble(_sleepHoursKey, sleepHours);
    } catch (_) {}

    final updatedWeekly = List<int>.from(metricsNotifier.value.weeklySteps);
    if (updatedWeekly.isNotEmpty) {
      updatedWeekly[updatedWeekly.length - 1] = currentSteps;
    }

    metricsNotifier.value = metricsNotifier.value.copyWith(
      heartRate: heartRate,
      steps: currentSteps,
      sleepHours: sleepHours,
      sleepQuality: quality,
      weeklySteps: updatedWeekly,
    );
  }

  static Future<void> addWater([int ml = 250]) async {
    final current = metricsNotifier.value.waterMilliliters;
    final updated = (current + ml).clamp(0, 8000);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_waterMlKey, updated);
    } catch (_) {}
    metricsNotifier.value = metricsNotifier.value.copyWith(waterMilliliters: updated);
  }

  static Future<void> removeWater([int ml = 250]) async {
    final current = metricsNotifier.value.waterMilliliters;
    final updated = (current - ml).clamp(0, 8000);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_waterMlKey, updated);
    } catch (_) {}
    metricsNotifier.value = metricsNotifier.value.copyWith(waterMilliliters: updated);
  }

  static Future<void> setWaterGoal(int goal) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_waterGoalKey, goal);
    } catch (_) {}
    metricsNotifier.value = metricsNotifier.value.copyWith(waterGoalMilliliters: goal);
  }

  static Future<void> setWaterReminder(bool enabled, [int? intervalHours]) async {
    final interval = intervalHours ?? metricsNotifier.value.waterReminderIntervalHours;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_waterReminderKey, enabled);
      await prefs.setInt(_waterIntervalKey, interval);
      if (!kIsWeb) {
        if (enabled) {
          await LocalNotificationService.scheduleWaterReminder(intervalHours: interval);
        } else {
          await LocalNotificationService.cancelWaterReminder();
        }
      }
    } catch (_) {}
    metricsNotifier.value = metricsNotifier.value.copyWith(
      waterReminderEnabled: enabled,
      waterReminderIntervalHours: interval,
    );
  }

  static Future<void> setBreathingWeeklyReminder(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_breathingWeeklyReminderKey, enabled);
      if (!kIsWeb) {
        if (enabled && isEnabledNotifier.value) {
          await LocalNotificationService.scheduleWeeklyBreathingReminder();
        } else {
          await LocalNotificationService.cancelWeeklyBreathingReminder();
        }
      }
    } catch (_) {}
    metricsNotifier.value = metricsNotifier.value.copyWith(
      breathingWeeklyReminderEnabled: enabled,
    );
  }
}
