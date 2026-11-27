import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'auth_helper.dart';
import 'local_notification_service.dart';
import 'medication_reminders.dart';

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
  final List<int>
      weeklySteps; // Mon-Sun daily steps (7 days, starts at [0,0,0,0,0,0,0])
  final bool
      breathingWeeklyReminderEnabled; // weekly breathing & anti-stress reminder
  final double? heightCm; // e.g. 170.0 cm
  final String? bloodType;
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
    this.waterReminderEnabled = false,
    this.waterReminderIntervalHours = 2,
    this.isNativePedometerActive = true,
    this.weeklySteps = const [0, 0, 0, 0, 0, 0, 0],
    this.breathingWeeklyReminderEnabled = true,
    this.heightCm,
    this.weightKg,
    this.bloodType,
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
    String? bloodType,
    bool clearBloodType = false,
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
      bloodType: clearBloodType ? null : bloodType ?? this.bloodType,
      bmi: bmi ?? this.bmi,
      bmiCategory: bmiCategory ?? this.bmiCategory,
    );
  }

  static double? calculateBMI(double? heightCm, double? weightKg) {
    if (heightCm == null ||
        weightKg == null ||
        heightCm <= 0 ||
        weightKg <= 0) {
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
  static const String _stepsKey = 'health_daily_steps_v2';
  static const String _remoteStepsKey = 'health_synced_steps';
  static const String _pendingStepsKey = 'health_pending_steps';
  static const String _sensorOwnerKey = 'health_sensor_owner_v2';
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
  static const String _sensorReadingKey = 'health_sensor_reading_v2';
  static const String _bloodTypeKey = 'health_blood_type';

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

  static const _backgroundSteps = MethodChannel('salud_now/background_steps');
  static const _recordedStepsKey = 'health_background_steps';
  static Future<void> _recordingQueue = Future<void>.value();
  static bool _recordingPending = false;

  static bool get _hasAndroidRecorder =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> _trackingQueue = Future<void>.value();
  static int _sensorGeneration = 0;
  static int _accountGeneration = 0;
  static int _bodyRevision = 0;
  static bool _loaded = false;
  static final Set<String> _syncingUsers = {};

  static Future<void> _track(Future<void> Function() operation) {
    final result = _trackingQueue.then((_) => operation());
    _trackingQueue = result.catchError((Object error) {
      debugPrint('Error actualizando el registro de pasos: $error');
    });
    return _trackingQueue;
  }

  static String _dayKey(DateTime date) =>
      date.toIso8601String().substring(0, 10);

  static String _getTodayStr() => _dayKey(DateTime.now());

  static String _getCurrentWeekMondayStr() {
    final now = DateTime.now();
    return _dayKey(DateTime(now.year, now.month, now.day - now.weekday + 1));
  }

  static String _dailyKey(String key, String day) => _userKey('${key}_$day');

  static int _deviceTotal(SharedPreferences prefs, String day) => math.max(
        prefs.getInt(_dailyKey(_stepsKey, day)) ?? 0,
        prefs.getInt(_dailyKey(_recordedStepsKey, day)) ?? 0,
      );

  static int _dailyTotal(SharedPreferences prefs, String day) => math.max(
        _deviceTotal(prefs, day),
        prefs.getInt(_dailyKey(_remoteStepsKey, day)) ?? 0,
      );

  static Future<void> _refreshBackgroundSteps({bool history = false}) {
    if (!_hasAndroidRecorder ||
        !_loaded ||
        _activeUserId == 'guest' ||
        !isEnabledNotifier.value ||
        (_recordingPending && !history)) {
      return Future<void>.value();
    }
    final account = _activeUserId;
    final generation = _accountGeneration;
    _recordingPending = true;
    final result = _recordingQueue.then((_) async {
      if (generation != _accountGeneration ||
          !isEnabledNotifier.value ||
          !(await Permission.activityRecognition.status).isGranted) return;
      final prefs = await SharedPreferences.getInstance();
      if (_accountToken(prefs, account) == null) return;
      final today = _getTodayStr();
      final totals = await _backgroundSteps.invokeMapMethod<String, int>(
        'refresh',
        {
          'account': account,
          'seed': _deviceTotal(prefs, today),
          'history': history
        },
      ).timeout(const Duration(seconds: 8));
      if (totals == null || totals.isEmpty) return;

      await _track(() async {
        if (generation != _accountGeneration || !isEnabledNotifier.value)
          return;
        await _resetDay();
        final before = metricsNotifier.value.steps;
        for (final entry in totals.entries) {
          final key = _dailyKey(_recordedStepsKey, entry.key);
          final value = entry.value.clamp(0, 100000);
          if (value <= (prefs.getInt(key) ?? 0)) continue;
          await prefs.setInt(key, value);
          await prefs.setInt(_dailyKey(_pendingStepsKey, entry.key),
              _deviceTotal(prefs, entry.key));
        }
        final steps = _dailyTotal(prefs, _getTodayStr());
        metricsNotifier.value = metricsNotifier.value.copyWith(
          steps: steps,
          weeklySteps: _readWeek(prefs, _getCurrentWeekMondayStr()),
        );
        if (steps > before) {
          await _checkStepGoalCelebration(
              steps, metricsNotifier.value.stepGoal);
        }
      });
    }).catchError((Object error) {
      debugPrint('No se pudo leer el registro de pasos en segundo plano.');
    }).whenComplete(() {
      _recordingPending = false;
    });
    _recordingQueue = result;
    return result;
  }

  static Future<void> _stopBackgroundSteps(String? account) {
    if (!_hasAndroidRecorder) return Future<void>.value();
    _recordingQueue = _recordingQueue.then((_) async {
      try {
        await _backgroundSteps.invokeMethod<void>(
            'stop', {'account': account}).timeout(const Duration(seconds: 5));
      } catch (_) {
        debugPrint('No se pudo detener el registro de pasos en segundo plano.');
      }
    });
    return _recordingQueue;
  }

  static void _startMidnightTimer() {
    _midnightCheckTimer?.cancel();
    _midnightCheckTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
      await _track(_resetDay);
      await _refreshBackgroundSteps();
      unawaited(_syncSteps());
    });
  }

  static Future<void> onAppResumed() async {
    unawaited(_refreshMedicationReminders());
    await _track(_resetDay);
    unawaited(_syncSteps(refresh: true));
    if (isEnabledNotifier.value) {
      await initializePedometer(forceRestart: true);
    }
  }

  static Future<void> onAppPaused() async {
    await _trackingQueue;
    unawaited(_syncSteps());
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

  static List<int> _readWeek(SharedPreferences prefs, String monday) {
    final saved = prefs.getString(_userKey(_weeklyStepsWeekKey)) == monday
        ? prefs.getString(_userKey(_weeklyStepsKey))?.split(',')
        : null;
    final start = DateTime.parse(monday);
    final today = _getTodayStr();
    return List.generate(7, (index) {
      final day = _dayKey(DateTime(start.year, start.month, start.day + index));
      final count = _dailyTotal(prefs, day);
      if (count > 0 ||
          day.compareTo(today) >= 0 ||
          saved == null ||
          index >= saved.length) {
        return count;
      }
      return (int.tryParse(saved[index]) ?? 0).clamp(0, 100000);
    });
  }

  static Future<void> _resetDay() async {
    if (!_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = _dayKey(now);
    if (prefs.getString(_userKey(_lastDayDateKey)) == today) return;

    final weekly = _readWeek(prefs, _getCurrentWeekMondayStr());
    await prefs.setInt(_userKey(_waterMlKey), 0);
    await prefs.setString(_userKey(_lastDayDateKey), today);

    metricsNotifier.value = metricsNotifier.value.copyWith(
      steps: weekly[now.weekday - 1],
      waterMilliliters: 0,
      weeklySteps: weekly,
    );
    if (!kIsWeb &&
        metricsNotifier.value.waterReminderEnabled &&
        isEnabledNotifier.value) {
      await LocalNotificationService.scheduleWaterReminder(
        intervalHours: metricsNotifier.value.waterReminderIntervalHours,
        fromTime: now,
      );
    }
  }

  static String? _accountToken(SharedPreferences prefs, String user) {
    final token = prefs.getString('access_token');
    return user != 'guest' && AuthHelper.getUserIdFromToken(token) == user
        ? token
        : null;
  }

  static Future<void> _syncSteps({bool refresh = false}) async {
    final user = _activeUserId;
    final generation = _accountGeneration;
    if (kIsWeb || !_loaded || user == 'guest' || !_syncingUsers.add(user)) {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = _accountToken(prefs, user);
      if (token == null) return;
      final prefix = 'user_${user}_${_pendingStepsKey}_';
      final keys = prefs
          .getKeys()
          .where((key) => key.startsWith(prefix))
          .toList()
        ..sort();
      final totals = {
        for (final key in keys.take(100))
          key.substring(prefix.length): prefs.getInt(key) ?? 0,
      };
      if (!refresh && totals.isEmpty) return;
      final monday = _getCurrentWeekMondayStr();
      final response = await ApiClient.put(
        '/users/me/steps',
        {'week_start': monday, 'totals': totals},
        accessToken: token,
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return;
      final remote = Map<String, int>.from(jsonDecode(response.body) as Map);
      await _track(() async {
        for (final entry in totals.entries) {
          final key = '$prefix${entry.key}';
          if (prefs.getInt(key) == entry.value) await prefs.remove(key);
        }
        if (generation != _accountGeneration) return;
        await _cacheSyncedSteps(prefs, remote);
        if (monday != _getCurrentWeekMondayStr()) return;
        await _resetDay();
        final weekly = _readWeek(prefs, monday);
        metricsNotifier.value = metricsNotifier.value.copyWith(
          steps: _dailyTotal(prefs, _getTodayStr()),
          weeklySteps: weekly,
        );
      });
    } catch (error) {
      debugPrint('No se pudo sincronizar el historial de pasos: $error');
    } finally {
      _syncingUsers.remove(user);
    }
  }

  static Future<void> _cacheSyncedSteps(
    SharedPreferences prefs,
    Map<String, int> remote,
  ) async {
    for (final entry in remote.entries) {
      final key = _dailyKey(_remoteStepsKey, entry.key);
      if (entry.value > (prefs.getInt(key) ?? 0)) {
        await prefs.setInt(key, entry.value);
      }
    }
  }

  static Future<List<int>> loadStepWeek(DateTime start) async {
    final monday = _dayKey(start);
    final generation = _accountGeneration;
    final prefs = await SharedPreferences.getInstance();
    if (generation != _accountGeneration) {
      throw StateError('La cuenta cambió.');
    }
    final token = _accountToken(prefs, _activeUserId);
    if (token != null) {
      try {
        final response = await ApiClient.get(
          '/users/me/steps?week_start=$monday',
          accessToken: token,
        ).timeout(const Duration(seconds: 10));
        if (response.statusCode != 200) {
          throw StateError('Historial no disponible.');
        }
        final remote = Map<String, int>.from(jsonDecode(response.body) as Map);
        await _track(() async {
          if (generation == _accountGeneration) {
            await _cacheSyncedSteps(prefs, remote);
          }
        });
      } catch (_) {
        if (generation != _accountGeneration ||
            _readWeek(prefs, monday).every((total) => total == 0)) {
          rethrow;
        }
      }
    }
    if (generation != _accountGeneration) throw StateError('La cuenta cambió.');
    return _readWeek(prefs, monday);
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

  static Future<void> _refreshMedicationReminders() async {
    try {
      await MedicationReminderService.refresh();
    } catch (_) {
      debugPrint(
          'No se pudieron reprogramar los recordatorios de medicamentos.');
    }
  }

  static Future<void> _loadMedicationReminders(String? userId) async {
    try {
      await MedicationReminderService.activate(userId);
    } catch (_) {
      debugPrint('No se pudieron cargar los recordatorios de medicamentos.');
    }
  }

  /// Carga las métricas aisladas para el usuario activo (paciente, doctor o invitado).
  static Future<void> loadForUser(String? userId) => _track(() async {
        final newUserId =
            (userId != null && userId.isNotEmpty) ? userId : 'guest';
        if (_loaded && _activeUserId == newUserId) return;
        await _loadMedicationReminders(userId);

        try {
          final prefs = await SharedPreferences.getInstance();
          await _stopPedometer();
          if (_loaded && _activeUserId != newUserId) {
            unawaited(_stopBackgroundSteps(_activeUserId));
            await prefs.remove(_userKey(_sensorReadingKey));
            await prefs.remove(_sensorOwnerKey);
          }
          _activeUserId = newUserId;
          _accountGeneration++;
          _loaded = true;
          final now = DateTime.now();
          final today = _dayKey(now);
          final monday = _getCurrentWeekMondayStr();
          final st = _dailyTotal(prefs, today);
          final water = prefs.getString(_userKey(_lastDayDateKey)) == today
              ? prefs.getInt(_userKey(_waterMlKey)) ?? 0
              : 0;
          final weekly = _readWeek(prefs, monday);
          weekly[now.weekday - 1] = st;
          await prefs.setInt(_userKey(_waterMlKey), water);
          await prefs.setString(_userKey(_lastDayDateKey), today);
          await prefs.setString(_userKey(_weeklyStepsWeekKey), monday);
          await prefs.setString(_userKey(_weeklyStepsKey), weekly.join(','));

          final isEnabled = prefs.getBool(_userKey(_enabledKey)) ?? false;
          isEnabledNotifier.value = isEnabled;
          if (!isEnabled || newUserId == 'guest')
            unawaited(_stopBackgroundSteps(null));

          final hr = prefs.getInt(_userKey(_heartRateKey)) ?? 72;
          final stepGoal = prefs.getInt(_userKey(_stepGoalKey)) ?? 10000;
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
            bloodType: prefs.getString(_userKey(_bloodTypeKey)),
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
            unawaited(initializePedometer());
          } else if (!isEnabled && !kIsWeb) {
            await LocalNotificationService.cancelWaterReminder();
            await LocalNotificationService.cancelWeeklyBreathingReminder();
            await LocalNotificationService.cancelStepReminders();
          }
          unawaited(_syncSteps(refresh: true));
          unawaited(_loadBodyMetrics());
        } catch (e) {
          debugPrint(
              'Error al cargar métricas de salud para usuario $_activeUserId: $e');
        }
      });

  static Future<void> _stopPedometer() async {
    _sensorGeneration++;
    final subscription = _stepCountSubscription;
    _stepCountSubscription = null;
    await subscription?.cancel();
  }

  static Future<void> onLogout() async {
    await _loadMedicationReminders(null);
    await _refreshBackgroundSteps(history: true);
    final account = _activeUserId;
    await _track(() async {
      isEnabledNotifier.value = false;
      await _stopPedometer();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userKey(_sensorReadingKey));
      await prefs.remove(_sensorOwnerKey);
    });
    await _stopBackgroundSteps(account);
    await _syncSteps();
    await _track(() async {
      _accountGeneration++;
      _activeUserId = 'guest';
      _loaded = false;
      isEnabledNotifier.value = false;
      metricsNotifier.value = const HealthMetrics();
      if (!kIsWeb) {
        await LocalNotificationService.cancelWaterReminder();
        await LocalNotificationService.cancelWeeklyBreathingReminder();
        await LocalNotificationService.cancelStepReminders();
      }
    });
  }

  static Future<void> initializePedometer({bool forceRestart = false}) async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS) ||
        !isEnabledNotifier.value) {
      return;
    }

    final account = _accountGeneration;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        var status = await Permission.activityRecognition.status;
        if (!status.isGranted) {
          status = await Permission.activityRecognition.request();
        }
        if (!status.isGranted) return;
        if (account == _accountGeneration) {
          unawaited(
              _refreshBackgroundSteps(history: true).then((_) => _syncSteps()));
        }
      }

      await _track(() async {
        if (account != _accountGeneration || !isEnabledNotifier.value) return;
        if (_stepCountSubscription != null && !forceRestart) return;
        await _stopPedometer();
        final generation = _sensorGeneration;
        _stepCountSubscription = Pedometer.stepCountStream.listen(
          (event) => unawaited(_track(() async {
            if (generation != _sensorGeneration || !isEnabledNotifier.value) {
              return;
            }
            await _recordReading(event);
          })),
          onError: (Object error) {
            debugPrint('Sensor de podómetro no disponible: $error');
          },
        );
      });
    } catch (error) {
      debugPrint('Aviso inicializando sensor de podómetro: $error');
    }
  }

  static Future<void> _recordReading(StepCount event) async {
    await _resetDay();
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = _dayKey(now);
    final sensorKey = _userKey(_sensorReadingKey);
    if (_dayKey(event.timeStamp) != today) return;
    final reading = event.steps;
    final old = prefs.getString(sensorKey)?.split(':');
    final previous = old != null &&
            old.length == 2 &&
            old.first == today &&
            prefs.getString(_sensorOwnerKey) == _activeUserId
        ? int.tryParse(old.last)
        : null;

    // El sensor entrega un acumulado. Un cambio de día, de cuenta o un
    // reinicio del contador requiere una nueva lectura de referencia.
    if (previous == null || reading < previous) {
      await prefs.setString(sensorKey, '$today:$reading');
      await prefs.setString(_sensorOwnerKey, _activeUserId);
      return;
    }
    if (reading == previous) return;

    final stepsKey = _dailyKey(_stepsKey, today);
    final localSteps =
        ((prefs.getInt(stepsKey) ?? 0) + reading - previous).clamp(0, 100000);
    await Future.wait([
      prefs.setString(sensorKey, '$today:$reading'),
      prefs.setInt(stepsKey, localSteps),
      if (_activeUserId != 'guest')
        prefs.setInt(
          _dailyKey(_pendingStepsKey, today),
          math.max(localSteps,
              prefs.getInt(_dailyKey(_recordedStepsKey, today)) ?? 0),
        ),
    ]);
    final steps = _dailyTotal(prefs, today);
    if (steps == metricsNotifier.value.steps) return;
    final weekly = _readWeek(prefs, _getCurrentWeekMondayStr());
    metricsNotifier.value = metricsNotifier.value.copyWith(
      steps: steps,
      weeklySteps: weekly,
    );
    await _checkStepGoalCelebration(steps, metricsNotifier.value.stepGoal);
  }

  /// Activa o desactiva el módulo de salud globalmente.
  /// Si se desactiva, se cancelan de inmediato todas las notificaciones de agua, pasos y respiración.
  static Future<void> setEnabled(bool enabled) async {
    isEnabledNotifier.value = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_userKey(_enabledKey), enabled);

      if (!kIsWeb) {
        if (!enabled) {
          unawaited(_stopBackgroundSteps(_activeUserId));
          // Desactivar: cancelar todas las notificaciones del módulo de salud
          await LocalNotificationService.cancelWeeklyBreathingReminder();
          await LocalNotificationService.cancelWaterReminder();
          await LocalNotificationService.cancelStepReminders();
          await _track(() async {
            await _stopPedometer();
            await prefs.remove(_userKey(_sensorReadingKey));
            await prefs.remove(_sensorOwnerKey);
          });
          unawaited(
              ApiClient.put('/users/me', {'water_reminder_enabled': false}));
        } else {
          // Activar: iniciar podómetro y reprogramar recordatorios según preferencias
          await LocalNotificationService.scheduleDailyStepReminders();
          await initializePedometer(forceRestart: true);
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
          } else {
            await LocalNotificationService.cancelWaterReminder();
            unawaited(
                ApiClient.put('/users/me', {'water_reminder_enabled': false}));
          }
        }
      }
    } catch (_) {}
  }

  static Future<void> _loadBodyMetrics() async {
    final generation = _accountGeneration;
    final revision = _bodyRevision;
    final prefs = await SharedPreferences.getInstance();
    final token = _accountToken(prefs, _activeUserId);
    if (token == null) return;
    try {
      final response = await ApiClient.get('/users/me', accessToken: token)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200 ||
          generation != _accountGeneration ||
          revision != _bodyRevision) {
        return;
      }
      final profile = jsonDecode(response.body) as Map<String, dynamic>;
      final current = metricsNotifier.value;
      final height =
          (profile['height_cm'] as num?)?.toDouble() ?? current.heightCm;
      final weight =
          (profile['weight_kg'] as num?)?.toDouble() ?? current.weightKg;
      final bloodType = profile['blood_type'] as String?;
      final bmi = HealthMetrics.calculateBMI(height, weight);
      final key = _userKey(_bloodTypeKey);
      if (profile.containsKey('blood_type')) {
        if (bloodType == null) {
          unawaited(prefs.remove(key));
        } else {
          unawaited(prefs.setString(key, bloodType));
        }
      }
      metricsNotifier.value = current.copyWith(
        heightCm: height,
        weightKg: weight,
        bmi: bmi,
        bmiCategory: HealthMetrics.getBMICategory(bmi),
        bloodType: bloodType,
        clearBloodType: profile.containsKey('blood_type') && bloodType == null,
      );
    } catch (error) {
      debugPrint('No se pudieron cargar los datos de salud: $error');
    }
  }

  static Future<void> updateBloodType(String? bloodType) async {
    final generation = _accountGeneration;
    final prefs = await SharedPreferences.getInstance();
    final token = _accountToken(prefs, _activeUserId);
    if (token == null) throw StateError('Se requiere una sesión activa.');
    final key = _userKey(_bloodTypeKey);
    final response = await ApiClient.put(
      '/users/me',
      {'blood_type': bloodType},
      accessToken: token,
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw StateError('El servidor no guardó el tipo de sangre.');
    }
    final profile = jsonDecode(response.body) as Map;
    if (!profile.containsKey('blood_type') ||
        profile['blood_type'] != bloodType) {
      throw StateError('El servidor no guardó el tipo de sangre.');
    }
    if (generation != _accountGeneration) return;
    _bodyRevision++;
    metricsNotifier.value = metricsNotifier.value.copyWith(
      bloodType: bloodType,
      clearBloodType: bloodType == null,
    );
    try {
      if (bloodType == null) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, bloodType);
      }
    } catch (_) {
      // The server has already confirmed the update.
    }
  }

  static Future<void> updateBodyMetrics({
    required double heightCm,
    required double weightKg,
  }) async {
    final generation = _accountGeneration;
    final prefs = await SharedPreferences.getInstance();
    if (generation != _accountGeneration) return;
    final token = _accountToken(prefs, _activeUserId);
    if (token == null) throw StateError('Se requiere una sesión activa.');
    final heightKey = _userKey(_heightKey);
    final weightKey = _userKey(_weightKey);
    final response = await ApiClient.put(
      '/users/me',
      {'height_cm': heightCm, 'weight_kg': weightKg},
      accessToken: token,
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw StateError('El servidor no guardó las medidas.');
    }
    final profile = jsonDecode(response.body) as Map;
    final height = (profile['height_cm'] as num).toDouble();
    final weight = (profile['weight_kg'] as num).toDouble();
    if (generation != _accountGeneration) return;
    _bodyRevision++;
    final bmi = HealthMetrics.calculateBMI(height, weight);
    metricsNotifier.value = metricsNotifier.value.copyWith(
      heightCm: height,
      weightKg: weight,
      bmi: bmi,
      bmiCategory: HealthMetrics.getBMICategory(bmi),
    );
    try {
      await prefs.setDouble(heightKey, height);
      await prefs.setDouble(weightKey, weight);
    } catch (_) {
      // The server has already confirmed the update.
    }
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
        unawaited(
            ApiClient.put('/users/me', {'water_reminder_enabled': false}));
      }
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
      if (!kIsWeb) {
        try {
          await ApiClient.put('/users/me', {'water_reminder_enabled': enabled});
        } catch (_) {}
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
