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
  List<dynamic> _clinics = [];
  String _searchType = 'Doctores'; // 'Doctores' or 'Clínicas'
  String _selectedStatus = 'Todos';

  List<dynamic> get _visibleItems {
    final source = _searchType == 'Doctores' ? _doctors : _clinics;
    final filtered = source.where((item) {
      final hasActiveSubscription = item['plan'] != null &&
          item['plan'] != 'Ninguno' &&
          item['plan'] != 'none';
      final hasPendingPayment = item['pending_sub_id'] != null;
      final status = hasPendingPayment
          ? 'Pago pendiente'
          : hasActiveSubscription
              ? 'Activa'
              : 'Sin suscripción';
      return _selectedStatus == 'Todos' || _selectedStatus == status;
    }).toList();

    filtered.sort((a, b) {
      final aHasSubscription = a['plan'] != null &&
          a['plan'] != 'Ninguno' &&
          a['plan'] != 'none';
      final bHasSubscription = b['plan'] != null &&
          b['plan'] != 'Ninguno' &&
          b['plan'] != 'none';
      if (aHasSubscription != bHasSubscription) {
        return aHasSubscription ? -1 : 1;
      }
      if (!aHasSubscription) return 0;
      final aDays = (a['days_remaining'] as num?)?.toInt() ?? 0;
      final bDays = (b['days_remaining'] as num?)?.toInt() ?? 0;
      return aDays.compareTo(bDays);
    });
    return filtered;
  }

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final docRes = await ApiClient.get('/admin/doctors');
      final cliRes = await ApiClient.get('/admin/clinics');
      
      setState(() {
        if (docRes.statusCode == 200) {
          _doctors = jsonDecode(docRes.body);
        }
        if (cliRes.statusCode == 200) {
          _clinics = jsonDecode(cliRes.body);
        }
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateSub(int id, String action, [String? plan]) async {
    try {
      String url;
      if (action == 'approve') {
        // Approve uses sub_id (the pending subscription id), not doctor_id
        url = '/admin/subscriptions/$id/approve';
      } else if (action == 'reject') {
        url = '/admin/subscriptions/$id/reject';
      } else if (_searchType == 'Doctores') {
        url = '/admin/subscriptions/$id/$action' + (plan != null ? '?plan=$plan' : '');
      } else {
        url = '/admin/clinic_subscriptions/$id/$action' + (plan != null ? '?plan=$plan' : '');
      }
      
      final response = await ApiClient.post(url, {});
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✓ Suscripción actualizada'), backgroundColor: Colors.green)
        );
        _fetchData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${response.body}'), backgroundColor: Colors.red)
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _visibleItems;

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
                  Text('Aprueba pagos y asigna rangos', style: TextStyle(color: Color(0xFF475569))),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _searchType = 'Doctores'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _searchType == 'Doctores' ? const Color(0xFF0056B3) : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF0056B3)),
                        ),
                        child: Center(
                          child: Text('Doctores', style: TextStyle(
                            color: _searchType == 'Doctores' ? Colors.white : const Color(0xFF0056B3),
                            fontWeight: FontWeight.bold
                          )),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _searchType = 'Clínicas'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _searchType == 'Clínicas' ? const Color(0xFF0056B3) : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF0056B3)),
                        ),
                        child: Center(
                          child: Text('Clínicas', style: TextStyle(
                            color: _searchType == 'Clínicas' ? Colors.white : const Color(0xFF0056B3),
                            fontWeight: FontWeight.bold
                          )),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DropdownButtonFormField<String>(
                value: _selectedStatus,
                decoration: InputDecoration(
                  labelText: 'Filtrar por estado',
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.8),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                items: const [
                  'Todos',
                  'Activa',
                  'Pago pendiente',
                  'Sin suscripción',
                ]
                    .map((status) => DropdownMenuItem(
                          value: status,
                          child: Text(status),
                        ))
                    .toList(),
                onChanged: (status) {
                  if (status != null) setState(() => _selectedStatus = status);
                },
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : items.isEmpty 
                    ? Center(child: Text('No hay ${_searchType.toLowerCase()} registrados.'))
                    : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      itemCount: items.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final name = _searchType == 'Doctores' 
                            ? 'Dr. ${item['first_name']} ${item['last_name']}'
                            : '${item['first_name']}';
                        final specialties = (item['specialties'] as List<dynamic>?)?.join(', ') ?? 'Médico General';
                        final plan = item['plan'];
                        
                        Color planColor = Colors.grey;
                        if (plan == 'sponsored' || plan == 'clinic_vip') planColor = const Color(0xFF0056B3);
                        else if (plan == 'basic' || plan == 'featured') planColor = const Color(0xFF00BCD4);
                        
                        final daysRemaining = item['days_remaining'] ?? 0;

                        return _buildSubCard(
                          item['id'],
                          name, 
                          _searchType == 'Doctores' ? '$specialties | ${item['email']}' : '${item['email']}', 
                          plan == 'Ninguno' ? 'Sin plan' : plan, 
                          planColor,
                          daysRemaining,
                          pendingSubId: item['pending_sub_id'],
                          pendingPlan: item['pending_plan'],
                          pendingReference: item['pending_reference'],
                          pendingAmountBs: item['pending_amount_bs'] != null ? (item['pending_amount_bs'] as num).toDouble() : null,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubCard(int targetId, String name, String details, String plan, Color planColor, int daysRemaining, {
    int? pendingSubId,
    String? pendingPlan,
    String? pendingReference,
    double? pendingAmountBs,
  }) {
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
                    Text(details, style: const TextStyle(color: Color(0xFF475569))),
                    if (plan != 'Sin plan') ...[
                      const SizedBox(height: 4),
                      Text('Días restantes: $daysRemaining', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0056B3))),
                    ],
                    if (pendingSubId != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.orange)
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const Icon(Icons.schedule, color: Colors.orange, size: 12),
                              const SizedBox(width: 4),
                              Text('PAGO PENDIENTE: ${(pendingPlan ?? "").toUpperCase()}',
                                style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 10))
                            ]),
                            if (pendingReference != null)
                              Text('Ref: $pendingReference', style: const TextStyle(fontSize: 10, color: Colors.brown)),
                            if (pendingAmountBs != null)
                              Text('Bs. ${pendingAmountBs.toStringAsFixed(2)}', style: const TextStyle(fontSize: 10, color: Colors.brown)),
                          ],
                        ),
                      ),
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
          // Approve pending payment button (most important action)
          if (pendingSubId != null) ...[
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => _updateSub(pendingSubId, 'approve'),
              icon: const Icon(Icons.check_circle, color: Colors.white),
              label: Text('✔ Aprobar Pago ${pendingPlan?.toUpperCase() ?? ""}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                minimumSize: const Size(double.infinity, 44),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _updateSub(pendingSubId, 'reject'),
              icon: const Icon(Icons.cancel, color: Colors.white, size: 16),
              label: const Text('Rechazar Pago', style: TextStyle(color: Colors.white, fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                minimumSize: const Size(double.infinity, 36),
              ),
            ),
          ],
          const SizedBox(height: 8),
          const Divider(),
          const Text('Asignar manualmente:', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _updateSub(targetId, 'activate', _searchType == 'Doctores' ? 'sponsored' : 'clinic_vip'),
                  icon: const Icon(Icons.star, color: Colors.white, size: 16),
                  label: const Text('VIP', style: TextStyle(color: Colors.white, fontSize: 12)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0056B3)),
                ),
              ),
              if (_searchType == 'Doctores') ...[
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _updateSub(targetId, 'activate', 'featured'),
                    icon: const Icon(Icons.check, color: Colors.white, size: 16),
                    label: const Text('Básico', style: TextStyle(color: Colors.white, fontSize: 12)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00BCD4)),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => _updateSub(targetId, 'renew'),
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
            onPressed: () => _updateSub(targetId, 'deactivate'),
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
