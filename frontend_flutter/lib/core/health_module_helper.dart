import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
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
  final int stepGoal; // daily goal (default: 10000)
  final List<int> weeklySteps; // Mon-Sun daily steps (7 days, starts at [0,0,0,0,0,0,0])
  final bool breathingWeeklyReminderEnabled; // weekly breathing & anti-stress reminder
  final double? heightCm; // e.g. 170.0 cm
  final double? weightKg; // e.g. 70.0 kg
  final double? bmi; // Body Mass Index (calculated automatically)
  final String bmiCategory; // "Bajo peso", "Normal", "Sobrepeso", "Obesidad"

  const HealthMetrics({
    this.heartRate = 72,
    this.steps = 0,
    this.stepGoal = 10000,
    this.sleepHours = 7.3,
    this.sleepQuality = 'Bueno',
    this.waterMilliliters = 0,
    this.waterGoalMilliliters = 2000,
    this.waterReminderEnabled = true,
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
    int? stepGoal,
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
      stepGoal: stepGoal ?? this.stepGoal,
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

class HealthLifecycleObserver with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      HealthModuleHelper.onAppResumed();
    } else if (state == AppLifecycleState.paused) {
      HealthModuleHelper.onAppPaused();
    }
  }
}

class HealthModuleHelper {
  static const String _enabledKey = 'health_module_enabled';
  static const String _heartRateKey = 'health_metric_heart_rate';
  static const String _stepsKey = 'health_metric_steps';
  static const String _stepGoalKey = 'health_metric_step_goal';
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
  static const String _hardwareBaselineStepsKey =
      'health_hardware_step_baseline';
  static const String _lastHardwareBootStepsKey =
      'health_last_hardware_boot_steps';

  static String _activeUserId = 'guest';
  static bool _observerAttached = false;

  static String _userKey(String base) => 'user_${_activeUserId}_$base';

  /// Por defecto desactivado (false) según lo indicado por el usuario.
  static final ValueNotifier<bool> isEnabledNotifier =
      ValueNotifier<bool>(false);
  static final ValueNotifier<HealthMetrics> metricsNotifier =
      ValueNotifier<HealthMetrics>(const HealthMetrics());

  static StreamSubscription<StepCount>? _stepCountSubscription;
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
      _checkDailyStepReminders();
    });
  }

  /// Se ejecuta automáticamente cuando la app vuelve al primer plano (foreground),
  /// por ejemplo tras haber estado minimizada o con la pantalla bloqueada por horas.
  static Future<void> onAppResumed() async {
    try {
      await checkMidnightReset();
      if (isEnabledNotifier.value) {
        await initializePedometer(forceRestart: true);
      }
    } catch (e) {
      debugPrint('Aviso en onAppResumed de HealthModuleHelper: $e');
    }
  }

  /// Se ejecuta automáticamente cuando la app pasa a segundo plano o se bloquea la pantalla.
  static Future<void> onAppPaused() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_userKey(_stepsKey), metricsNotifier.value.steps);
      await prefs.setString(_userKey(_lastDayDateKey), _getTodayStr());
    } catch (_) {}
  }

  /// Verifica las 3 notificaciones diarias de progreso de pasos (Mañana, Tarde y Noche).
  /// Exclusivamente en la franja permitida de 6:00 AM a 10:00 PM (06:00 a 22:00) y si el módulo está activo.
  static Future<void> _checkDailyStepReminders() async {
    if (kIsWeb || !isEnabledNotifier.value) return;

    final now = DateTime.now();
    // Restricción estricta de horario: entre 6:00 AM y 10:00 PM
    if (now.hour < 6 || now.hour >= 22) return;

    final todayStr = _getTodayStr();
    final steps = metricsNotifier.value.steps;
    final goal = metricsNotifier.value.stepGoal > 0
        ? metricsNotifier.value.stepGoal
        : 10000;

    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Mañana (10:00 AM - 1:59 PM)
      if (now.hour >= 10 && now.hour < 14) {
        final lastMorning =
            prefs.getString(_userKey('health_step_reminder_morning_date'));
        if (lastMorning != todayStr) {
          await prefs.setString(
              _userKey('health_step_reminder_morning_date'), todayStr);
          await LocalNotificationService.showStepProgressReminder(
            notificationId: 981,
            title: '🚶‍♂️ Tus pasos de hoy',
            steps: steps,
            goal: goal,
            message:
                '¡Comienza tu día en movimiento! Llevas $steps de $goal pasos dados.',
          );
        }
      }

      // 2. Tarde (3:00 PM - 6:59 PM)
      if (now.hour >= 15 && now.hour < 19) {
        final lastAfternoon =
            prefs.getString(_userKey('health_step_reminder_afternoon_date'));
        if (lastAfternoon != todayStr) {
          await prefs.setString(
              _userKey('health_step_reminder_afternoon_date'), todayStr);
          await LocalNotificationService.showStepProgressReminder(
            notificationId: 982,
            title: '🏃‍♂️ Progreso de pasos',
            steps: steps,
            goal: goal,
            message:
                '¡Mitad del día! Llevas $steps de $goal pasos dados. ¡Sigue activo para alcanzar tu meta!',
          );
        }
      }

      // 3. Noche (8:00 PM - 9:59 PM, antes de las 10:00 PM)
      if (now.hour >= 20 && now.hour < 22) {
        final lastEvening =
            prefs.getString(_userKey('health_step_reminder_evening_date'));
        if (lastEvening != todayStr) {
          await prefs.setString(
              _userKey('health_step_reminder_evening_date'), todayStr);
          await LocalNotificationService.showStepProgressReminder(
            notificationId: 983,
            title: '👟 Cierre del día',
            steps: steps,
            goal: goal,
            message:
                'Llevas $steps de $goal pasos caminados hoy. ¡Revisa tu resumen diario en el Módulo de Salud!',
          );
        }
      }
    } catch (_) {}
  }

  /// Notificación push inmediata al alcanzar o superar la meta diaria de pasos.
  /// Solo se dispara si el módulo está activo y en horario de 6:00 AM a 10:00 PM.
  static Future<void> _checkStepGoalCelebration(int steps, int goal) async {
    if (kIsWeb || !isEnabledNotifier.value || goal <= 0) return;
    if (steps < goal) return;

    final now = DateTime.now();
    if (now.hour < 6 || now.hour >= 22) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final todayStr = _getTodayStr();
      final lastCelebrated =
          prefs.getString(_userKey('health_step_goal_celebrated_date'));
      if (lastCelebrated != todayStr) {
        await prefs.setString(
            _userKey('health_step_goal_celebrated_date'), todayStr);
        await LocalNotificationService.showStepGoalCompleted(
          steps: steps,
          goal: goal,
        );
      }
    } catch (_) {}
  }

  /// Verifica si ha pasado la medianoche (12:00 am) y reinicia agua y pasos a 0.
  static Future<void> checkMidnightReset() async {
    final todayStr = _getTodayStr();
    final prefs = await SharedPreferences.getInstance();
    final savedDate = prefs.getString(_userKey(_lastDayDateKey));

    if (savedDate != null && savedDate != todayStr) {
      // Cruzó las 12:00 AM o nuevo día

      // 1. Obtener la última lectura física de hardware registrada ayer
      final lastRecordedBootSteps =
          prefs.getInt(_userKey(_lastHardwareBootStepsKey));
      final previousBaseline =
          prefs.getInt(_userKey(_hardwareBaselineStepsKey));
      final previousSteps = prefs.getInt(_userKey(_stepsKey)) ?? 0;

      await prefs.setString(_userKey(_lastDayDateKey), todayStr);
      await prefs.setInt(_userKey(_waterMlKey), 0);
      await prefs.remove(_userKey('health_step_reminder_morning_date'));
      await prefs.remove(_userKey('health_step_reminder_afternoon_date'));
      await prefs.remove(_userKey('health_step_reminder_evening_date'));
      await prefs.remove(_userKey('health_step_goal_celebrated_date'));

      // 2. Establecer la línea base para hoy:
      // Conservamos el último conteo de hardware de ayer como punto de partida de hoy.
      // De esta manera, los pasos dados de madrugada o mañana con la app cerrada se cuentan para hoy.
      int? newTodayBaseline;
      if (lastRecordedBootSteps != null && lastRecordedBootSteps > 0) {
        newTodayBaseline = lastRecordedBootSteps;
      } else if (previousBaseline != null && previousBaseline > 0) {
        newTodayBaseline = previousBaseline + previousSteps;
      }

      if (newTodayBaseline != null) {
        await prefs.setInt(
            _userKey(_hardwareBaselineStepsKey), newTodayBaseline);
      } else {
        await prefs.remove(_userKey(_hardwareBaselineStepsKey));
      }

      // Reiniciar pasos guardados de hoy a 0 provisionalmente
      await prefs.setInt(_userKey(_stepsKey), 0);

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
      if (!kIsWeb &&
          metricsNotifier.value.waterReminderEnabled &&
          isEnabledNotifier.value) {
        await LocalNotificationService.scheduleWaterReminder(
          intervalHours: metricsNotifier.value.waterReminderIntervalHours,
          fromTime: DateTime.now(),
        );
      }
    }
  }

  /// Inicialización global al arrancar la app.
  static Future<void> initialize() async {
    if (!_observerAttached) {
      _observerAttached = true;
      WidgetsBinding.instance.addObserver(HealthLifecycleObserver());
    }
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

      if (savedDate == null) {
        // Primera vez para este usuario
        await prefs.setString(_userKey(_lastDayDateKey), todayStr);
        await prefs.setInt(_userKey(_stepsKey), 0);
        await prefs.setInt(_userKey(_waterMlKey), 0);
        await prefs.remove(_userKey(_hardwareBaselineStepsKey));
        await prefs.remove(_userKey(_lastHardwareBootStepsKey));
        st = 0;
        water = 0;
      } else if (savedDate != todayStr) {
        // Nuevo día: conservar el último registro de hardware de ayer como línea base de hoy
        final lastRecordedBootSteps =
            prefs.getInt(_userKey(_lastHardwareBootStepsKey));
        final previousBaseline =
            prefs.getInt(_userKey(_hardwareBaselineStepsKey));
        final previousSteps = prefs.getInt(_userKey(_stepsKey)) ?? 0;

        await prefs.setString(_userKey(_lastDayDateKey), todayStr);
        await prefs.setInt(_userKey(_stepsKey), 0);
        await prefs.setInt(_userKey(_waterMlKey), 0);
        await prefs.remove(_userKey('health_step_reminder_morning_date'));
        await prefs.remove(_userKey('health_step_reminder_afternoon_date'));
        await prefs.remove(_userKey('health_step_reminder_evening_date'));
        await prefs.remove(_userKey('health_step_goal_celebrated_date'));

        int? newTodayBaseline;
        if (lastRecordedBootSteps != null && lastRecordedBootSteps > 0) {
          newTodayBaseline = lastRecordedBootSteps;
        } else if (previousBaseline != null && previousBaseline > 0) {
          newTodayBaseline = previousBaseline + previousSteps;
        }

        if (newTodayBaseline != null) {
          await prefs.setInt(
              _userKey(_hardwareBaselineStepsKey), newTodayBaseline);
        } else {
          await prefs.remove(_userKey(_hardwareBaselineStepsKey));
        }

        st = 0;
        water = 0;
      } else {
        st = prefs.getInt(_userKey(_stepsKey)) ?? 0;
        water = prefs.getInt(_userKey(_waterMlKey)) ?? 0;
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
      final stepGoal = prefs.getInt(_userKey(_stepGoalKey)) ?? 10000;
      final sl = prefs.getDouble(_userKey(_sleepHoursKey)) ?? 7.3;
      final quality = HealthMetrics.calculateSleepQuality(sl);
      final goal = prefs.getInt(_userKey(_waterGoalKey)) ?? 2000;
      final reminder = prefs.getBool(_userKey(_waterReminderKey)) ?? true;
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
        stepGoal: stepGoal,
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

      if (isEnabled && !kIsWeb) {
        if (reminder && water < goal) {
          await LocalNotificationService.scheduleWaterReminder(
            intervalHours: interval,
            fromTime: DateTime.now(),
          );
        }
        if (breathingWeekly) {
          await LocalNotificationService.scheduleWeeklyBreathingReminder();
        }
        await LocalNotificationService.scheduleDailyStepReminders();
        unawaited(initializePedometer(forceRestart: true));
        unawaited(_checkDailyStepReminders());
        unawaited(_checkStepGoalCelebration(st, stepGoal));
      } else if (!isEnabled && !kIsWeb) {
        await LocalNotificationService.cancelWaterReminder();
        await LocalNotificationService.cancelWeeklyBreathingReminder();
        await LocalNotificationService.cancelStepReminders();
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
      _activeUserId = 'guest';
      isEnabledNotifier.value = false;
      metricsNotifier.value = const HealthMetrics(
        waterMilliliters: 0,
        weeklySteps: [0, 0, 0, 0, 0, 0, 0],
      );
      if (!kIsWeb) {
        await LocalNotificationService.cancelWaterReminder();
        await LocalNotificationService.cancelWeeklyBreathingReminder();
        await LocalNotificationService.cancelStepReminders();
      }
    } catch (_) {}
  }

  /// Inicializa el sensor de podómetro nativo en Android / iOS y solicita permisos de actividad física.
  /// Mantiene la línea base física guardada para contar pasos con precisión en tiempo real
  /// y acumular exactamente los pasos dados mientras la aplicación estuvo cerrada.
  static Future<void> initializePedometer({bool forceRestart = false}) async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    if (!isEnabledNotifier.value) return;

    try {
      var status = await Permission.activityRecognition.status;
      if (!status.isGranted) {
        status = await Permission.activityRecognition.request();
      }

      if (status.isGranted) {
        await checkMidnightReset();

        if (_stepCountSubscription != null && !forceRestart) {
          return;
        }

        await _stepCountSubscription?.cancel();
        _stepCountSubscription = Pedometer.stepCountStream.listen(
          (StepCount event) async {
            final nowDayStr = _getTodayStr();
            final currentBootSteps = event.steps;

            final prefs = await SharedPreferences.getInstance();
            final curSavedDate = prefs.getString(_userKey(_lastDayDateKey));
            if (curSavedDate != null && curSavedDate != nowDayStr) {
              await checkMidnightReset();
            }

            final baselineKey = _userKey(_hardwareBaselineStepsKey);
            int? savedBaseline = prefs.getInt(baselineKey);

            if (savedBaseline == null) {
              // Primera lectura del sensor en el día:
              // Establecemos la línea base de hardware descontando los pasos ya guardados hoy
              final existingSteps = prefs.getInt(_userKey(_stepsKey)) ?? 0;
              savedBaseline = currentBootSteps - existingSteps;
              await prefs.setInt(baselineKey, savedBaseline);
            } else if (currentBootSteps < savedBaseline) {
              // El teléfono se reinició (el contador de hardware empezó de 0)
              final lastSteps = prefs.getInt(_userKey(_stepsKey)) ?? 0;
              if (lastSteps > 0) {
                savedBaseline = currentBootSteps - lastSteps;
              } else {
                savedBaseline = 0;
              }
              await prefs.setInt(baselineKey, savedBaseline);
            }

            final todaySteps =
                (currentBootSteps - savedBaseline).clamp(0, 100000);

            // Guardamos el último conteo de hardware de forma persistente para transiciones entre días
            await prefs.setInt(
                _userKey(_lastHardwareBootStepsKey), currentBootSteps);

            // Actualizar métricas en memoria de inmediato para tiempo real sin retrasos
            await updateMetrics(
              heartRate: metricsNotifier.value.heartRate,
              sleepHours: metricsNotifier.value.sleepHours,
              steps: todaySteps,
            );
            await _checkStepGoalCelebration(
              todaySteps,
              metricsNotifier.value.stepGoal,
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

  /// Activa o desactiva el módulo de salud globalmente.
  /// Si se desactiva, se cancelan de inmediato todas las notificaciones de agua, pasos y respiración.
  static Future<void> setEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_userKey(_enabledKey), enabled);

      if (!kIsWeb) {
        if (!enabled) {
          // Desactivar: cancelar todas las notificaciones del módulo de salud
          await LocalNotificationService.cancelWeeklyBreathingReminder();
          await LocalNotificationService.cancelWaterReminder();
          await LocalNotificationService.cancelStepReminders();
          await _stepCountSubscription?.cancel();
          _stepCountSubscription = null;
          unawaited(
              ApiClient.put('/users/me', {'water_reminder_enabled': false}));
        } else {
          // Activar: iniciar podómetro y reprogramar recordatorios según preferencias
          await LocalNotificationService.scheduleDailyStepReminders();
          unawaited(initializePedometer(forceRestart: true));
          if (metricsNotifier.value.breathingWeeklyReminderEnabled) {
            await LocalNotificationService.scheduleWeeklyBreathingReminder();
          }
          if (metricsNotifier.value.waterReminderEnabled &&
              metricsNotifier.value.waterMilliliters <
                  metricsNotifier.value.waterGoalMilliliters) {
            await LocalNotificationService.scheduleWaterReminder(
              intervalHours: metricsNotifier.value.waterReminderIntervalHours,
              fromTime: DateTime.now(),
            );
            unawaited(
                ApiClient.put('/users/me', {'water_reminder_enabled': true}));
          }
          unawaited(_checkDailyStepReminders());
        }
      }
    } catch (_) {}
    isEnabledNotifier.value = enabled;
  }

  static Future<void> updateMetrics({
    int? heartRate,
    double? sleepHours,
    int? steps,
  }) async {
    final hr = heartRate ?? metricsNotifier.value.heartRate;
    final sl = sleepHours ?? metricsNotifier.value.sleepHours;
    final currentSteps = steps ?? metricsNotifier.value.steps;
    final quality = HealthMetrics.calculateSleepQuality(sl);

    final now = DateTime.now();
    final weekdayIdx = (now.weekday - 1).clamp(0, 6);
    final updatedWeekly = List<int>.from(metricsNotifier.value.weeklySteps);
    while (updatedWeekly.length < 7) {
      updatedWeekly.add(0);
    }
    updatedWeekly[weekdayIdx] = currentSteps;

    // Notificar inmediatamente a los oyentes de la UI para actualización instantánea en tiempo real
    metricsNotifier.value = metricsNotifier.value.copyWith(
      heartRate: hr,
      steps: currentSteps,
      sleepHours: sl,
      sleepQuality: quality,
      weeklySteps: updatedWeekly,
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_userKey(_heartRateKey), hr);
      if (steps != null) await prefs.setInt(_userKey(_stepsKey), steps);
      await prefs.setDouble(_userKey(_sleepHoursKey), sl);
      await prefs.setString(_userKey(_weeklyStepsKey), updatedWeekly.join(','));
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

  /// Añade agua (un vaso = 250 ml por defecto).
  /// Al sumar un vaso de agua, comienza a contar el intervalo elegido para el siguiente recordatorio.
  static Future<void> addWater([int ml = 250]) async {
    final current = metricsNotifier.value.waterMilliliters;
    final goal = metricsNotifier.value.waterGoalMilliliters;
    final updated = (current + ml).clamp(0, goal);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_userKey(_waterMlKey), updated);
    } catch (_) {}
    metricsNotifier.value =
        metricsNotifier.value.copyWith(waterMilliliters: updated);

    if (updated >= goal) {
      // Meta de hidratación completada: cancelar recordatorios por el resto del día
      if (!kIsWeb) {
        await LocalNotificationService.cancelWaterReminder();
      }
      unawaited(ApiClient.put('/users/me', {'water_reminder_enabled': false}));
    } else {
      // Conteo del intervalo a partir del momento en que bebió agua
      if (!kIsWeb &&
          metricsNotifier.value.waterReminderEnabled &&
          isEnabledNotifier.value) {
        await LocalNotificationService.scheduleWaterReminder(
          intervalHours: metricsNotifier.value.waterReminderIntervalHours,
          fromTime: DateTime.now(),
        );
      }
    }
  }

  static Future<void> removeWater([int ml = 250]) async {
    final current = metricsNotifier.value.waterMilliliters;
    final goal = metricsNotifier.value.waterGoalMilliliters;
    final updated = (current - ml).clamp(0, goal);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_userKey(_waterMlKey), updated);
    } catch (_) {}
    metricsNotifier.value =
        metricsNotifier.value.copyWith(waterMilliliters: updated);

    // Si baja de la meta y el recordatorio está activo, reprogramar con el intervalo
    if (!kIsWeb &&
        updated < goal &&
        metricsNotifier.value.waterReminderEnabled &&
        isEnabledNotifier.value) {
      await LocalNotificationService.scheduleWaterReminder(
        intervalHours: metricsNotifier.value.waterReminderIntervalHours,
        fromTime: DateTime.now(),
      );
    }
  }

  static Future<void> setStepGoal(int goal) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_userKey(_stepGoalKey), goal);
    } catch (_) {}
    metricsNotifier.value = metricsNotifier.value.copyWith(stepGoal: goal);
  }

  static Future<void> setWaterGoal(int goal) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_userKey(_waterGoalKey), goal);
    } catch (_) {}
    metricsNotifier.value =
        metricsNotifier.value.copyWith(waterGoalMilliliters: goal);

    if (!kIsWeb) {
      final current = metricsNotifier.value.waterMilliliters;
      if (current >= goal) {
        await LocalNotificationService.cancelWaterReminder();
      } else if (metricsNotifier.value.waterReminderEnabled &&
          isEnabledNotifier.value) {
        await LocalNotificationService.scheduleWaterReminder(
          intervalHours: metricsNotifier.value.waterReminderIntervalHours,
          fromTime: DateTime.now(),
        );
      }
    }
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
        if (enabled &&
            isEnabledNotifier.value &&
            metricsNotifier.value.waterMilliliters <
                metricsNotifier.value.waterGoalMilliliters) {
          await LocalNotificationService.scheduleWaterReminder(
            intervalHours: interval,
            fromTime: DateTime.now(),
          );
        } else {
          await LocalNotificationService.cancelWaterReminder();
        }
      }
      try {
        await ApiClient.put('/users/me', {'water_reminder_enabled': enabled});
      } catch (_) {}
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
