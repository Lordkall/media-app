import 'package:flutter/material.dart';

import 'dart:convert';

import 'api_client.dart';
import 'app_navigator.dart';
import 'auth_helper.dart';
import '../screens/agendar_cita_tab.dart';
import '../screens/appointment_details_dialog.dart';
import '../screens/mi_disponibilidad_tab.dart';

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
    final dialogContext = context != null && context.mounted
        ? context
        : appNavigatorKey.currentContext;
    if (dialogContext == null || !dialogContext.mounted) {
      _pendingAction = action;
      return;
    }
    try {
      final response = await ApiClient.get('/appointments/my');
      if (response.statusCode != 200) return;
      final decoded = jsonDecode(response.body);
      final appointments = decoded is List
          ? decoded
          : (decoded is Map && decoded['items'] is List
              ? decoded['items'] as List
              : <dynamic>[]);
      Map<String, dynamic>? appointment;
      for (final item in appointments) {
        if (item is Map && item['id'].toString() == appointmentId.toString()) {
          appointment = Map<String, dynamic>.from(item);
          break;
        }
      }
      if (appointment == null || !dialogContext.mounted) return;
      await showAppointmentDetailsDialog(
        dialogContext,
        appointment,
        isDoctor: role == 'doctor' || role == 'assistant',
      );
    } catch (_) {
      // Keep notification interactions quiet if appointment details cannot load.
    }
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
