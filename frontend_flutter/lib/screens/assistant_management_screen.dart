import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../core/api_client.dart';
import '../models/ve_catalogs.dart';

class AssistantManagementScreen extends StatefulWidget {
  const AssistantManagementScreen({super.key});

  @override
  State<AssistantManagementScreen> createState() =>
      _AssistantManagementScreenState();
}

class _AssistantManagementScreenState extends State<AssistantManagementScreen> {
  List<dynamic> _assistants = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAssistants();
  }

  Future<void> _fetchAssistants() async {
    try {
      final response = await ApiClient.get('/assistants/');
      if (response.statusCode == 200) {
        setState(() {
          _assistants = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _showAddAssistantDialog() {
    if (_assistants.isNotEmpty) return;
    final nameController = TextEditingController();
    final lastNameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final passwordController = TextEditingController();
    bool obscureText = true;
    String? assistantState;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Añadir Asistente',
                style: TextStyle(color: Color(0xFF0B2545))),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Nombre',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: lastNameController,
                    decoration: InputDecoration(
                      labelText: 'Apellido',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Correo Electrónico',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(11)
                    ],
                    maxLength: 11,
                    decoration: InputDecoration(
                      labelText: 'Teléfono (máximo 11 dígitos)',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: assistantState,
                    decoration: InputDecoration(
                      labelText: 'Estado',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    items: veStates
                        .map((state) =>
                            DropdownMenuItem(value: state, child: Text(state)))
                        .toList(),
                    onChanged: (state) =>
                        setDialogState(() => assistantState = state),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    obscureText: obscureText,
                    decoration: InputDecoration(
                      labelText: 'Contraseña Temporal',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      suffixIcon: IconButton(
                        icon: Icon(obscureText
                            ? Icons.visibility
                            : Icons.visibility_off),
                        onPressed: () {
                          setDialogState(() {
                            obscureText = !obscureText;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar',
                    style: TextStyle(color: Color(0xFF0056B3))),
              ),
              ElevatedButton(
                onPressed: () async {
                  final password = passwordController.text;
                  if (nameController.text.trim().isNotEmpty &&
                      lastNameController.text.trim().isNotEmpty &&
                      emailController.text.trim().isNotEmpty &&
                      phoneController.text.length <= 11 &&
                      phoneController.text.length >= 5 &&
                      assistantState != null &&
                      password.length >= 6 &&
                      RegExp(r'[A-Z]').hasMatch(password) &&
                      RegExp(r'[a-zA-Z]').hasMatch(password) &&
                      RegExp(r'[0-9]').hasMatch(password)) {
                    final response = await ApiClient.post('/assistants/', {
                      'first_name': nameController.text.trim(),
                      'last_name': lastNameController.text.trim(),
                      'email': emailController.text.trim().toLowerCase(),
                      'phone': phoneController.text,
                      'state': assistantState,
                      'password': password,
                    });
                    if (!context.mounted) return;

                    if (response.statusCode == 200) {
                      Navigator.pop(context);
                      _fetchAssistants();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Asistente añadido exitosamente.')));
                    } else {
                      final body = jsonDecode(response.body);
                      final detail =
                          body is Map ? body['detail']?.toString() : null;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content:
                              Text(detail ?? 'No se pudo crear el asistente')));
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            'Completa los campos. La contraseña debe tener al menos 6 caracteres, una mayúscula, letras y números.')));
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0056B3),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: const Text('Crear Asistente',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _removeAssistant(int id) async {
    try {
      final response = await ApiClient.delete('/assistants/$id');
      if (!mounted) return;
      if (response.statusCode == 200) {
        _fetchAssistants();
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Asistente eliminado.')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al eliminar asistente.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Asistentes',
            style: TextStyle(
                color: Color(0xFF0B2545), fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFE2F1F8),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0B2545)),
      ),
      backgroundColor: const Color(0xFFE2F1F8),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tus asistentes registrados podrán gestionar tu agenda de citas. Si tu plan VIP vence, perderán el acceso.',
              style: TextStyle(color: Color(0xFF475569), fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _assistants.isEmpty ? _showAddAssistantDialog : null,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Añadir Nuevo Asistente',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0056B3),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
              ),
            ),
            if (_assistants.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Cada doctor puede tener un solo asistente.',
                    style: TextStyle(color: Color(0xFF475569))),
              ),
            const SizedBox(height: 32),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: _assistants.length,
                      itemBuilder: (context, index) {
                        final assistant = _assistants[index];
                        final name =
                            '${assistant['first_name']} ${assistant['last_name']}';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(0)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            leading: const Icon(Icons.person,
                                color: Color(0xFF0056B3), size: 30),
                            title: Text(name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                            subtitle: Text(assistant['email'],
                                style:
                                    const TextStyle(color: Color(0xFF475569))),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                _removeAssistant(assistant['id']);
                              },
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
