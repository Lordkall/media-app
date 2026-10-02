import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../widgets/profile_avatar.dart';
import '../models/ve_catalogs.dart';

class ClinicInviteDoctorScreen extends StatefulWidget {
  const ClinicInviteDoctorScreen({super.key});

  @override
  State<ClinicInviteDoctorScreen> createState() => _ClinicInviteDoctorScreenState();
}

class _ClinicInviteDoctorScreenState extends State<ClinicInviteDoctorScreen> {
  final TextEditingController _nameController = TextEditingController();
  String? _selectedState;
  bool _loading = false;
  List<dynamic> _allDoctorsInState = [];
  List<dynamic> _filteredDoctors = [];

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_filterDoctors);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _filterDoctors() {
    final query = _nameController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _filteredDoctors = List.from(_allDoctorsInState));
      return;
    }
    setState(() {
      _filteredDoctors = _allDoctorsInState.where((doc) {
        final name = (doc['name'] ?? '').toString().toLowerCase();
        return name.contains(query);
      }).toList();
    });
  }

  Future<void> _fetchDoctorsByState(String state) async {
    setState(() {
      _loading = true;
      _allDoctorsInState = [];
      _filteredDoctors = [];
      _nameController.clear();
    });
    try {
      final stateStr = Uri.encodeComponent(state);
      final response = await ApiClient.get('/clinics/me/search-doctors?state=$stateStr');
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          _allDoctorsInState = jsonDecode(response.body) as List<dynamic>;
          _filteredDoctors = List.from(_allDoctorsInState);
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
      if (_selectedState != null) {
        _fetchDoctorsByState(_selectedState!);
      }
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedState,
              decoration: const InputDecoration(labelText: 'Seleccionar Estado', border: OutlineInputBorder()),
              items: veStates.map((state) => DropdownMenuItem(value: state, child: Text(state))).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedState = val);
                  _fetchDoctorsByState(val);
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Escribe el nombre para filtrar',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              enabled: _selectedState != null && !_loading,
            ),
            const SizedBox(height: 16),
            const Divider(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _selectedState == null
                      ? const Center(child: Text('Selecciona un estado para ver los doctores disponibles.'))
                      : _filteredDoctors.isEmpty
                          ? const Center(child: Text('No se encontraron doctores.'))
                          : ListView.builder(
                              itemCount: _filteredDoctors.length,
                              itemBuilder: (context, index) {
                                final doc = _filteredDoctors[index];
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
