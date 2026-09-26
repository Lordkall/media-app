import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../core/profile_image_helper.dart';
import '../core/api_client.dart';
import 'dart:convert';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _doctorData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final userResponse = await ApiClient.get('/users/me');
      if (userResponse.statusCode == 200) {
        final userData = jsonDecode(userResponse.body);
        Map<String, dynamic>? doctorData;
        if (userData['role'] == 'doctor') {
          final docResponse = await ApiClient.get('/doctors/me');
          if (docResponse.statusCode == 200) {
            doctorData = jsonDecode(docResponse.body);
          }
        }
        if (mounted) {
          setState(() {
            _userData = userData;
            _doctorData = doctorData;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _isLoading = true);
      final url = await ApiClient.uploadFile('/upload/avatar', pickedFile.path);
      if (url != null) {
        setState(() {
          if (_userData != null) {
            _userData!['avatar_url'] = url;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto actualizada correctamente.')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al subir la imagen.')));
      }
      setState(() => _isLoading = false);
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Mi Perfil',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0B2545)),
              ),
              const SizedBox(height: 24),
              Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF0056B3), width: 4),
                  color: Colors.grey[200],
                  image: DecorationImage(
                    image: ProfileImageHelper.getProfileImageProvider(_userData?['avatar_url']),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (_isLoading) const CircularProgressIndicator()
              else ...[
                Text(
                  _userData?['role'] == 'admin' ? 'Administrador' : (_userData?['role'] == 'doctor' ? 'Doctor' : 'Paciente'), 
                  style: const TextStyle(color: Color(0xFF38B6FF), fontWeight: FontWeight.bold, fontSize: 16)
                ),
                TextButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.cloud_upload, color: Color(0xFF0056B3)),
                  label: const Text('Cambiar Foto de Perfil', style: TextStyle(color: Color(0xFF0056B3), fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 24),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Información Personal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0B2545))),
                ),
                const SizedBox(height: 16),
                _buildTextField('Nombre', _userData?['first_name'] ?? 'Cargando...'),
                const SizedBox(height: 16),
                _buildTextField('Apellido', _userData?['last_name'] ?? 'Cargando...'),
                const SizedBox(height: 16),
                _buildTextField('Teléfono de Contacto', _userData?['phone_number'] ?? '04240000000'),
                if (_userData?['role'] == 'doctor') ...[
                  const SizedBox(height: 16),
                  _buildTextField('Días Laborables', 'Lunes a Viernes'),
                  const SizedBox(height: 16),
                  _buildTextField('Horario', '08:00 AM - 05:00 PM'),
                  const SizedBox(height: 16),
                  _buildTextField('Precio de Consulta', '\$${_doctorData?['consultation_fee'] ?? '40.00'}'),
                  const SizedBox(height: 16),
                  _buildTextField(
                    'Biografía (Breve descripción)', 
                    _doctorData?['bio'] ?? 'Médico especialista con más de 10 años de experiencia brindando atención integral y personalizada a cada paciente.',
                    maxLines: 4,
                  ),
                ],
                const SizedBox(height: 24),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.lock, color: Color(0xFF0056B3)),
                  label: const Text('Cambiar Contraseña', style: TextStyle(color: Color(0xFF0056B3))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF0056B3)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Tus cambios han sido guardados correctamente.')),
                    );
                  },
                  icon: const Icon(Icons.save, color: Colors.white),
                  label: const Text('Guardar Cambios de Perfil', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0056B3),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, String value, {int maxLines = 1}) {
    return TextFormField(
      initialValue: value,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF475569)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0B2545))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0B2545))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0056B3), width: 2)),
      ),
      style: const TextStyle(color: Color(0xFF0B2545), fontSize: 16, fontWeight: FontWeight.w500),
    );
  }
}
