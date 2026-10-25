import 'package:flutter/material.dart';

import 'auth_helper.dart';
import '../screens/agendar_cita_tab.dart';
import '../screens/mi_disponibilidad_tab.dart';
import '../screens/mis_citas_tab.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class NotificationNavigation {
  NotificationNavigation._();

  static String? _pendingAction;

  static Future<void> open(String? action, {BuildContext? context}) async {
    final normalizedAction = action?.trim();
    if (normalizedAction == null || normalizedAction.isEmpty) return;
    final role = await AuthHelper.getRole();
    final navigator = context != null && context.mounted
        ? Navigator.of(context, rootNavigator: true)
        : appNavigatorKey.currentState;
    if (role == null || navigator == null) {
      _pendingAction = action;
      return;
    }

    if (normalizedAction == 'weekly_schedule') {
      if (role == 'doctor' || role == 'assistant') {
        navigator.push(MaterialPageRoute<void>(
          builder: (_) => const _NotificationDestination(
            title: 'Horario',
            child: MiDisponibilidadTab(),
          ),
        ));
      } else if (role == 'patient') {
        navigator.push(MaterialPageRoute<void>(
          builder: (_) => const _NotificationDestination(
            title: 'Agendar cita',
            child: AgendarCitaTab(),
          ),
        ));
      }
      return;
    }

    final match = RegExp(r'appointment[:/](\d+)', caseSensitive: false)
        .firstMatch(normalizedAction);
    if (match == null) return;
    final appointmentId = int.tryParse(match.group(1)!);
    if (appointmentId == null) return;
    navigator.push(MaterialPageRoute<void>(
      builder: (_) => _NotificationDestination(
        title: 'Cita médica',
        child: MisCitasTab(initialAppointmentId: appointmentId),
      ),
    ));
  }

  static Future<void> consumePending() async {
    final action = _pendingAction;
    if (action == null || appNavigatorKey.currentState == null) return;
    _pendingAction = null;
    await open(action);
  }
}

class _NotificationDestination extends StatelessWidget {
  const _NotificationDestination({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: child,
      );
}
