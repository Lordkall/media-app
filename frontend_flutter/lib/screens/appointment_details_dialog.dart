import 'package:flutter/material.dart';

import '../widgets/profile_avatar.dart';

Future<void> showAppointmentDetailsDialog(
  BuildContext context,
  Map<String, dynamic> appt, {
  required bool isDoctor,
}) async {
  final otherPersonName =
      (isDoctor ? appt['patient_name'] : appt['doctor_name'])?.toString() ??
          (isDoctor ? 'Paciente' : 'Doctor');
  final specialty = appt['doctor_specialty']?.toString() ?? 'Consulta Médica';
  final status = (appt['status'] ?? 'scheduled').toString().toLowerCase();
  final displayStatus = status == 'scheduled'
      ? 'PROGRAMADA'
      : (status == 'cancelled' ? 'CANCELADA' : status.toUpperCase());
  final avatarUrl = appt['doctor_avatar']?.toString();

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: const EdgeInsets.all(24),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    ProfileAvatar(
                      imageUrl: avatarUrl,
                      size: 84,
                      fallbackRole: isDoctor ? 'patient' : 'doctor',
                      borderColor: !isDoctor && appt['doctor_is_vip'] == true
                          ? const Color(0xFFFFC107)
                          : Colors.transparent,
                      borderWidth:
                          !isDoctor && appt['doctor_is_vip'] == true ? 3 : 0,
                    ),
                    const SizedBox(height: 12),
                    Text(otherPersonName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0B2545))),
                    const SizedBox(height: 4),
                    Text(specialty,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF0056B3),
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: status == 'scheduled'
                              ? Colors.green.shade600
                              : (status == 'cancelled'
                                  ? Colors.red.shade400
                                  : Colors.blueGrey),
                          borderRadius: BorderRadius.circular(16)),
                      child: Text(displayStatus,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              letterSpacing: 0.5)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: const Color(0xFFE2F1F8),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: const Color(0xFF0056B3).withValues(alpha: 0.3))),
                child: Row(children: [
                  const Icon(Icons.confirmation_number_outlined,
                      color: Color(0xFF0056B3), size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const Text('TURNO ASIGNADO',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0056B3))),
                        Text('Turno #${appt['turn_number'] ?? '-'}',
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0B2545)))
                      ]))
                ]),
              ),
              const SizedBox(height: 16),
              _detail(Icons.calendar_today, 'Fecha',
                  appt['date']?.toString() ?? ''),
              const SizedBox(height: 12),
              _detail(Icons.access_time, 'Hora estimada / Bloque',
                  appt['time_block']?.toString() ?? 'Hora pendiente'),
              if ((appt['doctor_location']?.toString().trim().isNotEmpty ??
                      false) &&
                  !isDoctor) ...[
                const SizedBox(height: 12),
                _detail(Icons.location_on, 'Ubicación / Consultorio',
                    appt['doctor_location'].toString()),
              ],
              if (isDoctor &&
                  appt['patient_phone']?.toString().trim().isNotEmpty ==
                      true) ...[
                const SizedBox(height: 12),
                _detail(Icons.phone, 'Teléfono del paciente',
                    appt['patient_phone'].toString()),
              ],
              if (isDoctor && appt['patient_age'] != null) ...[
                const SizedBox(height: 12),
                _detail(
                    Icons.cake_outlined,
                    'Edad del paciente',
                    appt['patient_age_display']?.toString() ??
                        '${appt['patient_age']}'),
              ],
              if (isDoctor &&
                  appt['patient_relationship']?.toString().isNotEmpty ==
                      true) ...[
                const SizedBox(height: 12),
                _detail(Icons.family_restroom, 'Parentesco',
                    appt['patient_relationship'].toString()),
              ],
              if (!isDoctor &&
                  appt['doctor_phone']?.toString().trim().isNotEmpty ==
                      true) ...[
                const SizedBox(height: 12),
                _detail(Icons.phone, 'Teléfono del doctor',
                    appt['doctor_phone'].toString()),
              ],
              if ((appt['appointment_reason']?.toString() ??
                      appt['reason']?.toString() ??
                      '')
                  .trim()
                  .isNotEmpty) ...[
                const SizedBox(height: 12),
                _detail(Icons.medical_services_outlined, 'Motivo de consulta',
                    (appt['appointment_reason'] ?? appt['reason']).toString()),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar',
                style: TextStyle(
                    color: Color(0xFF0056B3),
                    fontWeight: FontWeight.bold,
                    fontSize: 16)))
      ],
    ),
  );
}

Widget _detail(IconData icon, String label, String value) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF0056B3)),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(fontSize: 14, color: Color(0xFF0B2545)))
        ]))
      ],
    );
