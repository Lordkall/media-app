import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'auth_helper.dart';
import 'local_notification_service.dart';

class HealthMetrics {
  final int heartRate; // bpm (default: 72)
  final int steps; // steps (default: 0 daily steps)
  final double sleepHours; // hours (default: 7.3)
  final String sleepQuality; // "Excelente", "Bueno", "Regular", "Bajo"
  final int waterMilliliters; // current ml drunk (starts at 0)
  final int waterGoalMilliliters; // daily goal (default: 2000)
  final bool waterReminderEnabled; // reminder switch
  final int waterReminderIntervalHours; // e.g. 2 hours
  final bool isNativePedometerActive; // steps tracked natively
  final List<int> weeklySteps; // Mon-Sun daily steps (7 days, starts at [0,0,0,0,0,0,0])
  final bool breathingWeeklyReminderEnabled; // weekly breathing & anti-stress reminder
  final double? heightCm; // e.g. 170.0 cm
  final double? weightKg; // e.g. 70.0 kg
  final double? bmi; // Body Mass Index (calculated automatically)
  final String bmiCategory; // "Bajo peso", "Normal", "Sobrepeso", "Obesidad"

  const HealthMetrics({
    this.heartRate = 72,
    this.steps = 0,
    this.sleepHours = 7.3,
    this.sleepQuality = 'Bueno',
    this.waterMilliliters = 0,
    this.waterGoalMilliliters = 2000,
    this.waterReminderEnabled = false,
    this.waterReminderIntervalHours = 2,
    this.isNativePedometerActive = true,
    this.weeklySteps = const [0, 0, 0, 0, 0, 0, 0],
    this.breathingWeeklyReminderEnabled = true,
    this.heightCm,
    this.weightKg,
    this.bmi,
    this.bmiCategory = 'Sin registrar',
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
    double? heightCm,
    double? weightKg,
    double? bmi,
    String? bmiCategory,
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
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      bmi: bmi ?? this.bmi,
      bmiCategory: bmiCategory ?? this.bmiCategory,
    );
  }

  static double? calculateBMI(double? heightCm, double? weightKg) {
    if (heightCm == null || weightKg == null || heightCm <= 0 || weightKg <= 0) {
      return null;
    }
    final meters = heightCm / 100.0;
    return double.parse((weightKg / (meters * meters)).toStringAsFixed(1));
  }

  static String getBMICategory(double? bmi) {
    if (bmi == null || bmi <= 0) return 'Sin registrar';
    if (bmi < 18.5) return 'Bajo peso';
    if (bmi < 25.0) return 'Normal';
    if (bmi < 30.0) return 'Sobrepeso';
    return 'Obesidad';
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
  static const String _heightKey = 'health_body_height_cm';
  static const String _weightKey = 'health_body_weight_kg';
  static const String _lastDayDateKey = 'health_last_day_date';
  static const String _weeklyStepsKey = 'health_weekly_steps';
  static const String _weeklyStepsWeekKey = 'health_weekly_steps_week';

  static String _activeUserId = 'guest';

  static String _userKey(String base) => 'user_${_activeUserId}_$base';

  /// Default disabled (false) as requested by user.
  static final ValueNotifier<bool> isEnabledNotifier =
      ValueNotifier<bool>(false);
  static final ValueNotifier<HealthMetrics> metricsNotifier =
      ValueNotifier<HealthMetrics>(const HealthMetrics());

  static StreamSubscription<StepCount>? _stepCountSubscription;
  static int _initialBootSteps = -1;
  static int _sessionBaseSteps = 0;
  static Timer? _midnightCheckTimer;

  static String _getTodayStr() =>
      DateTime.now().toIso8601String().substring(0, 10);

  static String _getCurrentWeekMondayStr() {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    return monday.toIso8601String().substring(0, 10);
  }

  static void _startMidnightTimer() {
    _midnightCheckTimer?.cancel();
    _midnightCheckTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      checkMidnightReset();
    });
  }

  /// Verifica si ha pasado la medianoche (12:00 am) y reinicia agua y pasos a 0.
  static Future<void> checkMidnightReset() async {
    final todayStr = _getTodayStr();
    final prefs = await SharedPreferences.getInstance();
    final savedDate = prefs.getString(_userKey(_lastDayDateKey));

    if (savedDate != null && savedDate != todayStr) {
      // Cruzó las 12:00 AM: reiniciar pasos y agua a 0
      await prefs.setString(_userKey(_lastDayDateKey), todayStr);
      await prefs.setInt(_userKey(_stepsKey), 0);
      await prefs.setInt(_userKey(_waterMlKey), 0);
      _initialBootSteps = -1;
      _sessionBaseSteps = 0;

      final now = DateTime.now();
      final mondayStr = _getCurrentWeekMondayStr();
      final savedWeek = prefs.getString(_userKey(_weeklyStepsWeekKey));

      List<int> updatedWeekly;
      if (savedWeek != mondayStr) {
        updatedWeekly = [0, 0, 0, 0, 0, 0, 0];
        await prefs.setString(_userKey(_weeklyStepsWeekKey), mondayStr);
      } else {
        final raw = prefs.getString(_userKey(_weeklyStepsKey));
        if (raw != null && raw.isNotEmpty) {
          updatedWeekly =
              raw.split(',').map((e) => int.tryParse(e) ?? 0).toList();
          while (updatedWeekly.length < 7) {
            updatedWeekly.add(0);
          }
        } else {
          updatedWeekly = [0, 0, 0, 0, 0, 0, 0];
        }
      }
      final todayWeekdayIdx = (now.weekday - 1).clamp(0, 6);
      updatedWeekly[todayWeekdayIdx] = 0;
      await prefs.setString(_userKey(_weeklyStepsKey), updatedWeekly.join(','));

      metricsNotifier.value = metricsNotifier.value.copyWith(
        steps: 0,
        waterMilliliters: 0,
        weeklySteps: updatedWeekly,
      );
    }
  }

  /// Inicialización global al arrancar la app.
  static Future<void> initialize() async {
    _startMidnightTimer();
    final userId = await AuthHelper.getUserId();
    await loadForUser(userId);
  }

  /// Carga las métricas aisladas para el usuario activo (paciente, doctor o invitado).
  static Future<void> loadForUser(String? userId) async {
    final newUserId = (userId != null && userId.isNotEmpty) ? userId : 'guest';
    _activeUserId = newUserId;

    try {
      final prefs = await SharedPreferences.getInstance();
      final todayStr = _getTodayStr();
      final savedDate = prefs.getString(_userKey(_lastDayDateKey));

      int st = 0;
      int water = 0;

      if (savedDate == null || savedDate != todayStr) {
        // Nuevo día o primera vez para este usuario: reiniciar pasos y agua a 0
        await prefs.setString(_userKey(_lastDayDateKey), todayStr);
        await prefs.setInt(_userKey(_stepsKey), 0);
        await prefs.setInt(_userKey(_waterMlKey), 0);
        _initialBootSteps = -1;
        _sessionBaseSteps = 0;
        st = 0;
        water = 0;
      } else {
        st = prefs.getInt(_userKey(_stepsKey)) ?? 0;
        water = prefs.getInt(_userKey(_waterMlKey)) ?? 0;
        _sessionBaseSteps = st;
        _initialBootSteps = -1;
      }

      // Manejo de pasos semanales (Lunes a Domingo)
      final now = DateTime.now();
      final mondayStr = _getCurrentWeekMondayStr();
      final savedWeek = prefs.getString(_userKey(_weeklyStepsWeekKey));

      List<int> weekly;
      if (savedWeek != mondayStr) {
        weekly = [0, 0, 0, 0, 0, 0, 0];
        weekly[(now.weekday - 1).clamp(0, 6)] = st;
        await prefs.setString(_userKey(_weeklyStepsWeekKey), mondayStr);
        await prefs.setString(_userKey(_weeklyStepsKey), weekly.join(','));
      } else {
        final raw = prefs.getString(_userKey(_weeklyStepsKey));
        if (raw != null && raw.isNotEmpty) {
          weekly = raw.split(',').map((e) => int.tryParse(e) ?? 0).toList();
          while (weekly.length < 7) {
            weekly.add(0);
          }
        } else {
          weekly = [0, 0, 0, 0, 0, 0, 0];
        }
        weekly[(now.weekday - 1).clamp(0, 6)] = st;
        await prefs.setString(_userKey(_weeklyStepsKey), weekly.join(','));
      }

      final isEnabled = prefs.getBool(_userKey(_enabledKey)) ?? false;
      isEnabledNotifier.value = isEnabled;

      final hr = prefs.getInt(_userKey(_heartRateKey)) ?? 72;
      final sl = prefs.getDouble(_userKey(_sleepHoursKey)) ?? 7.3;
      final quality = HealthMetrics.calculateSleepQuality(sl);
      final goal = prefs.getInt(_userKey(_waterGoalKey)) ?? 2000;
      final reminder = prefs.getBool(_userKey(_waterReminderKey)) ?? false;
      final interval = prefs.getInt(_userKey(_waterIntervalKey)) ?? 2;
      final breathingWeekly =
          prefs.getBool(_userKey(_breathingWeeklyReminderKey)) ?? true;

      final height = prefs.getDouble(_userKey(_heightKey));
      final weight = prefs.getDouble(_userKey(_weightKey));
      final bmi = HealthMetrics.calculateBMI(height, weight);
      final bmiCategory = HealthMetrics.getBMICategory(bmi);

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
        weeklySteps: weekly,
        breathingWeeklyReminderEnabled: breathingWeekly,
        heightCm: height,
        weightKg: weight,
        bmi: bmi,
        bmiCategory: bmiCategory,
      );

      if (reminder && !kIsWeb) {
        await LocalNotificationService.scheduleWaterReminder(
            intervalHours: interval);
      }
      if (breathingWeekly && isEnabled && !kIsWeb) {
        await LocalNotificationService.scheduleWeeklyBreathingReminder();
      }

      if (isEnabled) {
        unawaited(initializePedometer());
      }
    } catch (e) {
      debugPrint('Error al cargar métricas de salud para usuario $_activeUserId: $e');
    }
  }

  /// Limpia suscripciones y reinicia estado al cerrar sesión.
  static Future<void> onLogout() async {
    try {
      await _stepCountSubscription?.cancel();
      _stepCountSubscription = null;
      _initialBootSteps = -1;
      _sessionBaseSteps = 0;
      _activeUserId = 'guest';
      isEnabledNotifier.value = false;
      metricsNotifier.value = const HealthMetrics(
        waterMilliliters: 0,
        weeklySteps: [0, 0, 0, 0, 0, 0, 0],
      );
    } catch (_) {}
  }

  /// Inicializa el sensor de podómetro nativo en Android / iOS y solicita permisos de actividad física.
  static Future<void> initializePedometer() async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }

    try {
      var status = await Permission.activityRecognition.status;
      if (!status.isGranted) {
        status = await Permission.activityRecognition.request();
      }

      if (status.isGranted) {
        await checkMidnightReset();

        await _stepCountSubscription?.cancel();
        _stepCountSubscription = Pedometer.stepCountStream.listen(
          (StepCount event) async {
            final nowDayStr = _getTodayStr();
            final currentBootSteps = event.steps;

            final prefs = await SharedPreferences.getInstance();
            final curSavedDate = prefs.getString(_userKey(_lastDayDateKey));
            if (curSavedDate != nowDayStr) {
              await checkMidnightReset();
            }

            if (_initialBootSteps < 0 || currentBootSteps < _initialBootSteps) {
              _initialBootSteps = currentBootSteps;
              _sessionBaseSteps = prefs.getInt(_userKey(_stepsKey)) ?? 0;
            }

            final hardwareDiff =
                (currentBootSteps - _initialBootSteps).clamp(0, 100000);
            final todaySteps =
                (_sessionBaseSteps + hardwareDiff).clamp(0, 100000);

            await updateMetrics(
              heartRate: metricsNotifier.value.heartRate,
              sleepHours: metricsNotifier.value.sleepHours,
              steps: todaySteps,
            );
          },
          onError: (error) {
            debugPrint(
                'Aviso: Sensor de podómetro no disponible en este dispositivo: $error');
          },
          cancelOnError: false,
        );
      }
    } catch (e) {
      debugPrint('Aviso inicializando sensor de podómetro: $e');
    }
  }

  static Future<void> setEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_userKey(_enabledKey), enabled);
      if (!kIsWeb) {
        if (enabled && metricsNotifier.value.breathingWeeklyReminderEnabled) {
          await LocalNotificationService.scheduleWeeklyBreathingReminder();
        } else if (!enabled) {
          await LocalNotificationService.cancelWeeklyBreathingReminder();
          await LocalNotificationService.cancelWaterReminder();
        }
        if (enabled) {
          unawaited(initializePedometer());
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
      await prefs.setInt(_userKey(_heartRateKey), heartRate);
      if (steps != null) await prefs.setInt(_userKey(_stepsKey), steps);
      await prefs.setDouble(_userKey(_sleepHoursKey), sleepHours);

      final now = DateTime.now();
      final weekdayIdx = (now.weekday - 1).clamp(0, 6);
      final updatedWeekly = List<int>.from(metricsNotifier.value.weeklySteps);
      while (updatedWeekly.length < 7) {
        updatedWeekly.add(0);
      }
      updatedWeekly[weekdayIdx] = currentSteps;
      await prefs.setString(_userKey(_weeklyStepsKey), updatedWeekly.join(','));

      metricsNotifier.value = metricsNotifier.value.copyWith(
        heartRate: heartRate,
        steps: currentSteps,
        sleepHours: sleepHours,
        sleepQuality: quality,
        weeklySteps: updatedWeekly,
      );
    } catch (_) {}
  }

  static Future<void> updateBodyMetrics({
    required double heightCm,
    required double weightKg,
  }) async {
    final bmi = HealthMetrics.calculateBMI(heightCm, weightKg);
    final bmiCat = HealthMetrics.getBMICategory(bmi);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_userKey(_heightKey), heightCm);
      await prefs.setDouble(_userKey(_weightKey), weightKg);
      // Sync with user profile on backend
      await ApiClient.put('/users/me', {
        'height_cm': heightCm,
        'weight_kg': weightKg,
      });
    } catch (_) {}

    metricsNotifier.value = metricsNotifier.value.copyWith(
      heightCm: heightCm,
      weightKg: weightKg,
      bmi: bmi,
      bmiCategory: bmiCat,
    );
  }

  static Future<void> addWater([int ml = 250]) async {
    final current = metricsNotifier.value.waterMilliliters;
    final updated = (current + ml).clamp(0, 8000);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_userKey(_waterMlKey), updated);
    } catch (_) {}
    metricsNotifier.value =
        metricsNotifier.value.copyWith(waterMilliliters: updated);
  }

  static Future<void> removeWater([int ml = 250]) async {
    final current = metricsNotifier.value.waterMilliliters;
    final updated = (current - ml).clamp(0, 8000);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_userKey(_waterMlKey), updated);
    } catch (_) {}
    metricsNotifier.value =
        metricsNotifier.value.copyWith(waterMilliliters: updated);
  }

  static Future<void> setWaterGoal(int goal) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_userKey(_waterGoalKey), goal);
    } catch (_) {}
    metricsNotifier.value =
        metricsNotifier.value.copyWith(waterGoalMilliliters: goal);
  }

  static Future<void> setWaterReminder(bool enabled,
      [int? intervalHours]) async {
    final interval =
        intervalHours ?? metricsNotifier.value.waterReminderIntervalHours;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_userKey(_waterReminderKey), enabled);
      await prefs.setInt(_userKey(_waterIntervalKey), interval);
      if (!kIsWeb) {
        if (enabled) {
          await LocalNotificationService.scheduleWaterReminder(
              intervalHours: interval);
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
      await prefs.setBool(_userKey(_breathingWeeklyReminderKey), enabled);
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
