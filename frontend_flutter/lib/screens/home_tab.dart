import 'package:flutter/material.dart';
import '../widgets/doctor_header.dart';
import '../widgets/appointment_card.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE0EAFC), Color(0xFFCFDEF3), Color(0xFFB3C6DF)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const DoctorHeader(),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Divider(color: Colors.white),
              ),
              const Center(
                child: Text('Menú Principal', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0B2545))),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Fecha:', style: TextStyle(fontSize: 16, color: Color(0xFF0B2545))),
                  Row(
                    children: const [
                      Icon(Icons.calendar_month, color: Color(0xFF0056B3)),
                      SizedBox(width: 8),
                      Text('24/09/2026', style: TextStyle(fontSize: 16, color: Color(0xFF0B2545))),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: const [
                    AppointmentCard(
                      patientName: 'Juan Pérez',
                      status: 'Confirmada',
                      clinicName: 'Clínica Central - Consultorio 4',
                      reason: 'Razona la visita trencata',
                      date: '24/09/2026',
                      time: '03:00 PM',
                      turn: '1',
                    ),
                    AppointmentCard(
                      patientName: 'María Gómez',
                      status: 'Confirmada',
                      clinicName: 'Clínica Central - Consultorio 4',
                      reason: 'Razon de la visita',
                      date: '24/09/2026',
                      time: '03:30 PM',
                      turn: '2',
                    ),
                    SizedBox(height: 80), // Espacio extra para que el FAB no tape la ultima tarjeta
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
