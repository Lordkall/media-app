import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'health_module_helper.dart';
import 'smartwatch_ble_helper.dart';

enum HealthPlatformStatus {
  notConfigured,
  unsupported,
  available,
  needsInstall,
  authorized,
  unauthorized,
  syncing,
  error,
}

class HealthConnectHelper {
  HealthConnectHelper._();

  static final Health _health = Health();

  static final ValueNotifier<HealthPlatformStatus> statusNotifier =
      ValueNotifier<HealthPlatformStatus>(HealthPlatformStatus.notConfigured);

  static final ValueNotifier<DateTime?> lastSyncNotifier =
      ValueNotifier<DateTime?>(null);

  static final List<HealthDataType> _dataTypes = [
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.SLEEP_SESSION,
    HealthDataType.SLEEP_ASLEEP,
  ];

  static bool _isInitialized = false;
  static Timer? _autoSyncTimer;

  static String get platformName {
    if (kIsWeb) return 'Salud Web';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'Google Health Connect';
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'Apple Health';
    }
    return 'Health Connect / Apple Health';
  }

  static Future<void> initialize() async {
    if (kIsWeb) {
      statusNotifier.value = HealthPlatformStatus.unsupported;
      return;
    }
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      await _health.configure();

      if (defaultTargetPlatform == TargetPlatform.android) {
        final sdkStatus = await _health.getHealthConnectSdkStatus();
        if (sdkStatus == HealthConnectSdkStatus.sdkUnavailable) {
          statusNotifier.value = HealthPlatformStatus.unsupported;
          return;
        } else if (sdkStatus == HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired) {
          statusNotifier.value = HealthPlatformStatus.needsInstall;
          return;
        }
      }

      final permissions = _dataTypes.map((_) => HealthDataAccess.READ).toList();
      final hasPerms = await _health.hasPermissions(_dataTypes, permissions: permissions);
      if (hasPerms == true) {
        statusNotifier.value = HealthPlatformStatus.authorized;
        unawaited(syncHealthData());
      } else {
        statusNotifier.value = HealthPlatformStatus.available;
      }

      _autoSyncTimer?.cancel();
      // Auto sincronización periódica cada 60 segundos si está autorizado
      _autoSyncTimer = Timer.periodic(const Duration(seconds: 60), (_) {
        if (statusNotifier.value == HealthPlatformStatus.authorized) {
          syncHealthData();
        }
      });
    } catch (e) {
      debugPrint('Error inicializando HealthConnectHelper: $e');
      statusNotifier.value = HealthPlatformStatus.error;
    }
  }

  static Future<bool> requestAuthorization() async {
    if (kIsWeb) return false;
    try {
      await _health.configure();

      if (defaultTargetPlatform == TargetPlatform.android) {
        final sdkStatus = await _health.getHealthConnectSdkStatus();
        if (sdkStatus == HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired) {
          statusNotifier.value = HealthPlatformStatus.needsInstall;
          await _health.installHealthConnect();
          return false;
        }
      }

      statusNotifier.value = HealthPlatformStatus.syncing;
      final permissions = _dataTypes.map((_) => HealthDataAccess.READ).toList();
      final authorized = await _health.requestAuthorization(_dataTypes, permissions: permissions);
      if (authorized) {
        statusNotifier.value = HealthPlatformStatus.authorized;
        await syncHealthData();
        return true;
      } else {
        statusNotifier.value = HealthPlatformStatus.unauthorized;
        return false;
      }
    } catch (e) {
      debugPrint('Error solicitando permisos de Health Connect / Apple Health: $e');
      statusNotifier.value = HealthPlatformStatus.error;
      return false;
    }
  }

  static Future<void> installHealthConnect() async {
    try {
      await _health.installHealthConnect();
    } catch (e) {
      debugPrint('Error al abrir Play Store para Health Connect: $e');
    }
  }

  static Future<void> syncHealthData() async {
    if (kIsWeb) return;
    try {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      final yesterdayEvening = midnight.subtract(const Duration(hours: 14));
      final recentWindow = now.subtract(const Duration(hours: 24));

      // 1. Pasos de hoy registrados en la plataforma de salud
      int? stepsToday;
      try {
        stepsToday = await _health.getTotalStepsInInterval(midnight, now);
      } catch (e) {
        debugPrint('Error leyendo pasos de Health: $e');
      }

      // 2. Ritmo Cardíaco más reciente (últimas 24h)
      int? latestHeartRate;
      try {
        final heartPoints = await _health.getHealthDataFromTypes(
          types: [HealthDataType.HEART_RATE],
          startTime: recentWindow,
          endTime: now,
        );
        if (heartPoints.isNotEmpty) {
          heartPoints.sort((a, b) => b.dateTo.compareTo(a.dateTo));
          final val = heartPoints.first.value;
          if (val is NumericHealthValue) {
            latestHeartRate = val.numericValue.round();
          } else {
            final parsed = num.tryParse(val.toString().replaceAll(RegExp(r'[^0-9.]'), ''));
            if (parsed != null) latestHeartRate = parsed.round();
          }
        }
      } catch (e) {
        debugPrint('Error leyendo ritmo cardíaco de Health: $e');
      }

      // 3. Horas de sueño (anoche hasta hoy)
      double? sleepHours;
      try {
        final sleepPoints = await _health.getHealthDataFromTypes(
          types: [HealthDataType.SLEEP_SESSION, HealthDataType.SLEEP_ASLEEP],
          startTime: yesterdayEvening,
          endTime: now,
        );
        if (sleepPoints.isNotEmpty) {
          int totalMinutes = 0;
          for (final p in sleepPoints) {
            final diff = p.dateTo.difference(p.dateFrom).inMinutes;
            if (diff > 0 && diff < 1200) {
              totalMinutes += diff;
            }
          }
          if (totalMinutes > 30) {
            sleepHours = double.parse((totalMinutes / 60.0).toStringAsFixed(1));
          }
        }
      } catch (e) {
        debugPrint('Error leyendo sueño de Health: $e');
      }

      final cur = HealthModuleHelper.metricsNotifier.value;

      // El usuario solicitó:
      // - Pasos siguen contándose con el teléfono (mantenemos cur.steps si el podómetro del móvil está activo).
      // - Ritmo cardíaco y Horas de sueño se toman directamente de la sincronización del smartwatch.
      final finalSteps = (cur.steps > 0)
          ? cur.steps
          : ((stepsToday != null && stepsToday > 0) ? stepsToday : cur.steps);

      final finalHeartRate = (latestHeartRate != null && latestHeartRate >= 35 && latestHeartRate <= 230)
          ? latestHeartRate
          : cur.heartRate;

      final finalSleep = (sleepHours != null && sleepHours >= 1.0 && sleepHours <= 18.0)
          ? sleepHours
          : cur.sleepHours;

      if (latestHeartRate != null && latestHeartRate >= 35 && latestHeartRate <= 230) {
        SmartwatchBleHelper.liveBpmNotifier.value = latestHeartRate;
      }

      await HealthModuleHelper.updateMetrics(
        steps: finalSteps,
        heartRate: finalHeartRate,
        sleepHours: finalSleep,
      );

      lastSyncNotifier.value = DateTime.now();
      statusNotifier.value = HealthPlatformStatus.authorized;
      debugPrint('Sincronización de $platformName completada: HR=$finalHeartRate, Sueño=$finalSleep, Pasos=$finalSteps');
    } catch (e) {
      debugPrint('Error al sincronizar datos de salud: $e');
      statusNotifier.value = HealthPlatformStatus.authorized;
    }
  }
}
