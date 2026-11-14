import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Estados posibles de la mascota 3D Wobnimo
enum WobnimoState {
  idle,
  thinking,
  speaking,
  celebrating,
}

/// Mascota robot inteligente 3D interactiva para Salud Now.
/// Inspirada en Wobnimo (Volt the LED robot), con físicas de resortes,
/// reacciones altamente visibles de "Pensando" (ámbar, escaneo, inclinación)
/// y "Festejo" (verde neón, saltos alegres continuos, ojos felices, destellos).
class WobnimoRobotMascot extends StatefulWidget {
  final double size;
  final WobnimoState state;
  final VoidCallback? onTap;

  const WobnimoRobotMascot({
    super.key,
    this.size = 60,
    this.state = WobnimoState.idle,
    this.onTap,
  });

  @override
  State<WobnimoRobotMascot> createState() => _WobnimoRobotMascotState();
}

class _WobnimoRobotMascotState extends State<WobnimoRobotMascot>
    with TickerProviderStateMixin {
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  late AnimationController _celebrateBounceController;
  late Animation<double> _celebrateBounceAnimation;

  late AnimationController _thinkingScanController;

  @override
  void initState() {
    super.initState();

    // 1. Flotación física suave
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: -3.5, end: 3.5).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOutSine),
    );

    // 2. Parpadeo de ojos LED cada 3.2 segundos
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();

    _blinkAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 92),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.1)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 4,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.1, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 4,
      ),
    ]).animate(_blinkController);

    // 3. Pulso de energía continuo
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // 4. Salto alegre para festejo (continuo, rápido y enérgico)
    _celebrateBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );

    _celebrateBounceAnimation = Tween<double>(begin: 0.0, end: -14.0).animate(
      CurvedAnimation(
        parent: _celebrateBounceController,
        curve: Curves.easeOutCubic,
      ),
    );

    // 5. Escaneo / cálculo rápido cuando está pensando
    _thinkingScanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..repeat();

    _updateStateAnimations();
  }

  void _updateStateAnimations() {
    if (widget.state == WobnimoState.celebrating) {
      if (!_celebrateBounceController.isAnimating) {
        _celebrateBounceController.repeat(reverse: true);
      }
    } else {
      if (_celebrateBounceController.isAnimating) {
        _celebrateBounceController.stop();
        _celebrateBounceController.value = 0.0;
      }
    }
  }

  @override
  void didUpdateWidget(covariant WobnimoRobotMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state != oldWidget.state) {
      _updateStateAnimations();
    }
  }

  @override
  void dispose() {
    _floatController.dispose();
    _blinkController.dispose();
    _pulseController.dispose();
    _celebrateBounceController.dispose();
    _thinkingScanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double s = widget.size;

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _floatAnimation,
          _blinkAnimation,
          _pulseAnimation,
          _celebrateBounceAnimation,
          _thinkingScanController,
        ]),
        builder: (context, child) {
          // Desplazamiento e inclinación según el estado activo
          double tiltAngle = 0.0;
          double yOffset = _floatAnimation.value;

          if (widget.state == WobnimoState.thinking) {
            // Cabeza inclinada con curiosidad + balanceo de cálculo mental
            tiltAngle = -0.22 +
                (math.sin(_thinkingScanController.value * math.pi * 2) * 0.05);
            yOffset += -2.0;
          } else if (widget.state == WobnimoState.celebrating) {
            // Salto enérgico y balanceo de alegría festiva
            yOffset += _celebrateBounceAnimation.value;
            tiltAngle =
                math.sin(_celebrateBounceController.value * math.pi) * 0.16;
          } else {
            // Flotación normal
            tiltAngle = math.sin(_floatController.value * math.pi) * 0.05;
          }

          // Aura luminosa exterior reactiva según el estado
          List<BoxShadow>? auraShadow;
          if (widget.state == WobnimoState.celebrating) {
            auraShadow = [
              BoxShadow(
                color: const Color(0xFF10B981).withValues(alpha: 0.65),
                blurRadius: s * 0.45,
                spreadRadius: s * 0.12,
              ),
            ];
          } else if (widget.state == WobnimoState.thinking) {
            auraShadow = [
              BoxShadow(
                color: const Color(0xFFFFB703).withValues(alpha: 0.65),
                blurRadius: s * 0.40,
                spreadRadius: s * 0.10,
              ),
            ];
          }

          return Transform.translate(
            offset: Offset(0, yOffset),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0015)
                ..rotateZ(tiltAngle)
                ..rotateY(tiltAngle * 0.7),
              child: Container(
                width: s,
                height: s,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: auraShadow,
                ),
                child: CustomPaint(
                  painter: _WobnimoRobotPainter(
                    state: widget.state,
                    blink: _blinkAnimation.value,
                    pulse: _pulseAnimation.value,
                    scanProgress: _thinkingScanController.value,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Pintor custom con estética 3D del robot Volt (Wobnimo)
class _WobnimoRobotPainter extends CustomPainter {
  final WobnimoState state;
  final double blink;
  final double pulse;
  final double scanProgress;

  _WobnimoRobotPainter({
    required this.state,
    required this.blink,
    required this.pulse,
    required this.scanProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Offset center = Offset(w / 2, h / 2);

    // --- Destellos / Estrellas grandes de festejo ---
    if (state == WobnimoState.celebrating) {
      final Paint sparklePaint = Paint()
        ..color = const Color(0xFFFBBF24)
        ..style = PaintingStyle.fill;

      // Estrella 1 (arriba derecha grande)
      _drawSparkle(canvas, Offset(w * 0.90, h * 0.12), w * 0.16, sparklePaint);
      // Estrella 2 (arriba izquierda)
      _drawSparkle(canvas, Offset(w * 0.10, h * 0.16), w * 0.13, sparklePaint);
      // Estrella 3 (abajo derecha)
      _drawSparkle(canvas, Offset(w * 0.92, h * 0.82), w * 0.11, sparklePaint);
      // Estrella 4 (abajo izquierda)
      _drawSparkle(canvas, Offset(w * 0.08, h * 0.76), w * 0.10, sparklePaint);
    }

    // --- Puntos de pensamiento (...) cuando state == thinking ---
    if (state == WobnimoState.thinking) {
      final Paint dotPaint = Paint()
        ..color = const Color(0xFFFFB703)
        ..style = PaintingStyle.fill;

      final double dotRadius = w * 0.055;
      final double bounce1 = math.sin(scanProgress * math.pi * 2) * (w * 0.08);
      final double bounce2 = math.sin((scanProgress + 0.33) * math.pi * 2) * (w * 0.08);
      final double bounce3 = math.sin((scanProgress + 0.66) * math.pi * 2) * (w * 0.08);

      canvas.drawCircle(Offset(w * 0.74, h * 0.14 + bounce1), dotRadius, dotPaint);
      canvas.drawCircle(Offset(w * 0.86, h * 0.08 + bounce2), dotRadius * 1.25, dotPaint);
      canvas.drawCircle(Offset(w * 0.98, h * 0.02 + bounce3), dotRadius * 1.5, dotPaint);
    }

    // Sombra 3D suave en la base
    final Paint shadowPaint = Paint()
      ..color = const Color(0xFF002868).withValues(alpha: 0.28)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.12);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, h * 0.94),
        width: w * 0.75,
        height: h * 0.16,
      ),
      shadowPaint,
    );

    // --- 1. Antena 3D superior con esfera luminosa ---
    final double stemTop = h * 0.12;
    final double stemBottom = h * 0.24;
    final Paint stemPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFB0C4DE), Color(0xFF5A738E)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(w * 0.47, stemTop, w * 0.06, stemBottom - stemTop))
      ..strokeWidth = w * 0.05
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(center.dx, stemBottom),
      Offset(center.dx, stemTop),
      stemPaint,
    );

    // Esfera luminosa de la antena (pulsante)
    Color glowColor;
    if (state == WobnimoState.thinking) {
      glowColor = const Color(0xFFFFB703); // Amarillo/Ámbar pensando
    } else if (state == WobnimoState.celebrating) {
      glowColor = const Color(0xFF10B981); // Verde esmeralda fiesta
    } else {
      glowColor = const Color(0xFF00E5FF); // Cian eléctrico Volt
    }

    final double antennaPulse = (state == WobnimoState.thinking)
        ? (0.7 + 0.3 * math.sin(scanProgress * math.pi * 4).abs())
        : (state == WobnimoState.celebrating)
            ? 1.15
            : pulse;

    final Paint antennaGlow = Paint()
      ..color = glowColor.withValues(alpha: 0.75 * antennaPulse)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.10);
    canvas.drawCircle(Offset(center.dx, stemTop), w * 0.13 * antennaPulse, antennaGlow);

    final Paint antennaBall = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white, glowColor],
        center: const Alignment(-0.3, -0.3),
        radius: 0.8,
      ).createShader(Rect.fromCircle(center: Offset(center.dx, stemTop), radius: w * 0.08));
    canvas.drawCircle(Offset(center.dx, stemTop), w * 0.075, antennaBall);

    // --- 2. Cabeza metálica 3D redondeada ---
    final Rect headRect = Rect.fromCenter(
      center: Offset(center.dx, h * 0.56),
      width: w * 0.78,
      height: h * 0.64,
    );
    final RRect headRRect = RRect.fromRectAndRadius(
      headRect,
      Radius.circular(w * 0.28),
    );

    // Gradiente metálico con relieve
    final Paint headPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFFFFF),
          Color(0xFFE2E8F0),
          Color(0xFFCBD5E1),
          Color(0xFF94A3B8),
        ],
        stops: [0.0, 0.3, 0.7, 1.0],
      ).createShader(headRect);
    canvas.drawRRect(headRRect, headPaint);

    // Borde brillante superior (iluminación de estudio)
    final Paint highlightBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.02
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.9),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(headRect);
    canvas.drawRRect(headRRect, highlightBorder);

    // --- 3. Visera LED negra brillante ---
    final Rect visorRect = Rect.fromCenter(
      center: Offset(center.dx, h * 0.55),
      width: w * 0.64,
      height: h * 0.42,
    );
    final RRect visorRRect = RRect.fromRectAndRadius(
      visorRect,
      Radius.circular(w * 0.20),
    );

    final Paint visorPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF0F172A),
          Color(0xFF020617),
        ],
      ).createShader(visorRect);
    canvas.drawRRect(visorRRect, visorPaint);

    // Barra de escaneo / cálculo cuando está pensando
    if (state == WobnimoState.thinking) {
      final double scanY = visorRect.top + (visorRect.height * scanProgress);
      final Paint scanLine = Paint()
        ..color = const Color(0xFFFFB703).withValues(alpha: 0.45)
        ..strokeWidth = w * 0.05
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.03);
      canvas.drawLine(
        Offset(visorRect.left + w * 0.04, scanY),
        Offset(visorRect.right - w * 0.04, scanY),
        scanLine,
      );
    }

    // Reflejo curvo de cristal sobre la visera
    final Paint glassReflect = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.22),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.55],
      ).createShader(visorRect);
    canvas.drawRRect(visorRRect, glassReflect);

    // --- 4. Ojos LED expresivos (Volt) ---
    final double eyeRadius = w * 0.09;
    final double eyeY = h * 0.52;
    final double leftEyeX = center.dx - w * 0.17;
    final double rightEyeX = center.dx + w * 0.17;

    final Color eyeColor = (state == WobnimoState.celebrating)
        ? const Color(0xFF10B981) // Verde esmeralda intenso
        : (state == WobnimoState.thinking)
            ? const Color(0xFFFFB703) // Ámbar analítico
            : const Color(0xFF38BDF8); // Azul cian LED

    if (state == WobnimoState.celebrating) {
      // Ojos felices en arco curvo (^  ^) llamativos para festejo
      final Paint happyGlow = Paint()
        ..color = const Color(0xFF10B981).withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.08
        ..strokeCap = StrokeCap.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.06);

      final Paint happyEyePaint = Paint()
        ..color = const Color(0xFF10B981)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.055
        ..strokeCap = StrokeCap.round;

      for (final double eyeX in [leftEyeX, rightEyeX]) {
        final Path happyPath = Path();
        happyPath.moveTo(eyeX - eyeRadius * 0.95, eyeY + eyeRadius * 0.35);
        happyPath.quadraticBezierTo(eyeX, eyeY - eyeRadius * 1.1, eyeX + eyeRadius * 0.95, eyeY + eyeRadius * 0.35);
        canvas.drawPath(happyPath, happyGlow);
        canvas.drawPath(happyPath, happyEyePaint);
      }
    } else {
      // Ojos circulares normales o pensando con parpadeo
      final Paint eyeGlowPaint = Paint()
        ..color = eyeColor.withValues(alpha: 0.7 * pulse)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.05);

      final double effectiveBlink =
          (state == WobnimoState.thinking) ? 0.65 : blink;

      for (final double eyeX in [leftEyeX, rightEyeX]) {
        final Rect eyeRect = Rect.fromCenter(
          center: Offset(eyeX, eyeY),
          width: eyeRadius * 2,
          height: (eyeRadius * 2 * effectiveBlink).clamp(2.0, eyeRadius * 2),
        );

        canvas.drawOval(eyeRect, eyeGlowPaint);

        final Paint eyeCore = Paint()
          ..shader = RadialGradient(
            colors: [Colors.white, eyeColor],
            center: const Alignment(-0.2, -0.2),
            radius: 0.7,
          ).createShader(eyeRect);
        canvas.drawOval(eyeRect, eyeCore);
      }
    }

    // --- 5. Boca LED / Sonrisa según estado ---
    final Paint mouthPaint = Paint()
      ..color = eyeColor.withValues(alpha: 0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.04
      ..strokeCap = StrokeCap.round;

    final Path mouthPath = Path();
    if (state == WobnimoState.celebrating) {
      // Gran sonrisa abierta y alegre festiva
      mouthPath.moveTo(center.dx - w * 0.16, h * 0.63);
      mouthPath.quadraticBezierTo(center.dx, h * 0.76, center.dx + w * 0.16, h * 0.63);
      canvas.drawPath(mouthPath, mouthPaint);
    } else if (state == WobnimoState.speaking) {
      // Onda de voz
      mouthPath.moveTo(center.dx - w * 0.10, h * 0.66);
      mouthPath.lineTo(center.dx - w * 0.04, h * 0.66 - (pulse * 3.5));
      mouthPath.lineTo(center.dx, h * 0.66 + (pulse * 3.5));
      mouthPath.lineTo(center.dx + w * 0.04, h * 0.66 - (pulse * 3.5));
      mouthPath.lineTo(center.dx + w * 0.10, h * 0.66);
      canvas.drawPath(mouthPath, mouthPaint);
    } else if (state == WobnimoState.thinking) {
      // Pequeña boca curiosa redondeada
      final Paint oMouth = Paint()
        ..color = eyeColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(center.dx, h * 0.66), w * 0.045, oMouth);
    } else {
      // Sonrisa amable habitual de Click
      mouthPath.moveTo(center.dx - w * 0.09, h * 0.66);
      mouthPath.quadraticBezierTo(center.dx, h * 0.71, center.dx + w * 0.09, h * 0.66);
      canvas.drawPath(mouthPath, mouthPaint);
    }

    // --- 6. Auriculares laterales metálicos ---
    final Paint earPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF94A3B8), Color(0xFF475569)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    // Oreja izquierda
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(center.dx - w * 0.39, h * 0.55),
          width: w * 0.06,
          height: h * 0.20,
        ),
        Radius.circular(w * 0.03),
      ),
      earPaint,
    );
    // Oreja derecha
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(center.dx + w * 0.39, h * 0.55),
          width: w * 0.06,
          height: h * 0.20,
        ),
        Radius.circular(w * 0.03),
      ),
      earPaint,
    );
  }

  void _drawSparkle(Canvas canvas, Offset pos, double size, Paint paint) {
    final Path p = Path();
    p.moveTo(pos.dx, pos.dy - size);
    p.quadraticBezierTo(pos.dx, pos.dy, pos.dx + size, pos.dy);
    p.quadraticBezierTo(pos.dx, pos.dy, pos.dx, pos.dy + size);
    p.quadraticBezierTo(pos.dx, pos.dy, pos.dx - size, pos.dy);
    p.quadraticBezierTo(pos.dx, pos.dy, pos.dx, pos.dy - size);
    canvas.drawPath(p, paint);
  }

  @override
  bool shouldRepaint(covariant _WobnimoRobotPainter oldDelegate) {
    return oldDelegate.state != state ||
        oldDelegate.blink != blink ||
        oldDelegate.pulse != pulse ||
        oldDelegate.scanProgress != scanProgress;
  }
}
