import 'package:flutter/material.dart';
import '../core/api_client.dart';
import 'dart:convert';

class AdminStatsTab extends StatefulWidget {
  const AdminStatsTab({super.key});

  @override
  State<AdminStatsTab> createState() => _AdminStatsTabState();
}

class _AdminStatsTabState extends State<AdminStatsTab> {
  bool _isLoading = true;
  Map<String, dynamic>? _statsData;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    try {
      final response = await ApiClient.get('/admin/stats');
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          _statsData = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching stats: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final patients = _statsData?['patients_count']?.toString() ?? '0';
    final doctors = _statsData?['doctors_count']?.toString() ?? '0';
    final clinics = _statsData?['clinics_count']?.toString() ?? '0';
    final subs = _statsData?['subscribed_doctors']?.toString() ?? '0';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE0EAFC), Color(0xFFCFDEF3)],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Estadísticas Globales',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0B2545)),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard('Pacientes\nRegistrados', patients,
                        Icons.personal_injury, Colors.blue),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard('Doctores\nRegistrados', doctors,
                        Icons.medical_services, Colors.teal),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard('Clínicas\nRegistradas', clinics,
                        Icons.local_hospital, Colors.redAccent),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard('Cuentas\nSuscritas', subs,
                        Icons.workspace_premium, Colors.amber),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildDemographicBreakdown(
                'Edades de pacientes',
                _statsData?['patient_age_ranges'] as Map<String, dynamic>? ?? const {},
                const {'0-12': '0–12', '13-17': '13–17', '18-29': '18–29', '30-44': '30–44', '45-59': '45–59', '60+': '60+', 'Sin dato': 'Sin dato'},
              ),
              const SizedBox(height: 16),
              _buildDemographicBreakdown(
                'Género de pacientes',
                _statsData?['patient_genders'] as Map<String, dynamic>? ?? const {},
                const {'masculino': 'Masculino', 'femenino': 'Femenino', 'otro_o_sin_especificar': 'Otro / sin especificar'},
              ),
              const SizedBox(height: 16),
              _buildDemographicBreakdown(
                'Edades de doctores',
                _statsData?['doctor_age_ranges'] as Map<String, dynamic>? ?? const {},
                const {'0-12': '0–12', '13-17': '13–17', '18-29': '18–29', '30-44': '30–44', '45-59': '45–59', '60+': '60+', 'Sin dato': 'Sin dato'},
              ),
              const SizedBox(height: 16),
              _buildDemographicBreakdown(
                'Género de doctores',
                _statsData?['doctor_genders'] as Map<String, dynamic>? ?? const {},
                const {'masculino': 'Masculino', 'femenino': 'Femenino', 'otro_o_sin_especificar': 'Otro / sin especificar'},
              ),
              const SizedBox(height: 32),
              const Text(
                'Distribución por Estados',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0B2545)),
              ),
              const SizedBox(height: 16),
              _buildStateList(),
              const SizedBox(height: 80), // Bottom nav padding
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDemographicBreakdown(
    String title,
    Map<String, dynamic> values,
    Map<String, String> labels,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0B2545))),
          const SizedBox(height: 8),
          ...labels.entries.map((entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(child: Text(entry.value, style: const TextStyle(color: Color(0xFF475569)))),
                    Text('${values[entry.key] ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0056B3))),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 16),
          Text(
            count,
            style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0B2545)),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
          ),
        ],
      ),
    );
  }

  Widget _buildStateList() {
    final states = _statsData?['states'] as List<dynamic>? ?? [];

    if (states.isEmpty) {
      return const Center(child: Text('No hay datos por estado aún.'));
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: states.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final state = states[index];
          return ListTile(
            title: Text(state['name'] as String,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Color(0xFF0B2545))),
            subtitle: Text(
                'Pacientes: ${state['patients']} | Doctores: ${state['doctors']} | Clínicas: ${state['clinics']}',
                style: const TextStyle(color: Color(0xFF475569))),
            trailing: const Icon(Icons.map, color: Color(0xFF38B6FF)),
          );
        },
      ),
    );
  }
}
