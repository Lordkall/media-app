import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/health_module_helper.dart';
import '../screens/health_tab.dart';

class HealthTodaySection extends StatelessWidget {
  const HealthTodaySection({super.key});

  static void _openHealthTab(BuildContext context) {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HealthTab()),
    );
  }

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
                      onPressed: () => _openHealthTab(context),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF0756A4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.arrow_forward_ios_rounded,
                          size: 13),
                      label: const Text(
                        'Ver módulo',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 3 Tarjetas de métricas: Pasos, Agua e IMC
                SizedBox(
                  height: 144,
                  child: Row(
                    children: [
                      // Card 1: Pasos (Gráfico circular de dona)
                      Expanded(
                        child: _buildHealthCard(
                          context: context,
                          onTap: () => _openHealthTab(context),
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
                                      progress: (metrics.steps /
                                              (metrics.stepGoal > 0
                                                  ? metrics.stepGoal
                                                  : 10000))
                                          .clamp(0.0, 1.0),
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
                              Center(
                                child: Text(
                                  'Meta: ${metrics.stepGoal >= 1000 ? "${(metrics.stepGoal / 1000).toStringAsFixed(metrics.stepGoal % 1000 == 0 ? 0 : 1)}k" : "${metrics.stepGoal}"}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF94A3B8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Card 2: Agua
                      Expanded(
                        child: _buildHealthCard(
                          context: context,
                          onTap: () => _openHealthTab(context),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: const [
                                  Icon(Icons.water_drop_rounded,
                                      color: Color(0xFF0284C7), size: 16),
                                  SizedBox(width: 4),
                                  Text(
                                    'Agua',
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
                                    '${(metrics.waterMilliliters / 250).toInt()} / ${(metrics.waterGoalMilliliters / 250).toInt()}',
                                    style: const TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                      height: 1.1,
                                    ),
                                  ),
                                  const Text(
                                    'vasos hoy',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w600,
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
                                    widthFactor: (metrics.waterMilliliters /
                                            metrics.waterGoalMilliliters)
                                        .clamp(0.0, 1.0),
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Color(0xFF0284C7),
                                            Color(0xFF38BDF8)
                                          ],
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
                      const SizedBox(width: 8),

                      // Card 3: IMC & Medidas
                      Expanded(
                        child: _buildHealthCard(
                          context: context,
                          onTap: () => _openHealthTab(context),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: const [
                                  Icon(Icons.monitor_weight_outlined,
                                      color: Color(0xFF10B981), size: 16),
                                  SizedBox(width: 4),
                                  Text(
                                    'IMC',
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
                                    metrics.bmi != null
                                        ? '${metrics.bmi}'
                                        : '--',
                                    style: const TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                      height: 1.1,
                                    ),
                                  ),
                                  Text(
                                    metrics.bmiCategory,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: _bmiCategoryColor(
                                          metrics.bmiCategory),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                (metrics.weightKg != null &&
                                        metrics.heightCm != null)
                                    ? '${metrics.weightKg!.toStringAsFixed(0)}kg • ${metrics.heightCm!.toStringAsFixed(0)}cm'
                                    : 'Sin registrar',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF94A3B8),
                                  fontWeight: FontWeight.w500,
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

  static Color _bmiCategoryColor(String category) {
    switch (category) {
      case 'Normal':
        return const Color(0xFF10B981);
      case 'Sobrepeso':
        return const Color(0xFFF59E0B);
      case 'Obesidad':
        return const Color(0xFFEF4444);
      case 'Bajo peso':
        return const Color(0xFF3B82F6);
      default:
        return const Color(0xFF94A3B8);
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
