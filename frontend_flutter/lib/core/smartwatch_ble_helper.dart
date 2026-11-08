import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_helper.dart';
import 'health_module_helper.dart';

enum SmartwatchConnectionStatus {
  disconnected,
  scanning,
  connecting,
  connected,
  error,
}

class DiscoveredSmartwatch {
  final BluetoothDevice device;
  final String name;
  final int rssi;
  final bool hasHeartRateService;

  const DiscoveredSmartwatch({
    required this.device,
    required this.name,
    required this.rssi,
    this.hasHeartRateService = false,
  });
}

class SmartwatchBleHelper {
  static final ValueNotifier<SmartwatchConnectionStatus> statusNotifier =
      ValueNotifier<SmartwatchConnectionStatus>(
          SmartwatchConnectionStatus.disconnected);

  static final ValueNotifier<String?> connectedDeviceNameNotifier =
      ValueNotifier<String?>(null);

  static final ValueNotifier<int?> liveBpmNotifier =
      ValueNotifier<int?>(null);

  static final ValueNotifier<List<DiscoveredSmartwatch>>
      discoveredDevicesNotifier =
      ValueNotifier<List<DiscoveredSmartwatch>>([]);

  static BluetoothDevice? _connectedDevice;
  static StreamSubscription<BluetoothConnectionState>? _connectionStateSub;
  static final List<StreamSubscription<List<int>>> _notifySubscriptions = [];
  static final List<BluetoothCharacteristic> _writeCharacteristics = [];
  static final List<BluetoothCharacteristic> _readCharacteristics = [];
  static StreamSubscription<List<ScanResult>>? _scanSub;

  // Standard Heart Rate GATT Service & Characteristic UUIDs
  static final Guid heartRateServiceUuid = Guid('180d');
  static final Guid heartRateMeasurementUuid = Guid('2a37');

  // Standard Battery GATT Service & Characteristic UUIDs
  static final Guid batteryServiceUuid = Guid('180f');
  static final Guid batteryLevelUuid = Guid('2a19');

  static String _prefKey(String key) {
    final userId = AuthHelper.getUserIdFromToken(null) ?? 'current';
    return 'user_${userId}_smartwatch_$key';
  }

  /// Inicializa la escucha de estado y reconecta el último dispositivo si estaba guardado
  static Future<void> initialize() async {
    if (kIsWeb) return;
    try {
      FlutterBluePlus.adapterState.listen((state) {
        if (state != BluetoothAdapterState.on &&
            statusNotifier.value == SmartwatchConnectionStatus.connected) {
          disconnect();
        }
      });

      // Intentar reconectar si había un reloj vinculado guardado
      final prefs = await SharedPreferences.getInstance();
      final lastId = prefs.getString(_prefKey('last_device_id'));
      final lastName = prefs.getString(_prefKey('last_device_name'));
      if (lastId != null && lastId.isNotEmpty) {
        connectedDeviceNameNotifier.value = lastName ?? 'Smart Watch';
        // Auto-reconexión silenciosa en segundo plano
        reconnectLastDevice();
      }
    } catch (e) {
      debugPrint('Error inicializando SmartwatchBleHelper: $e');
    }
  }

  /// Solicita permisos necesarios para Bluetooth Low Energy en Android / iOS
  static Future<bool> requestPermissions() async {
    if (kIsWeb) return false;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        // En Android 12+ (API 31+), los permisos Bluetooth son bluetoothScan y bluetoothConnect.
        final scanStatus = await Permission.bluetoothScan.request();
        final connectStatus = await Permission.bluetoothConnect.request();

        bool hasBt = (scanStatus.isGranted || scanStatus.isLimited) &&
            (connectStatus.isGranted || connectStatus.isLimited);

        // Si bluetoothScan o bluetoothConnect no están concedidos (o en Android <= 11), probar ubicación
        if (!hasBt) {
          final locationStatus = await Permission.locationWhenInUse.request();
          if (locationStatus.isGranted) {
            hasBt = true;
          }
        }
        return hasBt;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final status = await Permission.bluetooth.request();
        return status.isGranted;
      }
      return true;
    } catch (e) {
      debugPrint('Error solicitando permisos de Bluetooth: $e');
      return false;
    }
  }

  /// Inicia el escaneo de smartwatches y pulseras inteligentes cercanas
  static Future<void> startScan(
      {Duration timeout = const Duration(seconds: 12)}) async {
    if (kIsWeb) return;
    final hasPerms = await requestPermissions();
    if (!hasPerms) {
      debugPrint('Permisos de Bluetooth no concedidos');
      statusNotifier.value = SmartwatchConnectionStatus.error;
      return;
    }

    try {
      if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
        debugPrint('Bluetooth apagado, solicitando activación a Android...');
        try {
          await FlutterBluePlus.turnOn();
          final state = await FlutterBluePlus.adapterState
              .where((s) => s == BluetoothAdapterState.on)
              .first
              .timeout(const Duration(seconds: 4),
                  onTimeout: () => BluetoothAdapterState.off);
          if (state != BluetoothAdapterState.on) {
            statusNotifier.value = SmartwatchConnectionStatus.error;
            return;
          }
        } catch (e) {
          debugPrint('No se pudo activar Bluetooth automáticamente: $e');
          statusNotifier.value = SmartwatchConnectionStatus.error;
          return;
        }
      }

      statusNotifier.value = SmartwatchConnectionStatus.scanning;

      final initialList = <DiscoveredSmartwatch>[];
      final seenIds = <String>{};

      // 1. Obtener dispositivos BLE ya conectados al sistema Android (por ejemplo vinculados por Da Fit)
      try {
        final systemDevs = await FlutterBluePlus.systemDevices([]);
        for (final d in systemDevs) {
          final id = d.remoteId.str;
          if (seenIds.contains(id)) continue;
          seenIds.add(id);
          final name = d.platformName.isNotEmpty
              ? d.platformName
              : (d.advName.isNotEmpty ? d.advName : 'Smartwatch (Conectado)');
          initialList.add(DiscoveredSmartwatch(
            device: d,
            name: name,
            rssi: -50,
            hasHeartRateService: true,
          ));
        }
      } catch (e) {
        debugPrint('Error consultando systemDevices: $e');
      }

      // 2. Obtener dispositivos emparejados (bonded) en el teléfono
      try {
        final bonded = await FlutterBluePlus.bondedDevices;
        for (final d in bonded) {
          final id = d.remoteId.str;
          if (seenIds.contains(id)) continue;
          seenIds.add(id);
          final name = d.platformName.isNotEmpty
              ? d.platformName
              : (d.advName.isNotEmpty ? d.advName : '');
          if (name.trim().isEmpty) continue;
          initialList.add(DiscoveredSmartwatch(
            device: d,
            name: name,
            rssi: -65,
            hasHeartRateService: false,
          ));
        }
      } catch (e) {
        debugPrint('Error consultando bondedDevices: $e');
      }

      discoveredDevicesNotifier.value = List.from(initialList);

      await _scanSub?.cancel();
      _scanSub = FlutterBluePlus.scanResults.listen((results) {
        final currentList =
            List<DiscoveredSmartwatch>.from(discoveredDevicesNotifier.value);
        bool changed = false;

        for (final r in results) {
          final id = r.device.remoteId.str;
          final advName = r.advertisementData.advName;
          final platformName = r.device.platformName;
          final name = advName.isNotEmpty
              ? advName
              : (platformName.isNotEmpty ? platformName : '');

          if (name.trim().isEmpty) continue;

          final hasHr = r.advertisementData.serviceUuids
              .any((u) => u == heartRateServiceUuid);

          final existingIdx =
              currentList.indexWhere((e) => e.device.remoteId.str == id);
          if (existingIdx >= 0) {
            currentList[existingIdx] = DiscoveredSmartwatch(
              device: r.device,
              name: name,
              rssi: r.rssi,
              hasHeartRateService:
                  hasHr || currentList[existingIdx].hasHeartRateService,
            );
            changed = true;
          } else {
            currentList.add(DiscoveredSmartwatch(
              device: r.device,
              name: name,
              rssi: r.rssi,
              hasHeartRateService: hasHr,
            ));
            changed = true;
          }
        }

        if (changed) {
          currentList.sort((a, b) => b.rssi.compareTo(a.rssi));
          discoveredDevicesNotifier.value = currentList;
        }
      });

      await FlutterBluePlus.startScan(
        timeout: timeout,
        androidUsesFineLocation: false,
      );

      Future.delayed(timeout, () {
        if (statusNotifier.value == SmartwatchConnectionStatus.scanning) {
          statusNotifier.value = SmartwatchConnectionStatus.disconnected;
        }
      });
    } catch (e) {
      debugPrint('Error al escanear smartwatches: $e');
      statusNotifier.value = SmartwatchConnectionStatus.error;
    }
  }

  /// Detiene el escaneo activo
  static Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
      await _scanSub?.cancel();
      if (statusNotifier.value == SmartwatchConnectionStatus.scanning) {
        statusNotifier.value = SmartwatchConnectionStatus.disconnected;
      }
    } catch (_) {}
  }

  /// Conecta con un smartwatch específico y busca el servicio de ritmo cardíaco
  static Future<bool> connectToDevice(BluetoothDevice device,
      [String? deviceName]) async {
    if (kIsWeb) return false;
    try {
      await stopScan();
      statusNotifier.value = SmartwatchConnectionStatus.connecting;

      if (_connectedDevice != null && _connectedDevice != device) {
        await _connectedDevice?.disconnect();
      }

      _connectedDevice = device;
      final name = deviceName ??
          (device.platformName.isNotEmpty
              ? device.platformName
              : 'Smart Watch');

      await device.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );

      await _connectionStateSub?.cancel();
      _connectionStateSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.connected) {
          statusNotifier.value = SmartwatchConnectionStatus.connected;
          connectedDeviceNameNotifier.value = name;
        } else if (state == BluetoothConnectionState.disconnected) {
          statusNotifier.value = SmartwatchConnectionStatus.disconnected;
          liveBpmNotifier.value = null;
          connectedDeviceNameNotifier.value = null;
        }
      });

      for (final sub in _notifySubscriptions) {
        await sub.cancel();
      }
      _notifySubscriptions.clear();
      _writeCharacteristics.clear();
      _readCharacteristics.clear();

      final services = await device.discoverServices();
      debugPrint('Servicios BLE descubiertos en $name: ${services.length}');

      for (final s in services) {
        for (final c in s.characteristics) {
          if (c.properties.notify || c.properties.indicate) {
            try {
              await c.setNotifyValue(true);
              final sub = c.onValueReceived.listen((data) {
                _processIncomingData(data, c.uuid);
              });
              _notifySubscriptions.add(sub);
            } catch (e) {
              debugPrint('Error habilitando notify en ${c.uuid}: $e');
            }
          }

          if (c.properties.read) {
            _readCharacteristics.add(c);
            try {
              final readData = await c.read();
              _processIncomingData(readData, c.uuid);
            } catch (_) {}
          }

          if (c.properties.write || c.properties.writeWithoutResponse) {
            _writeCharacteristics.add(c);
          }
        }
      }

      // Enviar solicitud de telemetría a Da Fit (Y20GTA) y BLE genéricos
      await requestHeartRateReading();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey('last_device_id'), device.remoteId.str);
      await prefs.setString(_prefKey('last_device_name'), name);

      statusNotifier.value = SmartwatchConnectionStatus.connected;
      connectedDeviceNameNotifier.value = name;
      debugPrint(
          'Smartwatch conectado exitosamente: $name (${_notifySubscriptions.length} canales activos)');
      return true;
    } catch (e) {
      debugPrint('Error al conectar smartwatch: $e');
      statusNotifier.value = SmartwatchConnectionStatus.error;
      return false;
    }
  }

  /// Envía comandos a relojes Da Fit / Y20 / estándar para solicitar la lectura de pulso
  static Future<void> requestHeartRateReading() async {
    final commands = [
      [0x04, 0x01], // Da Fit / Moya start HR measurement / request live HR
      [0x05, 0x01], // Da Fit query current health status
      [0x09, 0x01], // Da Fit request last measurement
      [0xAA, 0x04, 0x01, 0x00],
      [0xBA, 0x01],
      [0x04, 0x02],
    ];

    for (final c in _writeCharacteristics) {
      for (final cmd in commands) {
        try {
          await c.write(cmd, withoutResponse: c.properties.writeWithoutResponse);
        } catch (_) {}
      }
    }

    for (final c in _readCharacteristics) {
      try {
        final data = await c.read();
        _processIncomingData(data, c.uuid);
      } catch (_) {}
    }
  }

  /// Reconecta el último dispositivo guardado si está disponible
  static Future<void> reconnectLastDevice() async {
    if (kIsWeb) return;
    try {
      if (statusNotifier.value == SmartwatchConnectionStatus.connected) return;
      final prefs = await SharedPreferences.getInstance();
      final lastId = prefs.getString(_prefKey('last_device_id'));
      final lastName = prefs.getString(_prefKey('last_device_name'));
      if (lastId != null && lastId.isNotEmpty) {
        final device = BluetoothDevice.fromId(lastId);
        await connectToDevice(device, lastName);
      }
    } catch (e) {
      debugPrint('Error reconectando smartwatch anterior: $e');
    }
  }

  /// Procesa cualquier paquete entrante de telemetría BLE (estándar o Da Fit/Y20)
  static void _processIncomingData(List<int> data, Guid uuid) {
    if (data.isEmpty) return;

    // 1. Estándar GATT Heart Rate Measurement (0x2A37)
    if (uuid == heartRateMeasurementUuid ||
        uuid.str.toLowerCase().contains('2a37')) {
      _parseHeartRateData(data);
      return;
    }

    // 2. Telemetría Da Fit / Y20 / Periféricos propietarios
    if (data.length >= 2) {
      // Ignorar paquetes de sincronización de fecha/hora (suelen comenzar con 0x01 y año actual)
      if (data.length >= 7 && data[0] == 0x01) return;

      for (int i = 0; i < data.length; i++) {
        final val = data[i];
        if (val >= 45 && val <= 220) {
          setLiveBpm(val);
          return;
        }
      }
    } else if (data.length == 1) {
      final val = data[0];
      if (val >= 45 && val <= 220) {
        setLiveBpm(val);
      }
    }
  }

  /// Parsea el paquete estándar de Heart Rate Measurement (GATT 0x2A37)
  static void _parseHeartRateData(List<int> data) {
    if (data.isEmpty) return;
    try {
      final flags = data[0];
      final is16Bit = (flags & 0x01) != 0;
      int bpm = 0;

      if (is16Bit && data.length >= 3) {
        bpm = data[1] + (data[2] << 8);
      } else if (!is16Bit && data.length >= 2) {
        bpm = data[1];
      }

      if (bpm >= 35 && bpm <= 240) {
        setLiveBpm(bpm);
      }
    } catch (e) {
      debugPrint('Error parseando datos de ritmo cardíaco: $e');
    }
  }

  /// Actualiza el ritmo cardíaco en vivo y sincroniza los modelos y estado global
  static void setLiveBpm(int bpm) {
    if (bpm < 35 || bpm > 240) return;
    liveBpmNotifier.value = bpm;
    HealthModuleHelper.updateMetrics(
      heartRate: bpm,
      sleepHours: HealthModuleHelper.metricsNotifier.value.sleepHours,
    );
  }

  /// Desconecta el smartwatch actualmente activo
  static Future<void> disconnect() async {
    try {
      for (final sub in _notifySubscriptions) {
        await sub.cancel();
      }
      _notifySubscriptions.clear();
      _writeCharacteristics.clear();
      _readCharacteristics.clear();

      await _connectionStateSub?.cancel();
      _connectionStateSub = null;
      await _connectedDevice?.disconnect();
      _connectedDevice = null;
      liveBpmNotifier.value = null;
      connectedDeviceNameNotifier.value = null;
      statusNotifier.value = SmartwatchConnectionStatus.disconnected;

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKey('last_device_id'));
      await prefs.remove(_prefKey('last_device_name'));
    } catch (e) {
      debugPrint('Error al desconectar smartwatch: $e');
    }
  }
}
