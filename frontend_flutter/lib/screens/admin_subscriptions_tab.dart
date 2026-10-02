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
  List<dynamic> _patients = [];
  String _searchType = 'Doctores'; // 'Doctores', 'Clínicas', or 'Pacientes'
  String _selectedStatus = 'Todos';

  List<dynamic> get _visibleItems {
    final List<dynamic> source;
    if (_searchType == 'Doctores') {
      source = _doctors;
    } else if (_searchType == 'Clínicas') {
      source = _clinics;
    } else {
      source = _patients;
    }

    final filtered = source.where((item) {
      final isBlocked = item['is_blocked'] == true;
      if (_searchType == 'Pacientes') {
        if (_selectedStatus == 'Todos') return true;
        if (_selectedStatus == 'Bloqueado') return isBlocked;
        if (_selectedStatus == 'Activo') return !isBlocked;
        return true;
      }

      if (_selectedStatus == 'Bloqueado') return isBlocked;

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

    if (_searchType != 'Pacientes') {
      filtered.sort((a, b) {
        final aHasSubscription =
            a['plan'] != null && a['plan'] != 'Ninguno' && a['plan'] != 'none';
        final bHasSubscription =
            b['plan'] != null && b['plan'] != 'Ninguno' && b['plan'] != 'none';
        if (aHasSubscription != bHasSubscription) {
          return aHasSubscription ? -1 : 1;
        }
        if (!aHasSubscription) return 0;
        final aDays = (a['days_remaining'] as num?)?.toInt() ?? 0;
        final bDays = (b['days_remaining'] as num?)?.toInt() ?? 0;
        return aDays.compareTo(bDays);
      });
    } else {
      filtered.sort((a, b) {
        final aName = '${a['first_name']} ${a['last_name']}';
        final bName = '${b['first_name']} ${b['last_name']}';
        return aName.compareTo(bName);
      });
    }
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
      final patRes = await ApiClient.get('/admin/patients');
      if (!mounted) return;

      setState(() {
        if (docRes.statusCode == 200) {
          _doctors = jsonDecode(docRes.body);
        }
        if (cliRes.statusCode == 200) {
          _clinics = jsonDecode(cliRes.body);
        }
        if (patRes.statusCode == 200) {
          _patients = jsonDecode(patRes.body);
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('Error fetching data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleBlockUser(int userId, String name, bool currentBlocked) async {
    final actionText = currentBlocked ? 'desbloquear' : 'bloquear';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${currentBlocked ? 'Desbloquear' : 'Bloquear'} cuenta'),
        content: Text(
          '¿Estás seguro de que deseas $actionText la cuenta de $name?\n\n'
          '${currentBlocked ? 'El usuario recuperará el acceso al menú principal y servicios.' : 'El usuario entrará a una pantalla de espera por incumplimiento de normas y solo podrá apelar a soporte o cerrar sesión.'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: currentBlocked ? Colors.green : Colors.red,
            ),
            child: Text(currentBlocked ? 'Desbloquear' : 'Bloquear'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final res = await ApiClient.patch('/admin/users/$userId/toggle-block', {});
      if (!mounted) return;
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(d['message']?.toString() ?? 'Estado de bloqueo actualizado'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${res.body}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _updateSub(int id, String action, [String? plan]) async {
    try {
      String url;
      if (action == 'approve') {
        url = '/admin/subscriptions/$id/approve';
      } else if (action == 'reject') {
        url = '/admin/subscriptions/$id/reject';
      } else if (_searchType == 'Doctores') {
        url =
            '/admin/subscriptions/$id/$action${plan != null ? '?plan=$plan' : ''}';
      } else {
        url =
            '/admin/clinic_subscriptions/$id/$action${plan != null ? '?plan=$plan' : ''}';
      }

      final response = await ApiClient.post(url, {});
      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('✓ Suscripción actualizada'),
            backgroundColor: Colors.green));
        _fetchData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: ${response.body}'),
            backgroundColor: Colors.red));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _deleteAccount(int profileId, String name) async {
    final String typeName;
    final String endpoint;
    if (_searchType == 'Doctores') {
      typeName = 'doctor';
      endpoint = '/admin/doctors/$profileId';
    } else if (_searchType == 'Clínicas') {
      typeName = 'clínica';
      endpoint = '/admin/clinics/$profileId';
    } else {
      typeName = 'paciente';
      endpoint = '/admin/patients/$profileId';
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Eliminar $typeName'),
        content: Text(
          '¿Eliminar permanentemente a $name y sus datos de la base de datos?\n'
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar permanentemente'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed != true || !mounted) return;

    try {
      final response = await ApiClient.delete(endpoint);
      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('$name fue eliminado'),
              backgroundColor: Colors.green),
        );
        await _fetchData();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('No se pudo eliminar: ${response.body}'),
              backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al eliminar: $e'),
              backgroundColor: Colors.red),
        );
      }
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
                  Text('Gestión y Administración',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0B2545))),
                  SizedBox(height: 4),
                  Text('Administra doctores, clínicas, pacientes y bloqueos',
                      style: TextStyle(color: Color(0xFF475569))),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  _buildTabOption('Doctores'),
                  const SizedBox(width: 8),
                  _buildTabOption('Clínicas'),
                  const SizedBox(width: 8),
                  _buildTabOption('Pacientes'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DropdownButtonFormField<String>(
                initialValue: _selectedStatus,
                decoration: InputDecoration(
                  labelText: 'Filtrar por estado',
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.8),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                items: (_searchType == 'Pacientes'
                        ? const ['Todos', 'Activo', 'Bloqueado']
                        : const [
                            'Todos',
                            'Activa',
                            'Pago pendiente',
                            'Sin suscripción',
                            'Bloqueado',
                          ])
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
                      ? Center(
                          child: Text(
                              'No hay ${_searchType.toLowerCase()} registrados.'))
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          itemCount: items.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final item = items[index];

                            if (_searchType == 'Pacientes') {
                              return _buildPatientCard(item);
                            }

                            final name = _searchType == 'Doctores'
                                ? 'Dr. ${item['first_name']} ${item['last_name']}'
                                : '${item['first_name']}';
                            final specialties =
                                (item['specialties'] as List<dynamic>?)
                                        ?.join(', ') ??
                                    'Médico General';
                            final plan = item['plan'];

                            Color planColor = Colors.grey;
                            if (plan == 'sponsored' || plan == 'clinic_vip') {
                              planColor = const Color(0xFF0056B3);
                            } else if (plan == 'basic' || plan == 'featured') {
                              planColor = const Color(0xFF00BCD4);
                            }

                            final daysRemaining = item['days_remaining'] ?? 0;
                            final isBlocked = item['is_blocked'] == true;
                            final userId = item['user_id'] as int;

                            return _buildSubCard(
                              item['id'],
                              userId,
                              name,
                              _searchType == 'Doctores'
                                  ? '$specialties | ${item['email']}'
                                  : '${item['email']}',
                              plan == 'Ninguno' ? 'Sin plan' : plan,
                              planColor,
                              daysRemaining,
                              isBlocked: isBlocked,
                              pendingSubId: item['pending_sub_id'],
                              pendingPlan: item['pending_plan'],
                              pendingReference: item['pending_reference'],
                              pendingAmountBs: item['pending_amount_bs'] != null
                                  ? (item['pending_amount_bs'] as num)
                                      .toDouble()
                                  : null,
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabOption(String title) {
    final isSelected = _searchType == title;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _searchType = title;
          _selectedStatus = 'Todos';
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0056B3) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF0056B3)),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF0056B3),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPatientCard(Map<String, dynamic> item) {
    final name = '${item['first_name']} ${item['last_name']}';
    final email = item['email']?.toString() ?? 'Sin correo';
    final phone = item['phone']?.toString() ?? 'Sin teléfono';
    final state = item['state']?.toString() ?? '';
    final isBlocked = item['is_blocked'] == true;
    final userId = item['user_id'] as int;
    final patientId = item['id'] as int;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isBlocked ? Colors.red.shade300 : Colors.white.withValues(alpha: 0.8),
          width: isBlocked ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: isBlocked
                ? Colors.red.shade100
                : const Color(0xFF0056B3).withValues(alpha: 0.1),
            child: Icon(
              isBlocked ? Icons.lock : Icons.person,
              color: isBlocked ? Colors.red : const Color(0xFF0056B3),
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0B2545),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.email_outlined, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        email,
                        style: const TextStyle(color: Color(0xFF334155), fontSize: 13, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (phone.isNotEmpty && phone != 'Sin teléfono') ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined, size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Text(
                        phone,
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      ),
                    ],
                  ),
                ],
                if (state.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Text(
                        state,
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isBlocked ? Colors.red.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isBlocked ? Colors.red.shade300 : Colors.green.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isBlocked ? Icons.lock : Icons.check_circle_outline,
                        size: 13,
                        color: isBlocked ? Colors.red : Colors.green.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isBlocked ? 'BLOQUEADO' : 'ACTIVO',
                        style: TextStyle(
                          color: isBlocked ? Colors.red : Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: isBlocked ? 'Desbloquear paciente' : 'Bloquear paciente',
                    onPressed: () => _toggleBlockUser(userId, name, isBlocked),
                    icon: Icon(
                      isBlocked ? Icons.lock : Icons.lock_open,
                      color: isBlocked ? Colors.red : Colors.green.shade700,
                      size: 24,
                    ),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                  IconButton(
                    tooltip: 'Eliminar paciente',
                    onPressed: () => _deleteAccount(patientId, name),
                    icon: const Icon(Icons.delete, color: Colors.red, size: 24),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubCard(
    int targetId,
    int userId,
    String name,
    String details,
    String plan,
    Color planColor,
    int daysRemaining, {
    bool isBlocked = false,
    int? pendingSubId,
    String? pendingPlan,
    String? pendingReference,
    double? pendingAmountBs,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isBlocked ? Colors.red.shade300 : Colors.white.withValues(alpha: 0.8),
          width: isBlocked ? 1.5 : 1.0,
        ),
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
                    Text(name,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0B2545))),
                    const SizedBox(height: 8),
                    Text(details,
                        style: const TextStyle(color: Color(0xFF475569))),
                    if (plan != 'Sin plan') ...[
                      const SizedBox(height: 4),
                      Text('Días restantes: $daysRemaining',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0056B3))),
                    ],
                    if (pendingSubId != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.orange)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const Icon(Icons.schedule,
                                  color: Colors.orange, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                  'PAGO PENDIENTE: ${(pendingPlan ?? "").toUpperCase()}',
                                  style: const TextStyle(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10))
                            ]),
                            if (pendingReference != null)
                              Text('Ref: $pendingReference',
                                  style: const TextStyle(
                                      fontSize: 10, color: Colors.brown)),
                            if (pendingAmountBs != null)
                              Text('Bs. ${pendingAmountBs.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      fontSize: 10, color: Colors.brown)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: isBlocked ? 'Desbloquear cuenta' : 'Bloquear cuenta',
                        onPressed: () => _toggleBlockUser(userId, name, isBlocked),
                        icon: Icon(
                          isBlocked ? Icons.lock : Icons.lock_open,
                          color: isBlocked ? Colors.red : Colors.green.shade700,
                          size: 24,
                        ),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 36, minHeight: 36),
                      ),
                      IconButton(
                        tooltip: 'Eliminar registro',
                        onPressed: () => _deleteAccount(targetId, name),
                        icon: const Icon(Icons.delete, color: Colors.red, size: 24),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 36, minHeight: 36),
                      ),
                    ],
                  ),
                  if (isBlocked) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock, size: 11, color: Colors.red),
                          SizedBox(width: 3),
                          Text('BLOQUEADO',
                              style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: planColor,
                        borderRadius: BorderRadius.circular(20)),
                    child: Text('✓ $plan',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
          // Approve pending payment button (most important action)
          if (pendingSubId != null) ...[
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => _updateSub(pendingSubId, 'approve'),
              icon: const Icon(Icons.check_circle, color: Colors.white),
              label: Text('✔ Aprobar Pago ${pendingPlan?.toUpperCase() ?? ""}',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                minimumSize: const Size(double.infinity, 44),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _updateSub(pendingSubId, 'reject'),
              icon: const Icon(Icons.cancel, color: Colors.white, size: 16),
              label: const Text('Rechazar Pago',
                  style: TextStyle(color: Colors.white, fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                minimumSize: const Size(double.infinity, 36),
              ),
            ),
          ],
          const SizedBox(height: 8),
          const Divider(),
          const Text('Asignar manualmente:',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _updateSub(targetId, 'activate',
                      _searchType == 'Doctores' ? 'sponsored' : 'clinic_vip'),
                  icon: const Icon(Icons.star, color: Colors.white, size: 16),
                  label: const Text('VIP',
                      style: TextStyle(color: Colors.white, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0056B3)),
                ),
              ),
              if (_searchType == 'Clínicas') ...[
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _updateSub(targetId, 'activate', 'clinic_basic'),
                    icon: const Icon(Icons.check, color: Colors.white, size: 16),
                    label: const Text('Básico',
                        style: TextStyle(color: Colors.white, fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00BCD4)),
                  ),
                ),
              ] else ...[
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _updateSub(targetId, 'activate', 'featured'),
                    icon:
                        const Icon(Icons.check, color: Colors.white, size: 16),
                    label: const Text('Básico',
                        style: TextStyle(color: Colors.white, fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00BCD4)),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => _updateSub(targetId, 'renew'),
            icon: const Icon(Icons.autorenew, color: Colors.white),
            label: const Text('Renovar Suscripción',
                style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0056B3),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              minimumSize: const Size(double.infinity, 40),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _updateSub(targetId, 'deactivate'),
            icon: const Icon(Icons.block, color: Colors.red),
            label: const Text('Desactivar Suscripción',
                style: TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              minimumSize: const Size(double.infinity, 40),
            ),
          ),
        ],
      ),
    );
  }
}
