import 'package:flutter/material.dart';

class AppointmentCard extends StatelessWidget {
  final String patientName;
  final String status;
  final String clinicName;
  final String reason;
  final String date;
  final String time;
  final String turn;

  const AppointmentCard({
    super.key,
    required this.patientName,
    required this.status,
    required this.clinicName,
    required this.reason,
    required this.date,
    required this.time,
    required this.turn,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0056B3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 20,
                backgroundColor: Color(0xFFCFDEF3),
                child: Icon(Icons.person, color: Color(0xFF0056B3)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Paciente: $patientName',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(10)),
                child: Text(status, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Expanded(child: Text(clinicName, style: const TextStyle(color: Colors.white, fontSize: 12))),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: Text(reason, style: const TextStyle(color: Color(0xFFCFDEF3), fontSize: 13)),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$date - $time', style: const TextStyle(color: Colors.white, fontSize: 12)),
                Text('Turno #$turn', style: const TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ),
          )
        ],
      ),
    );
  }
}
