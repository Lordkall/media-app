import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:ui';
import '../core/api_client.dart';
import '../models/ve_catalogs.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const _termsText =
      'El uso de esta aplicación implica la aceptación de todas las normas y condiciones descritas. El usuario es responsable de garantizar la veracidad de su información y mantener la seguridad de su cuenta. No nos hacemos responsables por la calidad del servicio médico ni por interrupciones en el sistema.';
  static const _privacyText =
      'Recolectamos datos de contacto y el motivo de la cita registrado por el usuario, como consulta o entrega de exámenes, para gestionar la agenda y mejorar la plataforma. No manejamos información médica detallada o diagnósticos. Sus datos están protegidos y no se comparten sin su consentimiento, y el usuario tiene el derecho de acceder, modificar o eliminar su información en cualquier momento.';
  final _formKey = GlobalKey<FormState>();
  String _role = 'patient';
  String _gender = 'Prefiero no decirlo';
  String? _state;

  final _emailCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _passwordRepeatCtrl = TextEditingController();
  final _clinicDescriptionCtrl = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureRepeatPassword = true;

  final List<String> _estadosVE = veStates;
  final List<String> _specialtiesList = medicalSpecialties;
  final Set<String> _selectedSpecialties = {};

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (_state == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor, selecciona un estado.')));
      return;
    }

    final password = _passwordCtrl.text;
    if (password != _passwordRepeatCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Las contraseñas no coinciden.')));
      return;
    }

    final hasUppercase = password.contains(RegExp(r'[A-Z]'));
    final hasLetters = password.contains(RegExp(r'[a-zA-Z]'));
    final hasNumbers = password.contains(RegExp(r'[0-9]'));

    if (!hasUppercase || !hasLetters || !hasNumbers || password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'La contraseña debe tener letras, números y al menos una mayúscula.')));
      return;
    }

    final accepted = await _showConsentDialog();
    if (accepted != true || !mounted) return;

    setState(() => _isLoading = true);

    try {
      final payload = {
        "email": _emailCtrl.text.trim().toLowerCase(),
        "first_name": _firstNameCtrl.text.trim(),
        "last_name": _lastNameCtrl.text.trim(),
        "phone": _phoneCtrl.text.trim(),
        "state": _state,
        "address": _addressCtrl.text.trim(),
        "gender": _gender,
        "password": _passwordCtrl.text,
        "role": _role,
        "specialties": _selectedSpecialties.toList(),
        "clinic_description": _clinicDescriptionCtrl.text.trim(),
        "accept_terms": true,
        "accept_privacy": true,
      };

      if (_role == 'clinic') {
        payload["last_name"] = "Centro Médico";
      }

      final response = await ApiClient.post('/auth/register', payload);

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('¡Cuenta creada exitosamente!'),
              backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      } else {
        final detail = _registrationError(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(detail), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _registrationError(String body) {
    try {
      final decoded = jsonDecode(body);
      final detail = decoded is Map ? decoded['detail'] : null;
      if (detail is String && detail.isNotEmpty) return detail;
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map && first['msg'] != null) {
          return first['msg'].toString();
        }
      }
    } catch (_) {}
    return 'Verifica los datos o si el correo ya existe.';
  }

  Future<bool?> _showConsentDialog() {
    bool terms = false;
    bool privacy = false;
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Términos y privacidad'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Términos y Condiciones',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(_termsText),
                    CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: terms,
                        title: const Text('Acepto los Términos y Condiciones'),
                        onChanged: (v) => update(() => terms = v ?? false)),
                    const Divider(),
                    const Text('Política de Privacidad',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(_privacyText),
                    CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: privacy,
                        title: const Text('Acepto la Política de Privacidad'),
                        onChanged: (v) => update(() => privacy = v ?? false)),
                  ]),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Rechazar')),
            FilledButton(
                onPressed: terms && privacy
                    ? () => Navigator.pop(dialogContext, true)
                    : null,
                child: const Text('Aceptar y registrarme')),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleButton(String title, IconData icon, String roleValue) {
    final isSelected = _role == roleValue;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _role = roleValue),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0056B3) : Colors.transparent,
            border: Border.all(
                color: isSelected
                    ? const Color(0xFF0056B3)
                    : const Color(0x60FFFFFF),
                width: 2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: isSelected ? Colors.white : const Color(0xFF0B2545)),
              const SizedBox(width: 5),
              Text(title,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color:
                          isSelected ? Colors.white : const Color(0xFF0B2545))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {bool isPassword = false,
      bool? obscureText,
      VoidCallback? onToggleObscure,
      TextInputType? keyboardType,
      List<TextInputFormatter>? inputFormatters,
      int? maxLength}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: isPassword
          ? StatefulBuilder(
              builder: (context, setLocalState) {
                bool localObscure = obscureText ?? true;
                return TextFormField(
                  controller: controller,
                  obscureText: localObscure,
                  keyboardType: keyboardType,
                  inputFormatters: inputFormatters,
                  maxLength: maxLength,
                  decoration: InputDecoration(
                    labelText: label,
                    filled: true,
                    fillColor: const Color(0x20FFFFFF),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0x60FFFFFF)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0x60FFFFFF)),
                    ),
                    labelStyle: const TextStyle(color: Color(0xFF0B2545)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        localObscure ? Icons.visibility_off : Icons.visibility,
                        color: const Color(0xFF0B3C85),
                      ),
                      onPressed: () {
                        if (onToggleObscure != null) onToggleObscure();
                        setLocalState(() {});
                      },
                    ),
                  ),
                  validator: (value) =>
                      value!.isEmpty ? 'Campo requerido' : null,
                );
              },
            )
          : TextFormField(
              controller: controller,
              decoration: InputDecoration(
                labelText: label,
                filled: true,
                fillColor: const Color(0x20FFFFFF),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0x60FFFFFF)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0x60FFFFFF)),
                ),
                labelStyle: const TextStyle(color: Color(0xFF0B2545)),
              ),
              obscureText: false,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              maxLength: maxLength,
              validator: (value) => value!.isEmpty ? 'Campo requerido' : null,
            ),
    );
  }

  Widget _buildRadio(String val) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Radio<String>(
          value: val,
          groupValue: _gender,
          activeColor: const Color(0xFF0056B3),
          onChanged: (newValue) => setState(() => _gender = newValue!),
        ),
        Text(val,
            style: const TextStyle(color: Color(0xFF0B2545), fontSize: 16)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE0EAFC), Color(0xFFCFDEF3), Color(0xFFB3C6DF)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF0056B3)),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(25),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          padding: const EdgeInsets.all(24.0),
                          decoration: BoxDecoration(
                            color: const Color(0x50FFFFFF),
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(
                                color: const Color(0x80FFFFFF), width: 1),
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Image.asset(
                                  'assets/logo.png',
                                  height: 100,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.medical_services,
                                          size: 80, color: Color(0xFF0056B3)),
                                ),
                                const SizedBox(height: 10),
                                const Text('Crear cuenta',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0056B3))),
                                const SizedBox(height: 5),
                                const Text(
                                    'Regístrese en Salud Now para gestionar sus citas',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF475569))),
                                const SizedBox(height: 20),
                                const Text('¿Cómo deseas registrarte?',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0B2545))),
                                const SizedBox(height: 10),
                                Column(
                                  children: [
                                    Row(
                                      children: [
                                        _buildRoleButton('Soy Paciente',
                                            Icons.person, 'patient'),
                                        const SizedBox(width: 5),
                                        _buildRoleButton('Soy Doctor',
                                            Icons.medical_services, 'doctor'),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        _buildRoleButton('Soy una Clínica',
                                            Icons.local_hospital, 'clinic'),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                if (_role != 'clinic') ...[
                                  const Text('Género',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0B2545))),
                                  const SizedBox(height: 10),
                                  Theme(
                                    data: Theme.of(context).copyWith(
                                        unselectedWidgetColor:
                                            const Color(0xFF0B2545)),
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            _buildRadio('Masculino'),
                                            const SizedBox(width: 16),
                                            _buildRadio('Femenino'),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            _buildRadio('Prefiero no decirlo'),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                _buildTextField(
                                    'Correo Electrónico', _emailCtrl,
                                    keyboardType: TextInputType.emailAddress),
                                if (_role == 'clinic') ...[
                                  _buildTextField('Nombre del Centro Médico',
                                      _firstNameCtrl),
                                ] else ...[
                                  _buildTextField('Nombres', _firstNameCtrl),
                                  _buildTextField('Apellidos', _lastNameCtrl),
                                ],
                                _buildTextField(
                                    'Teléfono de Contacto (ej: 04141234567)',
                                    _phoneCtrl,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(11),
                                    ],
                                    maxLength: 11),
                                if (_role == 'doctor') ...[
                                  const SizedBox(height: 10),
                                  Autocomplete<String>(
                                    optionsBuilder:
                                        (TextEditingValue textEditingValue) {
                                      if (textEditingValue.text.isEmpty) {
                                        return _specialtiesList;
                                      }
                                      return _specialtiesList
                                          .where((String option) {
                                        return option.toLowerCase().contains(
                                            textEditingValue.text
                                                .toLowerCase());
                                      });
                                    },
                                    onSelected: (String selection) {
                                      if (_selectedSpecialties.length >= 5 &&
                                          !_selectedSpecialties
                                              .contains(selection)) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: Text(
                                                  'Máximo 5 especialidades permitidas')),
                                        );
                                        return;
                                      }
                                      setState(() =>
                                          _selectedSpecialties.add(selection));
                                    },
                                    fieldViewBuilder: (context, controller,
                                        focusNode, onFieldSubmitted) {
                                      return TextField(
                                        controller: controller,
                                        focusNode: focusNode,
                                        decoration: InputDecoration(
                                          labelText: 'Buscar Especialidad',
                                          filled: true,
                                          fillColor: const Color(0x20FFFFFF),
                                          border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: const BorderSide(
                                                  color: Color(0x60FFFFFF))),
                                          enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: const BorderSide(
                                                  color: Color(0x60FFFFFF))),
                                          labelStyle: const TextStyle(
                                              color: Color(0xFF0B2545)),
                                          suffixIcon: const Icon(Icons.search,
                                              color: Color(0xFF0B2545)),
                                        ),
                                      );
                                    },
                                  ),
                                  if (_selectedSpecialties.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: _selectedSpecialties.map((s) {
                                        return Chip(
                                          label: Text(s,
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11)),
                                          backgroundColor:
                                              const Color(0xFF0056B3),
                                          deleteIconColor: Colors.white,
                                          onDeleted: () => setState(() =>
                                              _selectedSpecialties.remove(s)),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ],
                                const SizedBox(height: 10),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Autocomplete<String>(
                                    optionsBuilder:
                                        (TextEditingValue textEditingValue) {
                                      if (textEditingValue.text.isEmpty) {
                                        return _estadosVE;
                                      }
                                      return _estadosVE.where((String option) {
                                        return option.toLowerCase().contains(
                                            textEditingValue.text
                                                .toLowerCase());
                                      });
                                    },
                                    onSelected: (String selection) {
                                      setState(() => _state = selection);
                                    },
                                    fieldViewBuilder: (context, controller,
                                        focusNode, onFieldSubmitted) {
                                      return TextField(
                                        controller: controller,
                                        focusNode: focusNode,
                                        decoration: InputDecoration(
                                          labelText: 'Buscar Estado',
                                          filled: true,
                                          fillColor: const Color(0x20FFFFFF),
                                          border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: const BorderSide(
                                                  color: Color(0x60FFFFFF))),
                                          enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: const BorderSide(
                                                  color: Color(0x60FFFFFF))),
                                          labelStyle: const TextStyle(
                                              color: Color(0xFF0B2545)),
                                          suffixIcon: const Icon(Icons.search,
                                              color: Color(0xFF0B2545)),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                if (_role == 'clinic') ...[
                                  const SizedBox(height: 10),
                                  _buildTextField(
                                      'Descripción de los servicios ofrecidos',
                                      _clinicDescriptionCtrl),
                                ],
                                _buildTextField(
                                    'Dirección Completa', _addressCtrl),
                                _buildTextField('Contraseña', _passwordCtrl,
                                    isPassword: true,
                                    obscureText: _obscurePassword,
                                    onToggleObscure: () => setState(() =>
                                        _obscurePassword = !_obscurePassword)),
                                _buildTextField(
                                    'Repetir contraseña', _passwordRepeatCtrl,
                                    isPassword: true,
                                    obscureText: _obscureRepeatPassword,
                                    onToggleObscure: () => setState(() =>
                                        _obscureRepeatPassword =
                                            !_obscureRepeatPassword)),
                                const SizedBox(height: 20),
                                ElevatedButton(
                                  onPressed: _isLoading ? null : _register,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0056B3),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                    elevation: 0,
                                  ),
                                  child: _isLoading
                                      ? const CircularProgressIndicator(
                                          color: Colors.white)
                                      : const Text('Registrarse',
                                          style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
