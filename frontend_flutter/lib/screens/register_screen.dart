import 'package:flutter/material.dart';
import 'dart:ui';
import '../core/api_client.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
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

  bool _isLoading = false;

  final List<String> _estadosVE = [
    "Amazonas", "Anzoátegui", "Apure", "Aragua", "Barinas", "Bolívar", "Carabobo", "Cojedes",
    "Delta Amacuro", "Dependencias Federales", "Distrito Capital", "Falcón", "Guárico", "La Guaira", "Lara",
    "Mérida", "Miranda", "Monagas", "Nueva Esparta", "Portuguesa", "Sucre", "Táchira",
    "Trujillo", "Yaracuy", "Zulia"
  ];

  final List<String> _specialtiesList = [
    "Alergología e Inmunología Clínica", "Análisis Clínicos", "Anatomía Patológica", "Anestesiología",
    "Angiología", "Bioquímica Clínica", "Cardiología", "Cirugía Cardiovascular", "Cirugía General",
    "Cirugía Oral y Maxilofacial", "Cirugía Ortopédica", "Cirugía Pediátrica", "Cirugía Plástica, Estética y Reparadora",
    "Cirugía Torácica", "Cirugía Vascular", "Cirugía de la Mano", "Dermatología", "Endocrinología",
    "Farmacología Clínica", "Foniatría / Audiología", "Gastroenterología", "Genética Médica",
    "Geriatría", "Gerontología Médica", "Ginecología y Obstetricia", "Hematología", "Infectología",
    "Inmunología", "Medicina Familiar y Comunitaria (o Medicina General)", "Medicina Física y Rehabilitación",
    "Medicina Intensiva", "Medicina Interna", "Medicina Legal y Forense", "Medicina Nuclear",
    "Medicina Paliativa / Cuidados Paliativos", "Medicina Preventiva y Salud Pública", "Medicina de Emergencias y Urgencias",
    "Medicina del Deporte", "Medicina del Trabajo", "Microbiología y Parasitología", "Nefrología",
    "Neumología", "Neurocirugía", "Neurofisiología Clínica", "Neurología", "Oftalmología",
    "Oncología Médica", "Oncología Radioterápica", "Otorrinolaringología", "Pediatría",
    "Psiquiatría", "Radiodiagnóstico / Radiología", "Reumatología", "Traumatología",
    "Urología", "Áreas de Laboratorio y Soporte Técnico"
  ];
  final Set<String> _selectedSpecialties = {};

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_state == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, selecciona un estado.')));
      return;
    }

    if (_passwordCtrl.text != _passwordRepeatCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Las contraseñas no coinciden.')));
      return;
    }

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
        "specialties": _selectedSpecialties.toList()
      };

      final response = await ApiClient.post('/auth/register', payload);

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Cuenta creada exitosamente!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al registrar. Verifica los datos o si el correo ya existe.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
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
            border: Border.all(color: isSelected ? const Color(0xFF0056B3) : const Color(0x60FFFFFF), width: 2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: isSelected ? Colors.white : const Color(0xFF0B2545)),
              const SizedBox(width: 5),
              Text(
                title, 
                style: TextStyle(
                  fontWeight: FontWeight.bold, 
                  fontSize: 12, 
                  color: isSelected ? Colors.white : const Color(0xFF0B2545)
                )
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool isPassword = false, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
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
        obscureText: isPassword,
        keyboardType: keyboardType,
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
        Text(val, style: const TextStyle(color: Color(0xFF0B2545), fontSize: 16)),
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
                            border: Border.all(color: const Color(0x80FFFFFF), width: 1),
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Image.asset(
                                  'assets/logo.png',
                                  height: 100,
                                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.medical_services, size: 80, color: Color(0xFF0056B3)),
                                ),
                                const SizedBox(height: 10),
                                const Text('Crear cuenta', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF0056B3))),
                                const SizedBox(height: 5),
                                const Text('Regístrese en Salud Now para gestionar sus citas', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Color(0xFF475569))),
                                const SizedBox(height: 20),
                                const Text('¿Cómo deseas registrarte?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0B2545))),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    _buildRoleButton('Soy Paciente', Icons.person, 'patient'),
                                    const SizedBox(width: 10),
                                    _buildRoleButton('Soy Doctor', Icons.medical_services, 'doctor'),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                const Text('Género', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0B2545))),
                                const SizedBox(height: 10),
                                Theme(
                                  data: Theme.of(context).copyWith(unselectedWidgetColor: const Color(0xFF0B2545)),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          _buildRadio('Masculino'),
                                          const SizedBox(width: 16),
                                          _buildRadio('Femenino'),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          _buildRadio('Prefiero no decirlo'),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _buildTextField('Correo Electrónico', _emailCtrl, keyboardType: TextInputType.emailAddress),
                                _buildTextField('Nombres', _firstNameCtrl),
                                _buildTextField('Apellidos', _lastNameCtrl),
                                _buildTextField('Teléfono (ej: 04141234567)', _phoneCtrl, keyboardType: TextInputType.phone),
                                
                                if (_role == 'doctor') ...[
                                  const SizedBox(height: 10),
                                  Autocomplete<String>(
                                    optionsBuilder: (TextEditingValue textEditingValue) {
                                      if (textEditingValue.text.isEmpty) {
                                        return _specialtiesList;
                                      }
                                      return _specialtiesList.where((String option) {
                                        return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                                      });
                                    },
                                    onSelected: (String selection) {
                                      if (_selectedSpecialties.length >= 5 && !_selectedSpecialties.contains(selection)) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Máximo 5 especialidades permitidas')),
                                        );
                                        return;
                                      }
                                      setState(() => _selectedSpecialties.add(selection));
                                    },
                                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                      return TextField(
                                        controller: controller,
                                        focusNode: focusNode,
                                        decoration: InputDecoration(
                                          labelText: 'Buscar Especialidad',
                                          filled: true,
                                          fillColor: const Color(0x20FFFFFF),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0x60FFFFFF))),
                                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0x60FFFFFF))),
                                          labelStyle: const TextStyle(color: Color(0xFF0B2545)),
                                          suffixIcon: const Icon(Icons.search, color: Color(0xFF0B2545)),
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
                                          label: Text(s, style: const TextStyle(color: Colors.white, fontSize: 11)),
                                          backgroundColor: const Color(0xFF0056B3),
                                          deleteIconColor: Colors.white,
                                          onDeleted: () => setState(() => _selectedSpecialties.remove(s)),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ],
                                
                                const SizedBox(height: 10),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Autocomplete<String>(
                                    optionsBuilder: (TextEditingValue textEditingValue) {
                                      if (textEditingValue.text.isEmpty) {
                                        return _estadosVE;
                                      }
                                      return _estadosVE.where((String option) {
                                        return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                                      });
                                    },
                                    onSelected: (String selection) {
                                      setState(() => _state = selection);
                                    },
                                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                      return TextField(
                                        controller: controller,
                                        focusNode: focusNode,
                                        decoration: InputDecoration(
                                          labelText: 'Buscar Estado',
                                          filled: true,
                                          fillColor: const Color(0x20FFFFFF),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0x60FFFFFF))),
                                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0x60FFFFFF))),
                                          labelStyle: const TextStyle(color: Color(0xFF0B2545)),
                                          suffixIcon: const Icon(Icons.search, color: Color(0xFF0B2545)),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                _buildTextField('Dirección', _addressCtrl),
                                _buildTextField('Contraseña', _passwordCtrl, isPassword: true),
                                _buildTextField('Repetir contraseña', _passwordRepeatCtrl, isPassword: true),
                                const SizedBox(height: 20),
                                ElevatedButton(
                                  onPressed: _isLoading ? null : _register,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0056B3),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    elevation: 0,
                                  ),
                                  child: _isLoading 
                                    ? const CircularProgressIndicator(color: Colors.white)
                                    : const Text('Registrarse', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
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
