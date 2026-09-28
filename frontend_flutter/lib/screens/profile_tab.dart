import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/api_client.dart';
import '../core/profile_image_helper.dart';
import '../models/ve_catalogs.dart';
import '../widgets/profile_avatar.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _fee = TextEditingController();
  final _bio = TextEditingController();

  Map<String, dynamic>? _userData;
  List<String> _specialties = [];
  String? _state;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isVip = false;

  bool get _isDoctor => _userData?['role'] == 'doctor';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _address.dispose();
    _fee.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      final userResponse = await ApiClient.get('/users/me');
      if (userResponse.statusCode != 200)
        throw Exception('No se pudo cargar el perfil');
      final user = Map<String, dynamic>.from(jsonDecode(userResponse.body));
      Map<String, dynamic>? doctor;
      Map<String, dynamic>? subscription;
      if (user['role'] == 'doctor') {
        final responses = await Future.wait([
          ApiClient.get('/doctors/me'),
          ApiClient.get('/subscriptions/me'),
        ]);
        if (responses[0].statusCode == 200) {
          doctor = Map<String, dynamic>.from(jsonDecode(responses[0].body));
        }
        if (responses[1].statusCode == 200) {
          subscription =
              Map<String, dynamic>.from(jsonDecode(responses[1].body));
        }
      }
      if (!mounted) return;
      _firstName.text = user['first_name']?.toString() ?? '';
      _lastName.text = user['last_name']?.toString() ?? '';
      _phone.text = user['phone']?.toString() ?? '';
      _address.text = user['address']?.toString() ?? '';
      _state =
          veStates.contains(user['state']) ? user['state'] as String : null;
      _fee.text = doctor?['consultation_fee']?.toString() ?? '';
      _bio.text = doctor?['bio']?.toString() ?? '';
      _specialties =
          List<String>.from(doctor?['specialties'] ?? const <String>[]);
      ProfileImageHelper.updateCurrentUserAvatar(
          user['avatar_url']?.toString());
      setState(() {
        _userData = user;
        _isVip = subscription?['current']?['plan'] == 'sponsored';
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (pickedFile == null) return;

    setState(() => _isSaving = true);
    try {
      final url = await ApiClient.uploadFile(
        '/upload/avatar',
        bytes: await pickedFile.readAsBytes(),
        filename: pickedFile.name,
      );
      if (url == null) throw Exception('No se pudo subir la imagen');
      if (!mounted) return;
      setState(() => _userData = {...?_userData, 'avatar_url': url});
      ProfileImageHelper.updateCurrentUserAvatar(url);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Foto de perfil actualizada.'),
            backgroundColor: Colors.green),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al subir la foto: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveProfile() async {
    final fee = double.tryParse(_fee.text.trim().replaceAll(',', '.'));
    if (_isDoctor && (fee == null || fee < 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un precio de consulta válido.')),
      );
      return;
    }
    if (_isDoctor && _specialties.length > 5) return;

    setState(() => _isSaving = true);
    try {
      final userResponse = await ApiClient.put('/users/me', {
        'first_name': _firstName.text.trim(),
        'last_name': _lastName.text.trim(),
        'phone': _phone.text.trim(),
        'address': _address.text.trim(),
        'state': _state,
      });
      if (userResponse.statusCode != 200) {
        throw Exception('No se pudo guardar la información personal');
      }

      if (_isDoctor) {
        final doctorResponse = await ApiClient.put('/doctors/me', {
          'consultation_fee': fee,
          'bio': _bio.text.trim(),
          'specialties': _specialties,
        });
        if (doctorResponse.statusCode != 200) {
          throw Exception('No se pudo guardar el precio o las especialidades');
        }
      }

      if (!mounted) return;
      setState(() {
        _userData = {
          ...?_userData,
          'first_name': _firstName.text.trim(),
          'last_name': _lastName.text.trim(),
          'phone': _phone.text.trim(),
          'address': _address.text.trim(),
          'state': _state,
        };
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Perfil actualizado correctamente.'),
            backgroundColor: Colors.green),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _chooseSpecialties() async {
    final selection = Set<String>.from(_specialties);
    final result = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, updateDialog) => AlertDialog(
          title: Text('Especialidades (${selection.length}/5)'),
          content: SizedBox(
            width: 420,
            height: 440,
            child: ListView.builder(
              itemCount: medicalSpecialties.length,
              itemBuilder: (context, index) {
                final specialty = medicalSpecialties[index];
                final selected = selection.contains(specialty);
                return CheckboxListTile(
                  dense: true,
                  value: selected,
                  title: Text(specialty),
                  onChanged: !selected && selection.length >= 5
                      ? null
                      : (checked) => updateDialog(() {
                            if (checked == true) {
                              selection.add(specialty);
                            } else {
                              selection.remove(specialty);
                            }
                          }),
                );
              },
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, selection.toList()),
                child: const Text('Guardar')),
          ],
        ),
      ),
    );
    if (result != null && mounted) setState(() => _specialties = result);
  }

  Widget _textField(String label, TextEditingController controller,
      {int maxLines = 1, TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white.withOpacity(0.65),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE0EAFC), Color(0xFFCFDEF3), Color(0xFFB3C6DF)],
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 110),
          children: [
            const Text('Mi Perfil',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0B2545))),
            const SizedBox(height: 24),
            Center(
              child: ProfileAvatar(
                imageUrl: _userData?['avatar_url']?.toString(),
                currentUser: true,
                size: 120,
                borderColor: _isDoctor && _isVip
                    ? const Color(0xFFFFC107)
                    : const Color(0xFF0056B3),
                borderWidth: 4,
              ),
            ),
            Center(
              child: TextButton.icon(
                onPressed: _isSaving ? null : _pickImage,
                icon: const Icon(Icons.cloud_upload),
                label: const Text('Cambiar Foto de Perfil'),
              ),
            ),
            const SizedBox(height: 12),
            _textField('Nombre', _firstName),
            const SizedBox(height: 14),
            _textField('Apellido', _lastName),
            const SizedBox(height: 14),
            _textField('Teléfono de contacto', _phone,
                keyboardType: TextInputType.phone),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _state,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Estado / ubicación',
                filled: true,
                fillColor: Colors.white.withOpacity(0.65),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: [
                const DropdownMenuItem<String>(
                    value: null, child: Text('Selecciona un estado')),
                ...veStates.map((state) =>
                    DropdownMenuItem(value: state, child: Text(state))),
              ],
              onChanged: (value) => setState(() => _state = value),
            ),
            const SizedBox(height: 14),
            _textField('Dirección', _address, maxLines: 2),
            if (_isDoctor) ...[
              const SizedBox(height: 22),
              const Text('Perfil médico',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0B2545))),
              const SizedBox(height: 14),
              _textField('Precio de consulta', _fee,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true)),
              const SizedBox(height: 14),
              _textField('Biografía', _bio, maxLines: 4),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(
                      child: Text('Especialidades (máximo 5)',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  TextButton.icon(
                      onPressed: _chooseSpecialties,
                      icon: const Icon(Icons.edit),
                      label: const Text('Editar')),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _specialties
                    .map((specialty) => InputChip(
                          label: Text(specialty),
                          onDeleted: () =>
                              setState(() => _specialties.remove(specialty)),
                        ))
                    .toList(),
              ),
              if (_specialties.isEmpty)
                const Text('Selecciona al menos una especialidad.',
                    style: TextStyle(color: Colors.grey)),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _isSaving ? null : _saveProfile,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save),
              label: const Text('Guardar cambios'),
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
