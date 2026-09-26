import 'package:flutter/material.dart';
import '../core/api_client.dart';
import 'dart:convert';

class AdminSubscriptionsTab extends StatefulWidget {
  const AdminSubscriptionsTab({super.key});

  @override
  State<AdminSubscriptionsTab> createState() => _AdminSubscriptionsTabState();
}

class _AdminSubscriptionsTabState extends State<AdminSubscriptionsTab> {
  bool _isLoading = true;
  List<dynamic> _doctors = [];

  @override
  void initState() {
    super.initState();
    _fetchDoctors();
  }

  Future<void> _fetchDoctors() async {
    try {
      final response = await ApiClient.get('/admin/doctors');
      if (response.statusCode == 200) {
        setState(() {
          _doctors = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error fetching doctors: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateSub(int doctorId, String action, [String? plan]) async {
    try {
      final url = '/admin/subscriptions/$doctorId/$action' + (plan != null ? '?plan=$plan' : '');
      final response = await ApiClient.post(url, {});
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Suscripción actualizada')));
        _fetchDoctors();
      }
    } catch (e) {
      print('Error updating subscription: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE0EAFC), Color(0xFFCFDEF3), Color(0xFFB3C6DF)],
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Gestión de Suscripciones', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0B2545))),
                  SizedBox(height: 4),
                  Text('Aprueba pagos y asigna rangos VIP o Destacado', style: TextStyle(color: Color(0xFF475569))),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text('Doctores Registrados y Estado de Suscripción', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0B2545))),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _doctors.isEmpty 
                    ? const Center(child: Text('No hay doctores registrados.'))
                    : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      itemCount: _doctors.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final doc = _doctors[index];
                        final name = 'Dr. ${doc['first_name']} ${doc['last_name']}';
                        final specialties = (doc['specialties'] as List<dynamic>?)?.join(', ') ?? 'Médico General';
                        final plan = doc['plan'];
                        
                        Color planColor = Colors.grey;
                        if (plan == 'sponsored') planColor = const Color(0xFF0056B3);
                        else if (plan == 'basic' || plan == 'featured') planColor = const Color(0xFF00BCD4);
                        
                        final daysRemaining = doc['days_remaining'] ?? 0;

                        return _buildSubCard(
                          doc['id'],
                          name, 
                          '$specialties | ${doc['email']}', 
                          plan == 'Ninguno' ? 'Sin plan' : plan, 
                          planColor,
                          daysRemaining
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubCard(int doctorId, String name, String details, String plan, Color planColor, int daysRemaining) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0B2545))),
                    const SizedBox(height: 8),
                    Text('Especialidad:\n$details', style: const TextStyle(color: Color(0xFF475569))),
                    if (plan != 'Sin plan') ...[
                      const SizedBox(height: 4),
                      Text('Días restantes: $daysRemaining', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0056B3))),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: planColor, borderRadius: BorderRadius.circular(20)),
                child: Text('✓ $plan', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              )
            ],
          ),
          const SizedBox(height: 16),
          const Text('Acciones de Administrador:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0B2545))),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _updateSub(doctorId, 'activate', 'sponsored'),
                  icon: const Icon(Icons.star, color: Colors.white, size: 16),
                  label: const Text('VIP', style: TextStyle(color: Colors.white, fontSize: 12)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0056B3)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _updateSub(doctorId, 'activate', 'featured'),
                  icon: const Icon(Icons.check, color: Colors.white, size: 16),
                  label: const Text('Básico', style: TextStyle(color: Colors.white, fontSize: 12)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00BCD4)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => _updateSub(doctorId, 'renew'),
            icon: const Icon(Icons.autorenew, color: Colors.white),
            label: const Text('Renovar Suscripción', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0056B3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              minimumSize: const Size(double.infinity, 40),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _updateSub(doctorId, 'deactivate'),
            icon: const Icon(Icons.block, color: Colors.red),
            label: const Text('Desactivar Suscripción', style: TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              minimumSize: const Size(double.infinity, 40),
            ),
          ),
        ],
      ),
    );
  }
}
