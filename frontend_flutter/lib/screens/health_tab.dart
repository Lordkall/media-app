import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/health_module_helper.dart';
import '../core/smartwatch_ble_helper.dart';

class HealthTab extends StatefulWidget {
  const HealthTab({super.key});

  @override
  State<HealthTab> createState() => _HealthTabState();
}

class _HealthTabState extends State<HealthTab> with TickerProviderStateMixin {
  // Breathing exercise controller
  late AnimationController _breathingController;
  late Animation<double> _breathingScale;
  bool _isBreathingActive = false;
  String _breathingPhase = 'Inhala 4s • Sostén 4s • Exhala 4s';

  // Water wave animation controller (movimiento constante del agua)
  late AnimationController _waterWaveController;

  // Selected day index in weekly bar chart (default today)
  int _selectedDayIndex = 0;

  @override
  void initState() {
    super.initState();
    _selectedDayIndex = (DateTime.now().weekday - 1).clamp(0, 6);
    HealthModuleHelper.initializePedometer();
    SmartwatchBleHelper.reconnectLastDevice();

    _waterWaveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();

    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );

    _breathingScale = Tween<double>(begin: 0.85, end: 1.25).animate(
      CurvedAnimation(
        parent: _breathingController,
        curve: Curves.easeInOutSine,
      ),
    );

    _breathingController.addStatusListener((status) {
      if (!_isBreathingActive) return;
      if (status == AnimationStatus.completed) {
        setState(() => _breathingPhase = 'Sostén el aire...');
        Future.delayed(const Duration(milliseconds: 3000), () {
          if (!mounted || !_isBreathingActive) return;
          setState(() => _breathingPhase = 'Exhala suavemente...');
          _breathingController.reverse();
        });
      } else if (status == AnimationStatus.dismissed) {
        setState(() => _breathingPhase = 'Inhala profundamente...');
        _breathingController.forward();
      }
    });
  }

  @override
  void dispose() {
    _waterWaveController.dispose();
    _breathingController.dispose();
    super.dispose();
  }

  void _toggleBreathing() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isBreathingActive = !_isBreathingActive;
      if (_isBreathingActive) {
        _breathingPhase = 'Inhala profundamente...';
        _breathingController.forward();
      } else {
        _breathingPhase = 'Inhala 4s • Sostén 4s • Exhala 4s';
        _breathingController.stop();
        _breathingController.reset();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const Scaffold(
        body: Center(
          child: Text(
            'El módulo de salud está disponible exclusivamente en la aplicación móvil.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        bottom: false,
        child: ValueListenableBuilder<bool>(
          valueListenable: HealthModuleHelper.isEnabledNotifier,
          builder: (context, isEnabled, _) {
            return ValueListenableBuilder<HealthMetrics>(
              valueListenable: HealthModuleHelper.metricsNotifier,
              builder: (context, metrics, _) {
                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // Header con título y switch de activación
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text(
                                      'Salud',
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF0B2545),
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Bienestar y seguimiento diario',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0756A4).withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.favorite_rounded,
                                    color: Color(0xFF0756A4),
                                    size: 24,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Switch Card: Activar módulo de salud
                            _buildActivationSwitchCard(isEnabled),
                          ],
                        ),
                      ),
                    ),

                    if (!isEnabled)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _buildDisabledState(context),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            // 1. Medidas Corporales & IMC (Estatura, Peso, IMC)
                            _buildBodyMetricsCard(context, metrics),
                            const SizedBox(height: 18),

                            // 2. Tarjeta de Vinculación Smartwatch (Bluetooth Low Energy)
                            _buildSmartwatchSyncCard(context),
                            const SizedBox(height: 18),

                            // 2. Tarjeta de Hidratación (Azul gradiente)
                            _buildHydrationCard(metrics),
                            const SizedBox(height: 18),

                            // 3. Tarjeta de Respiración (Azul gradiente)
                            _buildBreathingCard(),
                            const SizedBox(height: 18),

                            // 4. Tarjeta de Pasos en la Semana (Azul gradiente)
                            _buildWeeklyStepsCard(metrics),
                            const SizedBox(height: 18),

                            // 5. Métricas de hoy (Ritmo cardíaco y Sueño)
                            _buildDailySummaryCard(context, metrics),
                            const SizedBox(height: 18),

                            // 5. Configuración de Recordatorio Semanal Antiestrés
                            _buildWeeklyBreathingReminderCard(metrics),
                            const SizedBox(height: 18),

                            // 6. Configuración de recordatorios de hidratación
                            _buildReminderSettingsCard(metrics),
                          ]),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  // --- Tarjeta de Vinculación Smartwatch (Bluetooth Low Energy) ---
  Widget _buildSmartwatchSyncCard(BuildContext context) {
    return ValueListenableBuilder<SmartwatchConnectionStatus>(
      valueListenable: SmartwatchBleHelper.statusNotifier,
      builder: (context, status, _) {
        final isConnected = status == SmartwatchConnectionStatus.connected;
        final isScanning = status == SmartwatchConnectionStatus.scanning;
        final isConnecting = status == SmartwatchConnectionStatus.connecting;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isConnected
                  ? const Color(0xFF10B981).withValues(alpha: 0.35)
                  : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0B2545).withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isConnected
                          ? const Color(0xFF10B981).withValues(alpha: 0.12)
                          : const Color(0xFF0756A4).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.watch_rounded,
                      color: isConnected
                          ? const Color(0xFF10B981)
                          : const Color(0xFF0756A4),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Smartwatch / Reloj',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        ValueListenableBuilder<String?>(
                          valueListenable:
                              SmartwatchBleHelper.connectedDeviceNameNotifier,
                          builder: (context, deviceName, _) {
                            if (isConnected && deviceName != null) {
                              return Text(
                                deviceName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF10B981),
                                ),
                              );
                            }
                            return const Text(
                              'Vincula tu reloj para pulso en vivo',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isConnected
                          ? const Color(0xFF10B981).withValues(alpha: 0.12)
                          : (isScanning || isConnecting
                              ? const Color(0xFF0756A4).withValues(alpha: 0.1)
                              : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: isConnected
                                ? const Color(0xFF10B981)
                                : (isScanning || isConnecting
                                    ? const Color(0xFF0756A4)
                                    : const Color(0xFF94A3B8)),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isConnected
                              ? 'En vivo'
                              : (isScanning
                                  ? 'Buscando'
                                  : (isConnecting
                                      ? 'Conectando'
                                      : 'Desconectado')),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isConnected
                                ? const Color(0xFF059669)
                                : (isScanning || isConnecting
                                    ? const Color(0xFF0756A4)
                                    : const Color(0xFF64748B)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (isConnected) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.favorite_rounded,
                          color: Color(0xFFEF4444), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ValueListenableBuilder<int?>(
                          valueListenable: SmartwatchBleHelper.liveBpmNotifier,
                          builder: (context, bpm, _) {
                            return Text(
                              bpm != null
                                  ? '$bpm bpm (Transmitiendo en tiempo real)'
                                  : 'Esperando primera lectura del sensor...',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F172A),
                              ),
                            );
                          },
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          SmartwatchBleHelper.disconnect();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Desconectar',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '✓ Pasos: continúan registrándose con el teléfono para máxima precisión.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ] else ...[
                const Text(
                  'Al conectar tu smartwatch (Da Fit u otros), Salud Now medirá tu ritmo cardíaco en tiempo real mientras tus pasos continúan registrándose con tu teléfono.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0756A4), Color(0xFF007BFF)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () => _openSmartwatchModal(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.bluetooth_searching_rounded,
                          color: Colors.white, size: 18),
                      label: const Text(
                        'Vincular Smartwatch',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _openSmartwatchModal(BuildContext context) {
    SmartwatchBleHelper.startScan();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.watch_rounded,
                          color: Color(0xFF0756A4), size: 24),
                      SizedBox(width: 10),
                      Text(
                        'Vincular Smartwatch',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  ValueListenableBuilder<SmartwatchConnectionStatus>(
                    valueListenable: SmartwatchBleHelper.statusNotifier,
                    builder: (context, status, _) {
                      final isScanning =
                          status == SmartwatchConnectionStatus.scanning;
                      return IconButton(
                        icon: isScanning
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF0756A4),
                                ),
                              )
                            : const Icon(Icons.refresh_rounded,
                                color: Color(0xFF0756A4)),
                        onPressed: isScanning
                            ? null
                            : () => SmartwatchBleHelper.startScan(),
                        tooltip: 'Buscar de nuevo',
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Asegúrate de que tu reloj tenga el Bluetooth encendido. Si está vinculado a Da Fit u otra app, ciérrala o desconéctalo para que libere su señal.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 10),
              Expanded(
                child: ValueListenableBuilder<List<DiscoveredSmartwatch>>(
                  valueListenable:
                      SmartwatchBleHelper.discoveredDevicesNotifier,
                  builder: (context, devices, _) {
                    return ValueListenableBuilder<SmartwatchConnectionStatus>(
                      valueListenable: SmartwatchBleHelper.statusNotifier,
                      builder: (context, status, _) {
                        if (status == SmartwatchConnectionStatus.scanning &&
                            devices.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    color: Color(0xFF0756A4),
                                  ),
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Buscando relojes cercanos...',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Acerca tu reloj al teléfono',
                                  style: TextStyle(
                                      fontSize: 12, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          );
                        }

                        if (devices.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.bluetooth_disabled_rounded,
                                    size: 48, color: Color(0xFF94A3B8)),
                                const SizedBox(height: 12),
                                const Text(
                                  'No se detectaron smartwatches',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Padding(
                                  padding:
                                      EdgeInsets.symmetric(horizontal: 24),
                                  child: Text(
                                    'Verifica que el Bluetooth esté activo en tu teléfono y que el reloj esté encendido.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 20),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: const Color(0xFFBFDBFE)),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: const [
                                      Icon(Icons.info_outline_rounded,
                                          color: Color(0xFF1D4ED8), size: 18),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '¿Tu reloj está vinculado en Da Fit? Los smartwatches apagan su señal visible mientras están conectados activamente a otra app. Cierra la app Da Fit o desconecta el reloj allí un momento y presiona "Escanear otra vez".',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: Color(0xFF1E40AF),
                                            height: 1.35,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      SmartwatchBleHelper.startScan(),
                                  icon: const Icon(Icons.search_rounded),
                                  label: const Text('Escanear otra vez'),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.separated(
                          itemCount: devices.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final d = devices[index];
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                                border:
                                    Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0756A4)
                                          .withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.watch_rounded,
                                        color: Color(0xFF0756A4), size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          d.name,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Text(
                                              'Señal: ${d.rssi} dBm',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                            if (d.hasHeartRateService) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFEF4444)
                                                      .withValues(alpha: 0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: const Text(
                                                  '♥ Pulso',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFFEF4444),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: status ==
                                            SmartwatchConnectionStatus.connecting
                                        ? null
                                        : () async {
                                            HapticFeedback.selectionClick();
                                            final ok = await SmartwatchBleHelper
                                                .connectToDevice(
                                                    d.device, d.name);
                                            if (ok && ctx.mounted) {
                                              Navigator.pop(ctx);
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                      '✓ Conectado a ${d.name}'),
                                                  backgroundColor:
                                                      const Color(0xFF10B981),
                                                ),
                                              );
                                            }
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0756A4),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 8),
                                      minimumSize: Size.zero,
                                    ),
                                    child: const Text(
                                      'Conectar',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.info_outline_rounded,
                        size: 16, color: Color(0xFF64748B)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Los pasos diarios se mantienen contando desde el teléfono para no alterar tus registros.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Switch Card: Activar módulo de salud ---
  Widget _buildActivationSwitchCard(bool isEnabled) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isEnabled
              ? const Color(0xFF0756A4).withValues(alpha: 0.3)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B2545).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: isEnabled
                  ? const Color(0xFFEF4444).withValues(alpha: 0.12)
                  : const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.favorite_rounded,
              color: isEnabled ? const Color(0xFFEF4444) : const Color(0xFF94A3B8),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Activar módulo de salud',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isEnabled
                      ? 'Muestra pasos, ritmo cardíaco y sueño en inicio'
                      : 'Actívalo para ver hidratación, pasos y respiración',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: isEnabled,
            activeColor: const Color(0xFF0756A4),
            onChanged: (val) {
              HapticFeedback.selectionClick();
              HealthModuleHelper.setEnabled(val);
            },
          ),
        ],
      ),
    );
  }

  // --- Estado Desactivado ---
  Widget _buildDisabledState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF0756A4).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.monitor_heart_outlined,
                size: 64,
                color: Color(0xFF0756A4),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Módulo de salud desactivado',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0B2545),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Activa el módulo para registrar tus vasos de agua, seguir tu rutina de respiración guiada y ver tus pasos semanales.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0756A4), Color(0xFF0A3D78)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0756A4).withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  HealthModuleHelper.setEnabled(true);
                },
                icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                label: const Text(
                  'Activar ahora',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWaterGoalPicker(BuildContext context, int currentGoal) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: const [
                  Icon(Icons.water_drop_rounded,
                      color: Color(0xFF0284C7), size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Meta diaria de hidratación',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Elige tu consumo de agua recomendado por día. Las notificaciones se pausarán automáticamente al completar tu meta diaria.',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              _buildWaterGoalOption(
                ctx,
                ml: 2000,
                glasses: 8,
                title: '2000 ML / 8 vasos',
                subtitle: 'Predeterminada recomendada',
                isSelected: currentGoal == 2000,
              ),
              const SizedBox(height: 10),
              _buildWaterGoalOption(
                ctx,
                ml: 2500,
                glasses: 10,
                title: '2500 ML / 10 vasos',
                subtitle: 'Ideal para personas activas',
                isSelected: currentGoal == 2500,
              ),
              const SizedBox(height: 10),
              _buildWaterGoalOption(
                ctx,
                ml: 3000,
                glasses: 12,
                title: '3000 ML / 12 vasos',
                subtitle: 'Alto rendimiento o climas calurosos',
                isSelected: currentGoal == 3000,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWaterGoalOption(
    BuildContext context, {
    required int ml,
    required int glasses,
    required String title,
    required String subtitle,
    required bool isSelected,
  }) {
    return Material(
      color: isSelected ? const Color(0xFFE0F2FE) : const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          HapticFeedback.mediumImpact();
          await HealthModuleHelper.setWaterGoal(ml);
          if (context.mounted) Navigator.pop(context);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF0284C7)
                  : const Color(0xFFE2E8F0),
              width: isSelected ? 1.8 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF0284C7)
                      : const Color(0xFFE2E8F0),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.local_drink_rounded,
                  size: 20,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? const Color(0xFF0369A1)
                            : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF0284C7),
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 1. Tarjeta de Hidratación (Azul gradiente) ---
  Widget _buildHydrationCard(HealthMetrics metrics) {
    final glassesCount = (metrics.waterMilliliters / 250).toInt();
    final totalGlasses = (metrics.waterGoalMilliliters / 250).toInt();
    final fillFraction =
        (metrics.waterMilliliters / metrics.waterGoalMilliliters).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0756A4).withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Vaso con agua estilizado con onda animada continua
          SizedBox(
            width: 72,
            height: 104,
            child: AnimatedBuilder(
              animation: _waterWaveController,
              builder: (context, _) => CustomPaint(
                painter: _WaterGlassPainter(
                  fillFraction: fillFraction,
                  wavePhase: _waterWaveController.value * 2 * math.pi,
                ),
              ),
            ),
          ),
          const SizedBox(width: 22),

          // Información textual y controles + / -
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Agua',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _showWaterGoalPicker(
                          context, metrics.waterGoalMilliliters),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.tune_rounded,
                                size: 12, color: Color(0xFF0369A1)),
                            const SizedBox(width: 4),
                            Text(
                              '${metrics.waterGoalMilliliters} ml',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0369A1),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // 6 / 8 vasos
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$glassesCount',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '/ $totalGlasses vasos',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // 1500 ml de 2000 ml
                Text(
                  '${metrics.waterMilliliters} ml de ${metrics.waterGoalMilliliters} ml',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 14),

                // Botones - y + en Azul Gradiente
                Row(
                  children: [
                    // Botón [-] (fondo azul tenue con icono oscuro)
                    Material(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          HealthModuleHelper.removeWater(250);
                        },
                        child: const SizedBox(
                          width: 44,
                          height: 44,
                          child: Icon(
                            Icons.remove,
                            color: Color(0xFF0756A4),
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Botón [+] (fondo azul gradiente con icono blanco)
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF0756A4), Color(0xFF0A3D78)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0756A4).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            HealthModuleHelper.addWater(250);
                          },
                          child: const Center(
                            child: Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 2. Tarjeta de Respiración (Azul gradiente profundo) ---
  Widget _buildBreathingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A8A), Color(0xFF1D4ED8)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Respiración',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.air_rounded, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Caja 4-4-4',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Círculo animado pulsante de respiración (Play también inicia la respiración)
          GestureDetector(
            onTap: _toggleBreathing,
            behavior: HitTestBehavior.opaque,
            child: AnimatedBuilder(
              animation: _breathingScale,
              builder: (context, child) {
                final scale = _isBreathingActive ? _breathingScale.value : 1.0;
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.35),
                          Colors.white.withValues(alpha: 0.08),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        _isBreathingActive ? Icons.spa_rounded : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),

          // Texto de la fase (Inhala / Sostén / Exhala)
          Text(
            _breathingPhase,
            style: const TextStyle(
              color: Color(0xFFBFDBFE),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),

          // Botón Stop / Iniciar (Estilo idéntico a img 3)
          SizedBox(
            width: 140,
            height: 40,
            child: ElevatedButton(
              onPressed: _toggleBreathing,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isBreathingActive
                    ? Colors.white.withValues(alpha: 0.22)
                    : Colors.white,
                foregroundColor:
                    _isBreathingActive ? Colors.white : const Color(0xFF1E3A8A),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: _isBreathingActive
                      ? const BorderSide(color: Colors.white, width: 1.2)
                      : BorderSide.none,
                ),
              ),
              child: Text(
                _isBreathingActive ? 'Detener' : 'Iniciar',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 3. Tarjeta de Pasos en la Semana (Azul Gradiente) ---
  Widget _buildWeeklyStepsCard(HealthMetrics metrics) {
    final weekly = metrics.weeklySteps;
    // Días de la semana: L, M, M, J, V, S, D
    const dayLabels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

    // Encontrar el valor más alto para escalar las barras (mínimo 10000 para escala adecuada)
    final maxSteps = weekly.isEmpty ? 10000 : math.max(10000, weekly.reduce(math.max));

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B2545).withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado: "Esta semana" y "Pasos" (sin "(k)")
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Esta semana',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                'Pasos',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Gráfico de 7 barras verticales redondeadas en Azul Gradiente
          SizedBox(
            height: 140,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (index) {
                final daySteps = index < weekly.length ? weekly[index] : 0;
                final isSelected = index == _selectedDayIndex;
                final fraction = maxSteps > 0
                    ? (daySteps / maxSteps).clamp(daySteps > 0 ? 0.16 : 0.08, 1.0)
                    : 0.08;

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedDayIndex = index);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Etiqueta flotante con la cantidad exacta de pasos (ej: "32 pasos", "0 pasos")
                      if (isSelected) ...[
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '$daySteps pasos',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0756A4),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                      ] else ...[
                        const SizedBox(height: 18),
                      ],

                      // Barra vertical redondeada (Pill) en Azul Gradiente
                      Container(
                        width: 26,
                        height: 90 * fraction,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: isSelected
                              ? const Color(0xFF0756A4)
                              : const Color(0xFFE2E8F0),
                          gradient: isSelected
                              ? const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Color(0xFF007BFF), Color(0xFF0756A4)],
                                )
                              : null,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF0756A4).withValues(alpha: 0.35),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Letra del día (L, M, M, J, V, S, D)
                      Text(
                        dayLabels[index],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected
                              ? const Color(0xFF0756A4)
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // --- 4. Métricas Rápidas de Hoy (Ritmo cardíaco y Sueño) ---
  Widget _buildDailySummaryCard(BuildContext context, HealthMetrics metrics) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B2545).withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Resumen de hoy',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              Icon(Icons.query_builder_rounded, color: Color(0xFF64748B), size: 18),
            ],
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              // Ritmo cardíaco
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.favorite, color: Color(0xFFEF4444), size: 16),
                          const SizedBox(width: 6),
                          const Text(
                            'Cardíaco',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const Spacer(),
                          ValueListenableBuilder<SmartwatchConnectionStatus>(
                            valueListenable: SmartwatchBleHelper.statusNotifier,
                            builder: (context, status, _) {
                              if (status == SmartwatchConnectionStatus.connected) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981)
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'En vivo',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF059669),
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ValueListenableBuilder<int?>(
                        valueListenable: SmartwatchBleHelper.liveBpmNotifier,
                        builder: (context, liveBpm, _) {
                          final bpm = liveBpm ?? metrics.heartRate;
                          return Text(
                            '$bpm bpm',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Sueño
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.nightlight_round,
                              color: Color(0xFF4338CA), size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Sueño',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${metrics.sleepHours.toStringAsFixed(1)}h (${metrics.sleepQuality})',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- 5. Configuración de Recordatorio Semanal Antiestrés y Respiración ---
  Widget _buildWeeklyBreathingReminderCard(HealthMetrics metrics) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B2545).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0756A4), Color(0xFF0A3D78)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.self_improvement_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Recordatorio semanal antiestrés',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Recibe una notificación push cada semana recordando hacer respiraciones guiadas y pausar el estrés.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: metrics.breathingWeeklyReminderEnabled,
            activeColor: const Color(0xFF0756A4),
            onChanged: (val) {
              HapticFeedback.selectionClick();
              HealthModuleHelper.setBreathingWeeklyReminder(val);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(val
                      ? 'Recordatorio semanal antiestrés activado.'
                      : 'Recordatorio semanal desactivado.'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- 6. Configuración de Recordatorios de Hidratación (Azul) ---
  Widget _buildReminderSettingsCard(HealthMetrics metrics) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B2545).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.notifications_active_outlined,
                      color: Color(0xFF0756A4), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Recordatorio de agua',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Switch.adaptive(
                value: metrics.waterReminderEnabled,
                activeColor: const Color(0xFF0756A4),
                onChanged: (val) {
                  HapticFeedback.selectionClick();
                  HealthModuleHelper.setWaterReminder(val);
                },
              ),
            ],
          ),
          if (metrics.waterReminderEnabled) ...[
            const SizedBox(height: 10),
            const Text(
              'Intervalo de recordatorio:',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [1, 2, 3, 4].map((hours) {
                final isSelected = metrics.waterReminderIntervalHours == hours;
                return ChoiceChip(
                  label: Text('Cada $hours h'),
                  selected: isSelected,
                  selectedColor: const Color(0xFF0756A4),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF334155),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 12,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      HapticFeedback.selectionClick();
                      HealthModuleHelper.setWaterReminder(true, hours);
                    }
                  },
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // --- Medidas Corporales & IMC (Altura, Peso e IMC con categoría y edición) ---
  Widget _buildBodyMetricsCard(BuildContext context, HealthMetrics metrics) {
    final height = metrics.heightCm;
    final weight = metrics.weightKg;
    final bmi = metrics.bmi;
    final category = metrics.bmiCategory;

    Color categoryColor;
    if (bmi == null || bmi <= 0) {
      categoryColor = const Color(0xFF94A3B8);
    } else if (bmi < 18.5) {
      categoryColor = const Color(0xFF3B82F6);
    } else if (bmi < 25.0) {
      categoryColor = const Color(0xFF10B981);
    } else if (bmi < 30.0) {
      categoryColor = const Color(0xFFF59E0B);
    } else {
      categoryColor = const Color(0xFFEF4444);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B2545).withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0756A4).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.accessibility_new_rounded,
                  color: Color(0xFF0756A4),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Medidas Corporales & IMC',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Visible para tu médico en consulta',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _openBodyMetricsSheet(context, metrics),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.edit_outlined, size: 14, color: Color(0xFF0756A4)),
                      SizedBox(width: 4),
                      Text(
                        'Modificar',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0756A4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.height_rounded, color: Color(0xFF0756A4), size: 20),
                      const SizedBox(height: 6),
                      const Text(
                        'Altura',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          height != null ? '${height.toStringAsFixed(0)} cm' : '--',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.monitor_weight_outlined, color: Color(0xFF0756A4), size: 20),
                      const SizedBox(height: 6),
                      const Text(
                        'Peso',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          weight != null ? '${weight.toStringAsFixed(1)} kg' : '--',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.speed_rounded, color: Color(0xFF0756A4), size: 20),
                      const SizedBox(height: 6),
                      const Text(
                        'IMC',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          bmi != null ? bmi.toStringAsFixed(1) : '--',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: categoryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: categoryColor.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(
                  bmi != null && bmi >= 18.5 && bmi < 25.0
                      ? Icons.check_circle_rounded
                      : Icons.info_outline_rounded,
                  color: categoryColor,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    bmi != null
                        ? 'Estado: $category (IMC ${bmi.toStringAsFixed(1)} kg/m²)'
                        : 'Ingresa tu altura y peso para calcular tu IMC',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: categoryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openBodyMetricsSheet(BuildContext context, HealthMetrics metrics) {
    final heightCtrl = TextEditingController(
      text: metrics.heightCm != null ? metrics.heightCm!.toStringAsFixed(0) : '',
    );
    final weightCtrl = TextEditingController(
      text: metrics.weightKg != null ? metrics.weightKg!.toStringAsFixed(1) : '',
    );

    double? liveHeight = metrics.heightCm;
    double? liveWeight = metrics.weightKg;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final liveBmi = HealthMetrics.calculateBMI(liveHeight, liveWeight);
            final liveCategory = HealthMetrics.getBMICategory(liveBmi);

            Color catColor = const Color(0xFF94A3B8);
            if (liveBmi != null && liveBmi > 0) {
              if (liveBmi < 18.5) catColor = const Color(0xFF3B82F6);
              else if (liveBmi < 25.0) catColor = const Color(0xFF10B981);
              else if (liveBmi < 30.0) catColor = const Color(0xFFF59E0B);
              else catColor = const Color(0xFFEF4444);
            }

            return Container(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 20,
                bottom: MediaQuery.of(bottomCtx).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Actualizar Altura y Peso',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(bottomCtx),
                        icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tu Índice de Masa Corporal (IMC) se calculará automáticamente y tus médicos podrán consultarlo en cada turno.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: heightCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    onChanged: (val) {
                      setModalState(() {
                        liveHeight = double.tryParse(val.trim());
                      });
                    },
                    decoration: InputDecoration(
                      labelText: 'Estatura / Altura',
                      hintText: 'Ej. 170',
                      suffixText: 'cm',
                      prefixIcon: const Icon(Icons.height_rounded, color: Color(0xFF0756A4)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: weightCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    onChanged: (val) {
                      setModalState(() {
                        liveWeight = double.tryParse(val.trim());
                      });
                    },
                    decoration: InputDecoration(
                      labelText: 'Peso corporal',
                      hintText: 'Ej. 70.5',
                      suffixText: 'kg',
                      prefixIcon: const Icon(Icons.monitor_weight_outlined, color: Color(0xFF0756A4)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: catColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: catColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'IMC CALCULADO',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF64748B),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              liveBmi != null ? '${liveBmi.toStringAsFixed(1)} kg/m²' : 'Completa ambos campos',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: catColor,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: catColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            liveCategory,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0756A4),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        final h = double.tryParse(heightCtrl.text.trim());
                        final w = double.tryParse(weightCtrl.text.trim());
                        if (h == null || h <= 40 || h > 260) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Por favor ingresa una estatura válida en centímetros (ej: 170).')),
                          );
                          return;
                        }
                        if (w == null || w <= 10 || w > 350) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Por favor ingresa un peso válido en kilogramos (ej: 70.5).')),
                          );
                          return;
                        }

                        HapticFeedback.mediumImpact();
                        await HealthModuleHelper.updateBodyMetrics(heightCm: h, weightKg: w);
                        if (context.mounted) {
                          Navigator.pop(bottomCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: Color(0xFF10B981),
                              content: Text('Medidas e IMC actualizados exitosamente.'),
                            ),
                          );
                        }
                      },
                      child: const Text(
                        'Guardar medidas',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

}

// --- CustomPainter del Vaso de Agua estilizado en Azul Gradiente ---
class _WaterGlassPainter extends CustomPainter {
  final double fillFraction;
  final double wavePhase;

  _WaterGlassPainter({required this.fillFraction, required this.wavePhase});

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // Forma del vaso (ligeramente más ancho arriba y esquinas inferiores redondeadas)
    final glassPath = Path();
    glassPath.moveTo(6, 4);
    glassPath.lineTo(width - 6, 4);
    glassPath.lineTo(width - 10, height - 14);
    glassPath.quadraticBezierTo(width - 11, height, width - 24, height);
    glassPath.lineTo(24, height);
    glassPath.quadraticBezierTo(11, height, 10, height - 14);
    glassPath.close();

    // Fondo del vaso (vacío con leve tinte translúcido azul)
    final bgPaint = Paint()
      ..color = const Color(0xFFF0F9FF)
      ..style = PaintingStyle.fill;
    canvas.drawPath(glassPath, bgPaint);

    // Si tiene agua, dibujamos el líquido recortado a la forma del vaso en azul gradiente
    if (fillFraction > 0.0) {
      canvas.save();
      canvas.clipPath(glassPath);

      final waterHeight = height * fillFraction;
      final waterTop = height - waterHeight;

      final waterPath = Path();
      waterPath.moveTo(0, height);
      waterPath.lineTo(0, waterTop);

      // Onda animada continua según wavePhase
      const waveAmp = 3.5;
      final w1 = waveAmp * math.sin(wavePhase);
      final w2 = waveAmp * math.cos(wavePhase + 1.2);
      final w3 = waveAmp * 0.7 * math.sin(wavePhase + 2.4);

      waterPath.quadraticBezierTo(
        width * 0.35,
        waterTop - w1,
        width * 0.65,
        waterTop + w2,
      );
      waterPath.quadraticBezierTo(
        width * 0.85,
        waterTop + w3,
        width,
        waterTop,
      );

      waterPath.lineTo(width, height);
      waterPath.close();

      final waterPaint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0284C7), Color(0xFF0056B3)],
        ).createShader(Rect.fromLTWH(0, waterTop, width, waterHeight));
      canvas.drawPath(waterPath, waterPaint);

      // Brillo translúcido en la pared del agua
      final sheenPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.22)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(14, waterTop + 6), Offset(14, height - 10), sheenPaint);

      canvas.restore();
    }

    // Borde exterior del vaso en azul celeste suave
    final glassBorderPaint = Paint()
      ..color = const Color(0xFF7DD3FC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawPath(glassPath, glassBorderPaint);
  }

  @override
  bool shouldRepaint(covariant _WaterGlassPainter oldDelegate) {
    return true;
  }
}
