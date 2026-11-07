import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'login_screen.dart';

/// Animated blue introduction shown before the app's sign-in screen.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _rippleController;
  late final AnimationController _introController;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..forward();

    _navigationTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      );
    });
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _rippleController.dispose();
    _introController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F4C81), Color(0xFF0A3158)],
          ),
        ),
        child: SizedBox.expand(
          child: AnimatedBuilder(
            animation: Listenable.merge([_rippleController, _introController]),
            builder: (context, _) {
              final reveal = Curves.easeOutCubic.transform(
                ((_introController.value - 0.56) / 0.16)
                    .clamp(0.0, 1.0)
                    .toDouble(),
              );
              final heartbeatReveal =
                  (_introController.value / 0.54).clamp(0.0, 1.0).toDouble();
              // The 4-second intro controller advances by 0.375 in 1.5 seconds.
              final loadingProgress =
                  (_introController.value - 0.56).clamp(0.0, 0.375).toDouble() /
                      0.375;
              return Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _SplashBackdropPainter(
                        progress: _rippleController.value,
                        heartbeatReveal: heartbeatReveal,
                      ),
                    ),
                  ),
                  Opacity(
                    opacity: reveal,
                    child: Transform.scale(
                      scale: 0.92 + (0.08 * reveal),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 280,
                            height: 280,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                for (var ring = 0; ring < 3; ring++)
                                  _RippleRing(
                                    controller: _rippleController,
                                    delay: ring / 3,
                                  ),
                                Container(
                                  width: 116,
                                  height: 116,
                                  padding: const EdgeInsets.all(15),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.22),
                                        blurRadius: 28,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: Image.asset(
                                    'assets/logo.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Salud Now',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tu Salud, a un Click!',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.78),
                              fontSize: 16,
                              letterSpacing: 0.25,
                            ),
                          ),
                          const SizedBox(height: 28),
                          SizedBox(
                            width: 190,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: loadingProgress,
                                minHeight: 4,
                                backgroundColor: Colors.white.withOpacity(0.22),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFFB9F4FF),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Cargando...',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.65),
                              fontSize: 12,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SplashBackdropPainter extends CustomPainter {
  const _SplashBackdropPainter({
    required this.progress,
    required this.heartbeatReveal,
  });

  final double progress;
  final double heartbeatReveal;

  static const _stars = <Offset>[
    Offset(0.09, 0.16),
    Offset(0.23, 0.30),
    Offset(0.81, 0.17),
    Offset(0.93, 0.35),
    Offset(0.14, 0.57),
    Offset(0.84, 0.59),
    Offset(0.27, 0.79),
    Offset(0.72, 0.83),
    Offset(0.52, 0.12),
    Offset(0.58, 0.91),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    _paintStars(canvas, size);
    _paintHeartbeat(canvas, size);
  }

  void _paintStars(Canvas canvas, Size size) {
    for (var i = 0; i < _stars.length; i++) {
      final star = _stars[i];
      final twinkle = (math.sin((progress * math.pi * 2) + i * 1.7) + 1) / 2;
      final center = Offset(star.dx * size.width, star.dy * size.height);
      final radius = 2 + twinkle * 3.2;
      final opacity = 0.18 + twinkle * 0.72;
      final glow = Paint()
        ..color = const Color(0xFFB9F4FF).withOpacity(opacity * 0.32)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 + twinkle * 5);
      final line = Paint()
        ..color = Colors.white.withOpacity(opacity)
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round;

      canvas.drawCircle(center, radius * 1.7, glow);
      canvas.drawLine(
        center.translate(-radius, 0),
        center.translate(radius, 0),
        line,
      );
      canvas.drawLine(
        center.translate(0, -radius),
        center.translate(0, radius),
        line,
      );
      canvas.drawCircle(center, 1.4 + twinkle,
          Paint()..color = Colors.white.withOpacity(opacity));
    }
  }

  void _paintHeartbeat(Canvas canvas, Size size) {
    // Keep the heartbeat behind the logo, matching the reference intro.
    final baseY = size.height * 0.42;
    final beatWidth = size.width * 0.42;
    final shift = progress * beatWidth;
    final path = Path();
    var first = true;
    for (var start = -beatWidth - shift;
        start < size.width + beatWidth;
        start += beatWidth) {
      final points = <Offset>[
        Offset(start, baseY),
        Offset(start + beatWidth * 0.36, baseY),
        Offset(start + beatWidth * 0.42, baseY - 5),
        Offset(start + beatWidth * 0.46, baseY + 4),
        Offset(start + beatWidth * 0.50, baseY),
        Offset(start + beatWidth * 0.55, baseY),
        Offset(start + beatWidth * 0.59, baseY - size.height * 0.095),
        Offset(start + beatWidth * 0.63, baseY + size.height * 0.055),
        Offset(start + beatWidth * 0.68, baseY - 9),
        Offset(start + beatWidth * 0.76, baseY),
        Offset(start + beatWidth, baseY),
      ];
      for (final point in points) {
        if (first) {
          path.moveTo(point.dx, point.dy);
          first = false;
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
    }

    final glowPaint = Paint()
      ..color = const Color(0xFF8DEEFF).withOpacity(0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.96)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.save();
    canvas.clipRect(
      Rect.fromLTRB(0, 0, size.width * heartbeatReveal, size.height),
    );
    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, linePaint);
    canvas.restore();

    // The bright tip follows the stroke while the ECG is being drawn.
    final dotX = size.width * heartbeatReveal;
    final phase = ((dotX + shift) % beatWidth) / beatWidth;
    final dotY = baseY + _heartbeatOffset(phase, size.height);
    if (heartbeatReveal < 1) {
      canvas.drawCircle(
        Offset(dotX, dotY),
        8,
        Paint()
          ..color = const Color(0xFF77E9FF).withOpacity(0.65)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
      );
      canvas.drawCircle(Offset(dotX, dotY), 3, Paint()..color = Colors.white);
    }
  }

  double _heartbeatOffset(double phase, double height) {
    if (phase >= 0.59 && phase < 0.63) return -height * 0.095;
    if (phase >= 0.63 && phase < 0.68) return height * 0.055;
    if (phase >= 0.42 && phase < 0.46) return -5;
    if (phase >= 0.46 && phase < 0.50) return 4;
    return 0;
  }

  @override
  bool shouldRepaint(covariant _SplashBackdropPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.heartbeatReveal != heartbeatReveal;
}

class _RippleRing extends StatelessWidget {
  const _RippleRing({required this.controller, required this.delay});

  final AnimationController controller;
  final double delay;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final progress = (controller.value + delay) % 1;
        final diameter = 122 + (150 * progress);
        final opacity = (1 - progress) * 0.30;
        return Container(
          width: diameter,
          height: diameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.lightBlueAccent.withOpacity(opacity),
              width: 2,
            ),
            color: Colors.white.withOpacity(opacity * 0.12),
          ),
        );
      },
    );
  }
}
