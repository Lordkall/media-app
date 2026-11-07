import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/health_module_helper.dart';

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

  // Selected day index in weekly bar chart (default today = 3, Thu/9.0k like in image 3)
  int _selectedDayIndex = 3;

  @override
  void initState() {
    super.initState();

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
                            // 1. Tarjeta de Hidratación (Azul gradiente)
                            _buildHydrationCard(metrics),
                            const SizedBox(height: 18),

                            // 2. Tarjeta de Respiración (Azul gradiente)
                            _buildBreathingCard(),
                            const SizedBox(height: 18),

                            // 3. Tarjeta de Pasos en la Semana (Azul gradiente)
                            _buildWeeklyStepsCard(metrics),
                            const SizedBox(height: 18),

                            // 4. Métricas de hoy (Ritmo cardíaco y Sueño)
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
                const Text(
                  'Water',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 4),

                // 6 / 8 glasses
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
                      '/ $totalGlasses glasses',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // 1500 ml of 2000 ml
                Text(
                  '${metrics.waterMilliliters} ml of ${metrics.waterGoalMilliliters} ml',
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
                              size: 22,
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
                'Breathing',
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
                      '4-4-4 Box',
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
                _isBreathingActive ? 'Stop' : 'Iniciar',
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

    // Encontrar el valor más alto para escalar las barras (mínimo 10.0k)
    final maxSteps = math.max(10000, weekly.reduce(math.max));

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
          // Encabezado: "This week" y "Steps (k)"
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'This week',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                'Steps (k)',
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
                final fraction = (daySteps / maxSteps).clamp(0.12, 1.0);
                final kValue = (daySteps / 1000.0).toStringAsFixed(1);

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedDayIndex = index);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Etiqueta flotante con el valor (ej. 9.0) en Azul si está seleccionado
                      if (isSelected) ...[
                        Text(
                          kValue,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0756A4),
                          ),
                        ),
                        const SizedBox(height: 4),
                      ] else ...[
                        const SizedBox(height: 20),
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
                        children: const [
                          Icon(Icons.favorite, color: Color(0xFFEF4444), size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Cardíaco',
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
                        '${metrics.heartRate} bpm',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
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
