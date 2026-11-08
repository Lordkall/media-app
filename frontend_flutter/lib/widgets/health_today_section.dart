import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/health_module_helper.dart';
import '../core/smartwatch_ble_helper.dart';

class HealthTodaySection extends StatelessWidget {
  const HealthTodaySection({super.key});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return const SizedBox.shrink();

    return ValueListenableBuilder<bool>(
      valueListenable: HealthModuleHelper.isEnabledNotifier,
      builder: (context, isEnabled, _) {
        if (!isEnabled) return const SizedBox.shrink();

        return ValueListenableBuilder<HealthMetrics>(
          valueListenable: HealthModuleHelper.metricsNotifier,
          builder: (context, metrics, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Encabezado principal
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tu salud hoy',
                      style: TextStyle(
                        color: Color(0xFF0B2545),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _openManualEntrySheet(context, metrics),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF0756A4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.edit_note_rounded, size: 18),
                      label: const Text(
                        'Registrar',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 3 Tarjetas de métricas: Cardíaco (Animado), Pasos y Sueño
                SizedBox(
                  height: 144,
                  child: Row(
                    children: [
                      // Card 1: Ritmo Cardíaco con onda ECG animada
                      Expanded(
                        child: _AnimatedHeartCard(
                          heartRate: metrics.heartRate,
                          onTap: () => _openManualEntrySheet(context, metrics),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Card 2: Pasos (Gráfico circular de dona)
                      Expanded(
                        child: _buildHealthCard(
                          context: context,
                          onTap: () => _openManualEntrySheet(context, metrics),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: const [
                                  Icon(Icons.directions_walk_rounded,
                                      color: Color(0xFF0756A4), size: 16),
                                  SizedBox(width: 4),
                                  Text(
                                    'Pasos',
                                    style: TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              Center(
                                child: SizedBox(
                                  width: 68,
                                  height: 68,
                                  child: CustomPaint(
                                    painter: _StepsDonutPainter(
                                      progress: (metrics.steps / 10000.0).clamp(0.0, 1.0),
                                      trackColor: const Color(0xFFE2E8F0),
                                      progressColor: const Color(0xFF0756A4),
                                    ),
                                    child: Center(
                                      child: Text(
                                        metrics.steps >= 1000
                                            ? '${(metrics.steps / 1000).toStringAsFixed(1)}k'
                                            : '${metrics.steps}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Card 3: Sueño (Horas + Calidad automática + barra de progreso)
                      Expanded(
                        child: _buildHealthCard(
                          context: context,
                          onTap: () => _openManualEntrySheet(context, metrics),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: const [
                                  Icon(Icons.nightlight_round,
                                      color: Color(0xFF4338CA), size: 15),
                                  SizedBox(width: 4),
                                  Text(
                                    'Sueño',
                                    style: TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${metrics.sleepHours.toStringAsFixed(1)}h',
                                    style: const TextStyle(
                                      fontSize: 23,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                      height: 1.1,
                                    ),
                                  ),
                                  Text(
                                    metrics.sleepQuality,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _qualityColor(metrics.sleepQuality),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  width: double.infinity,
                                  height: 6,
                                  color: const Color(0xFFE2E8F0),
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor:
                                        (metrics.sleepHours / 9.0).clamp(0.08, 1.0),
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [Color(0xFF312E81), Color(0xFF4338CA)],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static Color _qualityColor(String quality) {
    switch (quality) {
      case 'Excelente':
        return const Color(0xFF059669);
      case 'Bueno':
        return const Color(0xFF10B981);
      case 'Regular':
        return const Color(0xFFD97706);
      default:
        return const Color(0xFFDC2626);
    }
  }

  static Widget _buildHealthCard({
    required BuildContext context,
    required Widget child,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B2545).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: child,
          ),
        ),
      ),
    );
  }

  // --- Contador de Agua ---
  Widget _buildWaterTrackerCard(BuildContext context, HealthMetrics metrics) {
    final progress =
        (metrics.waterMilliliters / metrics.waterGoalMilliliters).clamp(0.0, 1.0);
    final glassesCount = (metrics.waterMilliliters / 250).toInt();
    final totalGlasses = (metrics.waterGoalMilliliters / 250).toInt();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0F2FE)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.water_drop_rounded,
                        color: Color(0xFF0284C7), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Hidratación de hoy',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0B2545),
                        ),
                      ),
                      Text(
                        '$glassesCount de $totalGlasses vasos (250 ml c/u)',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Text(
                '${metrics.waterMilliliters} / ${metrics.waterGoalMilliliters} ml',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0284C7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Barra de progreso de agua
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 10,
              width: double.infinity,
              color: const Color(0xFFE2E8F0),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0284C7), Color(0xFF38BDF8)],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Botones de acción rápida: -250 ml y +250 ml
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: metrics.waterMilliliters > 0
                    ? () => HealthModuleHelper.removeWater(250)
                    : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                ),
                icon: const Icon(Icons.remove, size: 16),
                label: const Text('-250 ml', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    HealthModuleHelper.addWater(250);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    minimumSize: Size.zero,
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('+250 ml (1 vaso)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Tarjeta de Respiración Guiada ---
  Widget _buildBreathingExerciseCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF0FDF4), Color(0xFFE0F2FE)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFCFFAFE)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D9488).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.air_rounded, color: Color(0xFF0D9488), size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Respiración Guiada',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0B2545),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Inhala, mantén y exhala para calmar tu mente y ritmo cardíaco (4-4-4).',
                  style: TextStyle(fontSize: 11, color: Color(0xFF475569)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: ElevatedButton(
              onPressed: () => _openBreathingDialog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                minimumSize: Size.zero,
              ),
              child: const Text('Iniciar',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // --- Diálogo interactivo de Respiración Guiada ---
  static void _openBreathingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _GuidedBreathingModal(),
    );
  }

  // --- Modal de Registro Manual con Calidad de Sueño Automática ---
  static void _openManualEntrySheet(BuildContext context, HealthMetrics current) {
    final heartController = TextEditingController(text: '${current.heartRate}');
    final sleepController = TextEditingController(text: '${current.sleepHours}');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final bottomInset = MediaQuery.of(context).viewInsets.bottom;
          final sleepVal = double.tryParse(
                  sleepController.text.trim().replaceAll(',', '.')) ??
              current.sleepHours;
          final calculatedQuality =
              HealthMetrics.calculateSleepQuality(sleepVal);

          return Padding(
            padding: EdgeInsets.fromLTRB(22, 20, 22, 22 + bottomInset),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Métricas de Salud',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0B2545),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Smartwatch detection banner & Ritmo cardíaco
                  ValueListenableBuilder<SmartwatchConnectionStatus>(
                    valueListenable: SmartwatchBleHelper.statusNotifier,
                    builder: (context, status, _) {
                      final isConnected =
                          status == SmartwatchConnectionStatus.connected;
                      final watchName =
                          SmartwatchBleHelper.connectedDeviceNameNotifier.value ??
                              'Smartwatch';

                      return ValueListenableBuilder<int?>(
                        valueListenable: SmartwatchBleHelper.liveBpmNotifier,
                        builder: (context, liveBpm, _) {
                          final effectiveBpm = liveBpm ?? current.heartRate;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isConnected
                                      ? const Color(0xFFDCFCE7)
                                      : const Color(0xFFE0F2FE),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isConnected
                                        ? const Color(0xFF86EFAC)
                                        : const Color(0xFFBAE6FD),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.watch_rounded,
                                      color: isConnected
                                          ? const Color(0xFF16A34A)
                                          : const Color(0xFF0284C7),
                                      size: 24,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isConnected
                                                ? 'Smartwatch conectado: $watchName'
                                                : 'Smartwatch no detectado',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                              color: isConnected
                                                  ? const Color(0xFF15803D)
                                                  : const Color(0xFF0369A1),
                                            ),
                                          ),
                                          const SizedBox(height: 1),
                                          Text(
                                            isConnected
                                                ? 'Telemetría de pulso en vivo. Pasos contados con sensor nativo del móvil.'
                                                : 'Pasos contados por sensor nativo del móvil. Registro manual disponible.',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isConnected
                                                  ? const Color(0xFF166534)
                                                  : const Color(0xFF075985),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              if (isConnected) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                        color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEF4444)
                                              .withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.favorite_rounded,
                                          color: Color(0xFFEF4444),
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Ritmo Cardíaco (bpm)',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '$effectiveBpm bpm (Sincronizado desde $watchName)',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF15803D),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.lock_outline_rounded,
                                          color: Color(0xFF94A3B8), size: 20),
                                    ],
                                  ),
                                ),
                              ] else ...[
                                _buildInputRow(
                                  label: 'Ritmo Cardíaco (bpm)',
                                  icon: Icons.favorite,
                                  iconColor: const Color(0xFFEF4444),
                                  controller: heartController,
                                  keyboardType: TextInputType.number,
                                  hint: 'Ej. 72',
                                  onChanged: (_) {},
                                ),
                              ],
                            ],
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 14),

                  // Pasos (Medición nativa automática por el móvil)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0756A4).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.directions_walk_rounded,
                              color: Color(0xFF0756A4), size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Pasos caminados hoy',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF334155),
                                ),
                              ),
                              Text(
                                '${current.steps} pasos (contados automáticamente por el sensor móvil)',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.lock_outline_rounded,
                            color: Color(0xFF94A3B8), size: 18),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Horas de Sueño
                  _buildInputRow(
                    label: 'Horas de sueño',
                    icon: Icons.nightlight_round,
                    iconColor: const Color(0xFF4338CA),
                    controller: sleepController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    hint: 'Ej. 7.3',
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  const SizedBox(height: 14),

                  // Calidad de sueño calculada AUTOMÁTICAMENTE
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Calidad del sueño:',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF334155),
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Calculada automáticamente según tus horas',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _qualityColor(calculatedQuality).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _qualityColor(calculatedQuality).withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            calculatedQuality,
                            style: TextStyle(
                              color: _qualityColor(calculatedQuality),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Botón Guardar Métricas
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF0756A4), Color(0xFF0A3D78)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0756A4).withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () async {
                          final hr = int.tryParse(heartController.text.trim()) ??
                              current.heartRate;
                          final sl = double.tryParse(sleepController.text
                                  .trim()
                                  .replaceAll(',', '.')) ??
                              current.sleepHours;

                          await HealthModuleHelper.updateMetrics(
                            heartRate: hr,
                            sleepHours: sl,
                          );

                          if (sheetContext.mounted) {
                            Navigator.pop(sheetContext);
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Métricas de salud actualizadas exitosamente.'),
                              ),
                            );
                          }
                        },
                        child: const Text(
                          'Guardar métricas',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static Widget _buildInputRow({
    required String label,
    required IconData icon,
    required Color iconColor,
    required TextEditingController controller,
    required TextInputType keyboardType,
    required String hint,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: iconColor, size: 20),
            hintText: hint,
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF0756A4), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

// --- Tarjeta de Ritmo Cardíaco con Onda ECG Animada ---
class _AnimatedHeartCard extends StatefulWidget {
  final int heartRate;
  final VoidCallback onTap;

  const _AnimatedHeartCard({
    required this.heartRate,
    required this.onTap,
  });

  @override
  State<_AnimatedHeartCard> createState() => _AnimatedHeartCardState();
}

class _AnimatedHeartCardState extends State<_AnimatedHeartCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    SmartwatchBleHelper.liveBpmNotifier.addListener(_onBpmChanged);
    _onBpmChanged();
  }

  void _onBpmChanged() {
    final bpm = SmartwatchBleHelper.liveBpmNotifier.value;
    if (bpm != null && bpm >= 40 && bpm <= 220) {
      final ms = (60000 / bpm).round().clamp(300, 2000);
      _animController.duration = Duration(milliseconds: ms);
    } else {
      _animController.duration = const Duration(milliseconds: 1400);
    }
  }

  @override
  void dispose() {
    SmartwatchBleHelper.liveBpmNotifier.removeListener(_onBpmChanged);
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int?>(
      valueListenable: SmartwatchBleHelper.liveBpmNotifier,
      builder: (context, liveBpm, _) {
        final effectiveBpm = liveBpm ?? widget.heartRate;
        final isStreaming = liveBpm != null;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isStreaming
                  ? const Color(0xFF10B981).withValues(alpha: 0.35)
                  : const Color(0xFFF1F5F9),
              width: isStreaming ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isStreaming
                    ? const Color(0xFF10B981).withValues(alpha: 0.08)
                    : const Color(0xFF0B2545).withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: widget.onTap,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        AnimatedBuilder(
                          animation: _animController,
                          builder: (context, child) {
                            final beat =
                                math.sin(_animController.value * math.pi * 2);
                            final scale =
                                1.0 + (beat > 0.7 ? (beat - 0.7) * 0.4 : 0.0);
                            return Transform.scale(
                              scale: scale,
                              child: Icon(
                                Icons.favorite,
                                color: isStreaming
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFEF4444),
                                size: 15,
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Cardíaco',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (isStreaming) ...[
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                const Text(
                                  'En vivo',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$effectiveBpm',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: isStreaming
                                ? const Color(0xFF065F46)
                                : const Color(0xFF0F172A),
                            height: 1.1,
                          ),
                        ),
                        Text(
                          isStreaming ? 'bpm · Reloj' : 'bpm',
                          style: TextStyle(
                            fontSize: 11,
                            color: isStreaming
                                ? const Color(0xFF059669)
                                : const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(
                      width: double.infinity,
                      height: 26,
                      child: AnimatedBuilder(
                        animation: _animController,
                        builder: (context, _) {
                          return CustomPaint(
                            painter: _AnimatedEcgWavePainter(
                              progress: _animController.value,
                              color: isStreaming
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFEF4444),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// --- Pintor animado de Onda ECG ---
class _AnimatedEcgWavePainter extends CustomPainter {
  final double progress;
  final Color color;

  const _AnimatedEcgWavePainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final mid = h * 0.58;

    // Línea base suave
    final basePaint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(0, mid);
    path.lineTo(w * 0.20, mid);
    path.quadraticBezierTo(w * 0.26, mid - h * 0.18, w * 0.32, mid);
    path.lineTo(w * 0.38, mid);
    path.lineTo(w * 0.42, mid + h * 0.14);
    path.lineTo(w * 0.48, mid - h * 0.62);
    path.lineTo(w * 0.54, mid + h * 0.32);
    path.lineTo(w * 0.58, mid);
    path.quadraticBezierTo(w * 0.68, mid - h * 0.22, w * 0.78, mid);
    path.lineTo(w, mid);

    canvas.drawPath(path, basePaint);

    // Onda activa iluminada que barre suavemente
    final activePaint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Calcular posición del pulso activo (0.0 a 1.0)
    final sweepCenter = progress * w;
    const sweepWidth = 32.0;

    canvas.save();
    canvas.clipRect(Rect.fromLTRB(
      math.max(0, sweepCenter - sweepWidth),
      0,
      math.min(w, sweepCenter + sweepWidth),
      h,
    ));
    canvas.drawPath(path, activePaint);
    canvas.restore();

    // Punto brillante en el cabezal de barrido
    final dotX = sweepCenter;
    final dotY = _getYOnPath(dotX / w, h, mid);
    final dotPaint = Paint()..color = color;
    canvas.drawCircle(Offset(dotX, dotY), 2.2, dotPaint);

    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(Offset(dotX, dotY), 4.5, glowPaint);
  }

  double _getYOnPath(double factor, double h, double mid) {
    if (factor >= 0.42 && factor <= 0.48) {
      final t = (factor - 0.42) / 0.06;
      return mid + h * (0.14 - t * 0.76);
    } else if (factor > 0.48 && factor <= 0.54) {
      final t = (factor - 0.48) / 0.06;
      return mid - h * 0.62 + t * h * 0.94;
    }
    return mid;
  }

  @override
  bool shouldRepaint(covariant _AnimatedEcgWavePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// --- Pintor de Dona de Pasos ---
class _StepsDonutPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;

  const _StepsDonutPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 9) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = 6.5
      ..style = PaintingStyle.stroke;

    final progressPaint = Paint()
      ..color = progressColor
      ..strokeWidth = 6.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, radius, trackPaint);

    final sweepAngle = (progress.clamp(0.0, 1.0)) * 2 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _StepsDonutPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.progressColor != progressColor;
}

// --- Diálogo de Ejercicio de Respiración Guiada ---
class _GuidedBreathingModal extends StatefulWidget {
  const _GuidedBreathingModal();

  @override
  State<_GuidedBreathingModal> createState() => _GuidedBreathingModalState();
}

class _GuidedBreathingModalState extends State<_GuidedBreathingModal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breatheController;
  Timer? _phaseTimer;
  String _currentPhase = 'Inhala';
  int _secondsRemaining = 4;
  int _completedCycles = 0;

  @override
  void initState() {
    super.initState();
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _startBreathingLoop();
  }

  void _startBreathingLoop() async {
    while (mounted) {
      // 1. Inhala (4s)
      if (!mounted) break;
      setState(() {
        _currentPhase = 'Inhala profundamente';
        _secondsRemaining = 4;
      });
      HapticFeedback.lightImpact();
      _breatheController.animateTo(1.0, curve: Curves.easeInOutSine);
      for (int i = 4; i > 0; i--) {
        if (!mounted) return;
        setState(() => _secondsRemaining = i);
        await Future.delayed(const Duration(seconds: 1));
      }

      // 2. Mantén (4s)
      if (!mounted) break;
      setState(() {
        _currentPhase = 'Mantén el aire';
        _secondsRemaining = 4;
      });
      HapticFeedback.selectionClick();
      for (int i = 4; i > 0; i--) {
        if (!mounted) return;
        setState(() => _secondsRemaining = i);
        await Future.delayed(const Duration(seconds: 1));
      }

      // 3. Exhala (4s)
      if (!mounted) break;
      setState(() {
        _currentPhase = 'Exhala lentamente';
        _secondsRemaining = 4;
      });
      HapticFeedback.mediumImpact();
      _breatheController.animateTo(0.0, curve: Curves.easeInOutSine);
      for (int i = 4; i > 0; i--) {
        if (!mounted) return;
        setState(() => _secondsRemaining = i);
        await Future.delayed(const Duration(seconds: 1));
      }

      if (mounted) {
        setState(() => _completedCycles++);
      }
    }
  }

  @override
  void dispose() {
    _phaseTimer?.cancel();
    _breatheController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Respiración Guiada 4-4-4',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0B2545),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Ciclos completados: $_completedCycles',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0D9488),
              ),
            ),
            const SizedBox(height: 30),

            // Círculo animado de respiración
            SizedBox(
              height: 180,
              width: 180,
              child: AnimatedBuilder(
                animation: _breatheController,
                builder: (context, _) {
                  final scale = 0.5 + (_breatheController.value * 0.5);
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // Aura exterior
                      Container(
                        width: 180 * scale,
                        height: 180 * scale,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                        ),
                      ),
                      // Círculo principal
                      Container(
                        width: 130 * scale,
                        height: 130 * scale,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF0D9488), Color(0xFF38BDF8)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0D9488).withValues(alpha: 0.35),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            '$_secondsRemaining',
                            style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 28),
            Text(
              _currentPhase,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0B2545),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Respira al ritmo del círculo para relajar tu sistema nervioso.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 24),

            // Botón Terminar
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0756A4),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Finalizar sesión',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
