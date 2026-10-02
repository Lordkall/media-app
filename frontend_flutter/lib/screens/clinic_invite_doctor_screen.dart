import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../widgets/profile_avatar.dart';

class ClinicInviteDoctorScreen extends StatefulWidget {
  const ClinicInviteDoctorScreen({super.key});

  @override
  State<ClinicInviteDoctorScreen> createState() => _ClinicInviteDoctorScreenState();
}

class _ClinicInviteDoctorScreenState extends State<ClinicInviteDoctorScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  bool _loading = false;
  List<dynamic> _results = [];

  Future<void> _search() async {
    setState(() => _loading = true);
    try {
      final name = Uri.encodeComponent(_nameController.text.trim());
      final stateStr = Uri.encodeComponent(_stateController.text.trim());
      final response = await ApiClient.get('/clinics/me/search-doctors?name=$name&state=$stateStr');
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          _results = jsonDecode(response.body) as List<dynamic>;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al buscar doctores.')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _invite(int doctorId) async {
    final response = await ApiClient.post('/clinics/me/invite-doctor/$doctorId', {});
    if (!mounted) return;
    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invitación enviada exitosamente.')));
      _search(); // Refresh results
    } else {
      var detail = 'Error al enviar invitación';
      try {
        detail = jsonDecode(response.body)['detail']?.toString() ?? detail;
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(detail)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invitar Doctor')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nombre del Doctor', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _stateController,
              decoration: const InputDecoration(labelText: 'Estado (ej. Distrito Capital)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _search,
                child: const Text('Buscar'),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                      ? const Center(child: Text('No se encontraron resultados.'))
                      : ListView.builder(
                          itemCount: _results.length,
                          itemBuilder: (context, index) {
                            final doc = _results[index];
                            return Card(
                              child: ListTile(
                                leading: ProfileAvatar(imageUrl: doc['avatar_url']?.toString(), size: 40, fallbackRole: 'doctor'),
                                title: Text(doc['name'] ?? ''),
                                subtitle: Text('${doc['state'] ?? ''} - ${(doc['specialties'] as List<dynamic>? ?? []).join(', ')}'),
                                trailing: FilledButton(
                                  onPressed: () => _invite(doc['doctor_id']),
                                  child: const Text('Invitar'),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
