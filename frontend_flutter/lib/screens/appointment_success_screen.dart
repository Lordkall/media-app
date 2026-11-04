import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../widgets/profile_avatar.dart';

enum AppointmentSuccessAction { viewSchedule, home }

class AppointmentSuccessScreen extends StatefulWidget {
  const AppointmentSuccessScreen({
    super.key,
    required this.doctor,
    required this.appointment,
  });

  final Map<String, dynamic> doctor;
  final Map<String, dynamic> appointment;

  @override
  State<AppointmentSuccessScreen> createState() =>
      _AppointmentSuccessScreenState();
}

class _AppointmentSuccessScreenState extends State<AppointmentSuccessScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _doctorName =>
      widget.appointment['doctor_name']?.toString() ??
      widget.doctor['name']?.toString() ??
      'Dr. ${widget.doctor['first_name'] ?? ''} ${widget.doctor['last_name'] ?? ''}'
          .trim();

  String get _specialty {
    final appointmentSpecialty =
        widget.appointment['doctor_specialty']?.toString();
    if (appointmentSpecialty != null && appointmentSpecialty.isNotEmpty) {
      return appointmentSpecialty;
    }
    final specialties = widget.doctor['specialties'] as List?;
    return specialties != null && specialties.isNotEmpty
        ? specialties.first.toString()
        : 'Especialista';
  }

  DateTime? get _appointmentDate =>
      DateTime.tryParse(widget.appointment['date']?.toString() ?? '');

  String get _dateLabel {
    final date = _appointmentDate;
    if (date == null) return 'Fecha por confirmar';
    const weekdays = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
    const months = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    return '${weekdays[date.weekday - 1]}, ${date.day} ${months[date.month - 1]}';
  }

  String get _timeLabel {
    final raw = widget.appointment['time_block']?.toString();
    if (raw == null || raw.trim().isEmpty) return 'Hora por confirmar';
    return raw.replaceAll('AM', 'a. m.').replaceAll('PM', 'p. m.');
  }

  @override
  Widget build(BuildContext context) {
    final rawAvatar = widget.appointment['doctor_avatar']?.toString() ??
        widget.doctor['avatar_url']?.toString();
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFE0EAFC),
                    Color(0xFFCFDEF3),
                    Color(0xFFB3C6DF),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => CustomPaint(
                painter: _ConfettiPainter(progress: _controller.value),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 220,
                          height: 220,
                          child: AnimatedBuilder(
                            animation: _controller,
                            builder: (context, _) {
                              final checkProgress =
                                  Curves.easeOutCubic.transform(
                                ((_controller.value - 0.18) / 0.35)
                                    .clamp(0.0, 1.0)
                                    .toDouble(),
                              );
                              return Stack(
                                alignment: Alignment.center,
                                children: [
                                  CustomPaint(
                                    size: const Size.square(220),
                                    painter: _SuccessRingsPainter(
                                      progress: _controller.value,
                                    ),
                                  ),
                                  Container(
                                    width: 122,
                                    height: 122,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0056B3),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF0056B3)
                                              .withOpacity(0.25),
                                          blurRadius: 26,
                                          spreadRadius: 3,
                                        ),
                                      ],
                                    ),
                                    child: CustomPaint(
                                      painter: _CheckmarkPainter(
                                          progress: checkProgress),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          '¡Cita agendada!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF17212B),
                            fontSize: 25,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Te enviaremos un recordatorio antes de la consulta.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF52647A),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _appointmentCard(rawAvatar),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: FilledButton(
                            onPressed: () => Navigator.pop(
                              context,
                              AppointmentSuccessAction.viewSchedule,
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF0056B3),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: const Text(
                              'Ver mi agenda',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: TextButton(
                            onPressed: () => Navigator.pop(
                              context,
                              AppointmentSuccessAction.home,
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF0B2545),
                              backgroundColor: const Color(0xFFE0EAFC),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: const Text(
                              'Volver al inicio',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _appointmentCard(String? avatarUrl) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE0EAFC),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          ProfileAvatar(
            imageUrl: avatarUrl,
            size: 56,
            fallbackRole: 'doctor',
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _doctorName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF17212B),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _specialty,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF68736F),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    _detail(Icons.calendar_month_outlined, _dateLabel),
                    _detail(Icons.access_time, _timeLabel),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detail(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: const Color(0xFF0056B3)),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF334155),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

}

class _CheckmarkPainter extends CustomPainter {
  const _CheckmarkPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.25, size.height * 0.52)
      ..lineTo(size.width * 0.44, size.height * 0.70)
      ..lineTo(size.width * 0.77, size.height * 0.34);
    final metrics = path.computeMetrics().first;
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(metrics.extractPath(0, metrics.length * progress), paint);
  }

  @override
  bool shouldRepaint(covariant _CheckmarkPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _SuccessRingsPainter extends CustomPainter {
  const _SuccessRingsPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    for (var i = 0; i < 2; i++) {
      final phase = (progress + (i * 0.24)).clamp(0.0, 1.0).toDouble();
      final radius = 68 + phase * 27;
      final opacity = (1 - phase) * 0.48;
      final paint = Paint()
        ..color = const Color(0xFF0056B3).withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SuccessRingsPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final fade = progress <= 0.7 ? 1.0 : (1 - progress) / 0.3;
    final origin = Offset(size.width / 2, size.height * 0.31);
    final random = math.Random(73);
    const colors = [
      Color(0xFF0056B3),
      Color(0xFF58A6FF),
      Color(0xFF8EC5FF),
      Color(0xFFFFFFFF),
      Color(0xFF0B3F78),
    ];

    for (var i = 0; i < 64; i++) {
      final angle = random.nextDouble() * math.pi * 2;
      final speed = 28 + random.nextDouble() * 130;
      final x = origin.dx + math.cos(angle) * speed * progress;
      final y = origin.dy +
          math.sin(angle) * speed * progress +
          112 * progress * progress;
      final width = 4 + random.nextDouble() * 4;
      final height = 3 + random.nextDouble() * 3;
      final paint = Paint()
        ..color = colors[i % colors.length].withOpacity(fade);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle + progress * 5);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: width, height: height),
          const Radius.circular(1.5),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
