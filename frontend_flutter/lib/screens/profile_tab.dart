import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/api_client.dart';
import '../core/auth_helper.dart';
import '../core/profile_image_helper.dart';
import '../models/avatar_catalog.dart';
import '../models/ve_catalogs.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/avatar_sprite.dart';
import 'login_screen.dart';

const _privacyText =
    'Recolectamos datos de contacto y el motivo de la cita registrado por el usuario, como consulta o entrega de exámenes, para gestionar la agenda y mejorar la plataforma. No manejamos información médica detallada o diagnósticos. Sus datos están protegidos y no se comparten sin su consentimiento, y el usuario tiene el derecho de acceder, modificar o eliminar su información en cualquier momento.';
const _termsText =
    'El uso de esta aplicación implica la aceptación de todas las normas y condiciones descritas. El usuario es responsable de garantizar la veracidad de su información y mantener la seguridad de su cuenta. No nos hacemos responsables por la calidad del servicio médico ni por interrupciones en el sistema.';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final _address = TextEditingController();
  final _fee = TextEditingController();
  final _bio = TextEditingController();

  Map<String, dynamic>? _userData;
  List<String> _specialties = [];
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isVip = false;
  bool _isClinicVip = false;

  bool get _isDoctor => _userData?['role'] == 'doctor';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _address.dispose();
    _fee.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      final userResponse = await ApiClient.get('/users/me');
      if (userResponse.statusCode != 200) {
        throw Exception('No se pudo cargar el perfil');
      }
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
      } else if (user['role'] == 'clinic') {
        final subResp = await ApiClient.get('/subscriptions/me');
        if (subResp.statusCode == 200) {
          final sub = jsonDecode(subResp.body) as Map<String, dynamic>;
          final plan = sub['current']?['plan']?.toString() ?? '';
          if (mounted) {
            setState(() => _isClinicVip = plan == 'clinic_vip' || plan == 'vip');
          }
        }
      }
      if (!mounted) return;
      _address.text = user['address']?.toString() ?? '';
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

  Future<void> _chooseAvatar() async {
    final role = AvatarCatalog.normalizeRole(_userData?['role']?.toString());
    final current = AvatarCatalog.parse(_userData?['avatar_url']?.toString());
    final index = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      builder: (context) => _AvatarPickerSheet(
        role: role,
        selectedIndex: current?.role == role ? current?.index : null,
      ),
    );
    if (index == null || !mounted) return;

    final avatarUrl = AvatarCatalog.presetUrl(role, index);
    setState(() => _isSaving = true);
    try {
      final response = await ApiClient.put(
        '/users/me',
        {'avatar_url': avatarUrl},
      );
      if (response.statusCode != 200) {
        throw Exception('El servidor no pudo guardar el avatar.');
      }
      if (!mounted) return;
      setState(() => _userData = {...?_userData, 'avatar_url': avatarUrl});
      ProfileImageHelper.updateCurrentUserAvatar(avatarUrl);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Avatar de perfil actualizado.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar el avatar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _open(String title, Widget page) {
    Navigator.of(context)
        .push(PageRouteBuilder<void>(
      pageBuilder: (_, animation, __) => page,
      transitionsBuilder: (_, animation, __, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(0.08, 0), end: Offset.zero)
            .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: FadeTransition(opacity: animation, child: child),
      ),
    ))
        .then((_) {
      if (mounted) _fetchData();
    });
  }

  Widget _menuRow(String title, VoidCallback onTap) => ListTile(
        title: Text(title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
        shape: const Border(bottom: BorderSide(color: Color(0x220B2545))),
      );

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
                fallbackRole: _userData?['role']?.toString() ?? 'patient',
                size: 120,
                borderColor: (_isDoctor && _isVip) || _isClinicVip
                    ? const Color(0xFFD7AF48)
                    : const Color(0xFF0056B3),
                borderWidth: 4,
              ),
            ),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: _isSaving ? null : _pickImage,
                  icon: const Icon(Icons.cloud_upload),
                  label: const Text('Subir foto'),
                ),
                TextButton.icon(
                  onPressed: _isSaving ? null : _chooseAvatar,
                  icon: const Icon(Icons.face_retouching_natural),
                  label: const Text('Elegir avatar'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const SizedBox(height: 18),
            _menuRow(
                'Tus Datos',
                () => _open(
                    'Tus Datos',
                    _ProfileMenu(title: 'Tus Datos', children: [
                      _menuRow(
                          'Información Personal',
                          () => _open('Información Personal',
                              _PersonalInfoPage(user: _userData ?? const {}))),
                      _menuRow(
                          'Mis Direcciones',
                          () => _open('Mis Direcciones',
                              _AddressPage(user: _userData ?? const {}))),
                    ]))),
            if (_isDoctor)
              _menuRow(
                  'Datos Laborales',
                  () => _open(
                      'Datos Laborales',
                      _DoctorDataPage(doctor: {
                        'bio': _bio.text,
                        'consultation_fee': _fee.text,
                        'specialties': _specialties,
                        'clinic_info': _address.text
                      }))),
            if (_userData?['role'] == 'clinic')
              _menuRow(
                  'Datos de la clínica',
                  () => _open('Datos de la clínica',
                      _ClinicDataPage(user: _userData ?? const {}))),
            _menuRow('Seguridad de tu cuenta',
                () => _open('Seguridad de tu cuenta', const _SecurityPage())),
            _menuRow(
                'Acerca de Salud Now',
                () => _open('Acerca de Salud Now',
                    _AboutPage(onOpen: _open, menuRow: _menuRow))),
          ],
        ),
      ),
    );
  }
}

class _AvatarPickerSheet extends StatelessWidget {
  const _AvatarPickerSheet({required this.role, this.selectedIndex});

  final String role;
  final int? selectedIndex;

  @override
  Widget build(BuildContext context) {
    final title = switch (role) {
      'doctor' => 'Avatares para doctores',
      'assistant' => 'Avatares para asistentes',
      'clinic' => 'Avatares para clínicas',
      _ => 'Avatares para pacientes',
    };

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.76,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0B2545),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Text('Selecciona una imagen para tu perfil.'),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              itemCount: AvatarCatalog.countForRole(role),
              itemBuilder: (context, index) {
                final isSelected = selectedIndex == index;
                return Semantics(
                  button: true,
                  label: 'Avatar ${index + 1}',
                  selected: isSelected,
                  child: InkWell(
                    onTap: () => Navigator.pop(context, index),
                    customBorder: const CircleBorder(),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF0056B3)
                              : const Color(0xFFE0EAFC),
                          width: isSelected ? 3 : 1,
                        ),
                      ),
                      child: ClipOval(
                        child: AvatarSprite(
                          role: role,
                          index: index,
                          size: double.infinity,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileMenu extends StatelessWidget {
  const _ProfileMenu({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) =>
      _SettingsPage(title: title, children: children);
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title), backgroundColor: Colors.transparent),
        body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            children: children),
      );
}

class _PersonalInfoPage extends StatefulWidget {
  const _PersonalInfoPage({required this.user});
  final Map<String, dynamic> user;
  @override
  State<_PersonalInfoPage> createState() => _PersonalInfoPageState();
}

class _PersonalInfoPageState extends State<_PersonalInfoPage> {
  late final name =
      TextEditingController(text: widget.user['first_name']?.toString());
  late final surname =
      TextEditingController(text: widget.user['last_name']?.toString());
  late final phone =
      TextEditingController(text: widget.user['phone']?.toString());
  bool saving = false;
  @override
  Widget build(BuildContext context) =>
      _SettingsPage(title: 'Información Personal', children: [
        _field('Nombres', name),
        _field('Apellidos', surname),
        _field('Teléfono de contacto', phone, type: TextInputType.phone),
        _field('Correo electrónico',
            TextEditingController(text: widget.user['email']?.toString()),
            enabled: false),
        FilledButton(
            onPressed: saving
                ? null
                : () async {
                    setState(() => saving = true);
                    final response = await ApiClient.put('/users/me', {
                      'first_name': name.text.trim(),
                      'last_name': surname.text.trim(),
                      'phone': phone.text.trim()
                    });
                    if (context.mounted) {
                      setState(() => saving = false);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(response.statusCode == 200
                              ? 'Información guardada.'
                              : 'No se pudo guardar.')));
                    }
                  },
            child: const Text('Guardar cambios')),
      ]);
}

class _AddressPage extends StatefulWidget {
  const _AddressPage({required this.user});
  final Map<String, dynamic> user;
  @override
  State<_AddressPage> createState() => _AddressPageState();
}

class _AddressPageState extends State<_AddressPage> {
  late String? _selectedState = veStates.contains(widget.user['state'])
      ? widget.user['state']?.toString()
      : null;
  late final address =
      TextEditingController(text: widget.user['address']?.toString());
  @override
  Widget build(BuildContext context) =>
      _SettingsPage(title: 'Mis Direcciones', children: [
        DropdownButtonFormField<String>(
          initialValue: _selectedState,
          decoration: const InputDecoration(
              labelText: 'Estado', border: OutlineInputBorder()),
          items: veStates
              .map(
                  (value) => DropdownMenuItem(value: value, child: Text(value)))
              .toList(),
          onChanged: (value) => setState(() => _selectedState = value),
        ),
        _field('Dirección', address, lines: 3),
        FilledButton(
            onPressed: () async {
              final r = await ApiClient.put('/users/me',
                  {'state': _selectedState, 'address': address.text.trim()});
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(r.statusCode == 200
                        ? 'Dirección guardada.'
                        : 'No se pudo guardar.')));
              }
            },
            child: const Text('Guardar cambios')),
      ]);
}

class _DoctorDataPage extends StatefulWidget {
  const _DoctorDataPage({required this.doctor});
  final Map<String, dynamic> doctor;
  @override
  State<_DoctorDataPage> createState() => _DoctorDataPageState();
}

class _DoctorDataPageState extends State<_DoctorDataPage> {
  final TextEditingController _specialtySearch = TextEditingController();
  late final bio =
      TextEditingController(text: widget.doctor['bio']?.toString());
  late final fee = TextEditingController(
      text: widget.doctor['consultation_fee']?.toString());
  late final location =
      TextEditingController(text: widget.doctor['clinic_info']?.toString());
  late List<String> specialties =
      (widget.doctor['specialties'] as List? ?? const [])
          .map((value) => value.toString())
          .toSet()
          .take(5)
          .toList();

  @override
  void dispose() {
    _specialtySearch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _SettingsPage(title: 'Datos Laborales', children: [
        _field('Biografía', bio, lines: 4),
        Autocomplete<String>(
          textEditingController: _specialtySearch,
          optionsBuilder: (value) => medicalSpecialties.where((item) =>
              item.toLowerCase().contains(value.text.trim().toLowerCase()) &&
              !specialties.contains(item)),
          onSelected: (value) {
            _specialtySearch.clear();
            if (specialties.length >= 5) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Máximo 5 especialidades permitidas')));
              return;
            }
            setState(() => specialties.add(value));
          },
          fieldViewBuilder: (context, controller, focusNode, onSubmitted) =>
              TextField(
            controller: controller,
            focusNode: focusNode,
            decoration: const InputDecoration(
              labelText: 'Buscar especialidad',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (specialties.isNotEmpty)
          Wrap(
            spacing: 8,
            children: specialties
                .map((specialty) => Chip(
                      label: Text(specialty),
                      onDeleted: () =>
                          setState(() => specialties.remove(specialty)),
                    ))
                .toList(),
          ),
        const SizedBox(height: 16),
        _field('Precio de la consulta', fee,
            type: const TextInputType.numberWithOptions(decimal: true)),
        _field('Ubicación de consultorio', location, lines: 2),
        FilledButton(
            onPressed: () async {
              final r = await ApiClient.put('/doctors/me', {
                'bio': bio.text.trim(),
                'consultation_fee':
                    double.tryParse(fee.text.replaceAll(',', '.')),
                'clinic_info': location.text.trim(),
                'specialties': specialties
              });
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(r.statusCode == 200
                        ? 'Datos laborales guardados.'
                        : 'No se pudieron guardar.')));
              }
            },
            child: const Text('Guardar cambios')),
      ]);
}

class _ClinicDataPage extends StatefulWidget {
  const _ClinicDataPage({required this.user});
  final Map<String, dynamic> user;
  @override
  State<_ClinicDataPage> createState() => _ClinicDataPageState();
}

class _ClinicDataPageState extends State<_ClinicDataPage> {
  late final description = TextEditingController();
  late final location =
      TextEditingController(text: widget.user['address']?.toString());
  late final specialties = TextEditingController();
  late final phone2 = TextEditingController();
  late final phone =
      TextEditingController(text: widget.user['phone']?.toString());
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await ApiClient.get('/clinics/me');
    if (r.statusCode == 200) {
      final d = Map<String, dynamic>.from(jsonDecode(r.body));
      description.text = d['description']?.toString() ?? '';
      specialties.text = (d['specialties'] as List? ?? []).join(', ');
      phone2.text = d['contact_phone_2']?.toString() ?? '';
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) =>
      _SettingsPage(title: 'Datos de la clínica', children: [
        _field('Descripción', description, lines: 4),
        _field('Ubicación', location, lines: 2),
        _field('Especialidades (separadas por coma)', specialties),
        _field('Número de contacto', phone, type: TextInputType.phone),
        _field('Segundo número de contacto', phone2, type: TextInputType.phone),
        FilledButton(
            onPressed: () async {
              final u = await ApiClient.put('/users/me', {
                'address': location.text.trim(),
                'phone': phone.text.trim()
              });
              final c = await ApiClient.put('/clinics/me', {
                'description': description.text.trim(),
                'specialties': specialties.text
                    .split(',')
                    .map((v) => v.trim())
                    .where((v) => v.isNotEmpty)
                    .toList(),
                'contact_phone_2': phone2.text.trim()
              });
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(u.statusCode == 200 && c.statusCode == 200
                        ? 'Datos guardados.'
                        : 'No se pudieron guardar los datos.')));
              }
            },
            child: const Text('Guardar cambios')),
      ]);
}

class _SecurityPage extends StatelessWidget {
  const _SecurityPage();
  @override
  Widget build(BuildContext context) =>
      _SettingsPage(title: 'Seguridad de tu cuenta', children: [
        ListTile(
            title: const Text('Cambiar contraseña'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const _ChangePasswordPage())))
      ]);
}

class _ChangePasswordPage extends StatefulWidget {
  const _ChangePasswordPage();
  @override
  State<_ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<_ChangePasswordPage> {
  final current = TextEditingController(),
      next = TextEditingController(),
      repeat = TextEditingController();
  bool busy = false;
  @override
  Widget build(BuildContext context) =>
      _SettingsPage(title: 'Cambiar contraseña', children: [
        _field('Contraseña actual', current, secret: true),
        _field('Nueva contraseña', next, secret: true),
        _field('Repetir nueva contraseña', repeat, secret: true),
        const Text(
            'Debe tener al menos 6 caracteres, letras, números y una mayúscula.'),
        FilledButton(
            onPressed: busy
                ? null
                : () async {
                    final p = next.text;
                    if (p != repeat.text ||
                        p.length < 6 ||
                        !RegExp(r'[A-Z]').hasMatch(p) ||
                        !RegExp(r'[a-zA-Z]').hasMatch(p) ||
                        !RegExp(r'[0-9]').hasMatch(p)) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text(
                              'La nueva contraseña no cumple los requisitos o no coincide.')));
                      return;
                    }
                    setState(() => busy = true);
                    final r = await ApiClient.put('/users/me/password',
                        {'current_password': current.text, 'new_password': p});
                    if (context.mounted) {
                      setState(() => busy = false);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(r.statusCode == 200
                              ? 'Contraseña actualizada.'
                              : 'La contraseña actual es incorrecta.')));
                    }
                  },
            child: const Text('Actualizar contraseña')),
      ]);
}

class _AboutPage extends StatelessWidget {
  const _AboutPage({required this.onOpen, required this.menuRow});
  final void Function(String, Widget) onOpen;
  final Widget Function(String, VoidCallback) menuRow;
  @override
  Widget build(BuildContext context) =>
      _SettingsPage(title: 'Acerca de Salud Now', children: [
        const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Preferencia de Datos',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
        menuRow(
            'Política de Privacidad',
            () => onOpen(
                'Política de Privacidad',
                const _TextPage(
                    title: 'Política de Privacidad', text: _privacyText))),
        menuRow(
            'Cookies',
            () => onOpen(
                'Cookies',
                const _TextPage(
                    title: 'Cookies',
                    text: 'Esta opción aún no está configurada.'))),
        const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Información Legal',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
        menuRow(
            'Términos y Condiciones',
            () => onOpen(
                'Términos y Condiciones',
                const _TextPage(
                    title: 'Términos y Condiciones', text: _termsText))),
        ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('Eliminar Cuenta de Salud Now',
                style: TextStyle(color: Colors.red)),
            onTap: () => _confirmDelete(context)),
      ]);
  Future<void> _confirmDelete(BuildContext context) async {
    final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text('Eliminar cuenta'),
                content: const Text(
                    'Se eliminarán tus datos personales, tus chats de soporte y todas tus citas agendadas. ¿Continuar?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Cancelar')),
                  TextButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Eliminar'))
                ]));
    if (yes == true) {
      final r = await ApiClient.delete('/users/me');
      if (r.statusCode == 200) {
        await AuthHelper.logout(preserveBiometricToken: false);
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
            MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
            (_) => false,
          );
        }
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(r.statusCode == 200
                ? 'Cuenta eliminada.'
                : 'No se pudo eliminar la cuenta.')));
      }
    }
  }
}

class _TextPage extends StatelessWidget {
  const _TextPage({required this.title, required this.text});
  final String title, text;
  @override
  Widget build(BuildContext context) => _SettingsPage(title: title, children: [
        Padding(
            padding: const EdgeInsets.all(12),
            child:
                Text(text, style: const TextStyle(fontSize: 16, height: 1.55)))
      ]);
}

Widget _field(String label, TextEditingController controller,
        {TextInputType? type,
        int lines = 1,
        bool secret = false,
        bool enabled = true}) =>
    Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextField(
            controller: controller,
            keyboardType: type,
            maxLines: secret ? 1 : lines,
            obscureText: secret,
            enabled: enabled,
            decoration: InputDecoration(
                labelText: label, border: const OutlineInputBorder())));
