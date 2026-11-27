import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import '../core/api_client.dart';
import '../core/auth_helper.dart';
import '../core/identity_document.dart';
import '../core/profile_image_helper.dart';
import '../models/avatar_catalog.dart';
import '../models/ve_catalogs.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/avatar_sprite.dart';
import '../widgets/settings_ui.dart';
import '../core/health_module_helper.dart';
import '../core/distribution_config.dart';
import 'health_tab.dart';
import 'login_screen.dart';
import 'legal_screens.dart';
import 'select_plan_screen.dart';
import 'doctor_pricing_screen.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final _address = TextEditingController();
  final _bio = TextEditingController();
  final _clinicInfo = TextEditingController();

  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _subData;
  List<String> _specialties = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _medicalLicenseNumber;
  int _yearsExperience = 0;
  int? _doctorId;

  bool get _isDoctor => _userData?['role'] == 'doctor';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _address.dispose();
    _bio.dispose();
    _clinicInfo.dispose();
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
      if (user['role'] == 'doctor') {
        final response = await ApiClient.get('/doctors/me');
        if (response.statusCode == 200) {
          doctor = Map<String, dynamic>.from(jsonDecode(response.body));
          final doctorId = int.tryParse(doctor['id']?.toString() ?? '');
          if (doctorId != null) {
            final prefs = await SharedPreferences.getInstance();
            final cacheKey = 'doctor_years_experience_$doctorId';
            final locallySavedExperience = prefs.getInt(cacheKey);
            final serverExperience =
                (doctor['years_experience'] as num?)?.toInt() ?? 0;
            if (locallySavedExperience != null &&
                locallySavedExperience == serverExperience) {
              await prefs.remove(cacheKey);
            } else if (locallySavedExperience != null) {
              doctor['years_experience'] = locallySavedExperience;
            }
          }
        }
      }
      if (!mounted) return;
      _address.text = user['address']?.toString() ?? '';
      _bio.text = doctor?['bio']?.toString() ?? '';
      _clinicInfo.text = doctor?['clinic_info']?.toString() ?? '';
      _specialties =
          List<String>.from(doctor?['specialties'] ?? const <String>[]);
      _medicalLicenseNumber = doctor?['medical_license_number']?.toString();
      _yearsExperience = (doctor?['years_experience'] as num?)?.toInt() ?? 0;
      _doctorId = int.tryParse(doctor?['id']?.toString() ?? '');
      ProfileImageHelper.updateCurrentUserAvatar(
          user['avatar_url']?.toString());

      Map<String, dynamic>? subData;
      try {
        final subResp = await ApiClient.get('/subscriptions/me');
        if (subResp.statusCode == 200) {
          subData = jsonDecode(subResp.body) as Map<String, dynamic>?;
        }
      } catch (_) {}

      setState(() {
        _userData = user;
        _subData = subData;
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

  void _open(String title, Widget page, {VoidCallback? onSuccess}) {
    Navigator.of(context)
        .push(PageRouteBuilder<Object?>(
      pageBuilder: (_, animation, __) => page,
      transitionsBuilder: (_, animation, __, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(0.08, 0), end: Offset.zero)
            .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: FadeTransition(opacity: animation, child: child),
      ),
    ))
        .then((success) {
      if (!mounted) return;
      if (success == true) onSuccess?.call();
      _fetchData();
    });
  }

  Widget _menuRow(String title, VoidCallback onTap,
          {IconData? icon, String? subtitle}) =>
      ListTile(
        leading: icon != null
            ? Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0756A4).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFF0756A4), size: 20),
              )
            : null,
        title: Text(title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        subtitle: subtitle != null
            ? Text(subtitle,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))
            : null,
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
                displayName:
                    '${_userData?['first_name'] ?? ''} ${_userData?['last_name'] ?? ''}'
                        .trim(),
                subtitle: _userData?['role'] == 'doctor'
                    ? 'Médico'
                    : (_userData?['role'] == 'clinic'
                        ? 'Clínica'
                        : (_userData?['role'] == 'admin'
                            ? 'Administrador'
                            : 'Paciente')),
                size: 120,
                borderColor: const Color(0xFF0056B3),
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
                      const SettingsBanner(
                        icon: Icons.manage_accounts_rounded,
                        title: 'Administra tu información',
                        subtitle:
                            'Mantén actualizados tus datos personales y direcciones de contacto.',
                      ),
                      const SizedBox(height: 16),
                      SettingsCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        child: Column(
                          children: [
                            _menuRow(
                              'Información Personal',
                              () => _open(
                                  'Información Personal',
                                  _PersonalInfoPage(
                                      user: _userData ?? const {})),
                              icon: Icons.person_outline_rounded,
                              subtitle:
                                  'Nombre, contacto, fecha de nacimiento y WhatsApp',
                            ),
                            _menuRow(
                              'Mis Direcciones',
                              () => _open('Mis Direcciones',
                                  _AddressPage(user: _userData ?? const {})),
                              icon: Icons.location_on_outlined,
                              subtitle: 'Estado y dirección de residencia',
                            ),
                          ],
                        ),
                      ),
                    ]))),
            _menuRow(
              'Módulo de Salud',
              () => _open('Módulo de Salud', const HealthTab()),
              icon: Icons.health_and_safety_rounded,
              subtitle: kIsWeb
                  ? 'Estatura, peso, IMC, hidratación y respiración'
                  : 'Estatura, peso, IMC, hidratación, respiración y pasos',
            ),
            if (_isDoctor)
              _menuRow(
                  'Datos Laborales',
                  () => _open(
                      'Datos Laborales',
                      _DoctorDataPage(doctor: {
                        'bio': _bio.text,
                        'specialties': _specialties,
                        'clinic_info': _clinicInfo.text,
                        'medical_license_number': _medicalLicenseNumber,
                        'years_experience': _yearsExperience,
                        'id': _doctorId,
                      }))),
            if (_isDoctor)
              _menuRow(
                'Tarifas y ofertas',
                () => _open('Tarifas y ofertas', const DoctorPricingScreen()),
                icon: Icons.sell_outlined,
              ),
            if (_userData?['role'] == 'clinic')
              _menuRow(
                  'Datos de la clínica',
                  () => _open('Datos de la clínica',
                      _ClinicDataPage(user: _userData ?? const {}))),
            _menuRow('Seguridad de tu cuenta',
                () => _open(
                      'Seguridad de tu cuenta',
                      const _SecurityPage(),
                      onSuccess: () {
                        ScaffoldMessenger.of(context)
                          ..clearSnackBars()
                          ..showSnackBar(const SnackBar(
                            content: Text('Contraseña cambiada con éxito'),
                          ));
                      },
                    )),
            _menuRow(
                'Acerca de Salud Now',
                () => _open('Acerca de Salud Now',
                    _AboutPage(onOpen: _open, menuRow: _menuRow))),
            if ((_userData?['role'] == 'doctor' || _userData?['role'] == 'clinic') && _subData != null) ...[
              const SizedBox(height: 18),
              _buildSubscriptionCard(),
              const SizedBox(height: 18),
            ],
          ],
        ),
      ),
    );
  }

  int _getDaysRemaining() {
    final endDate =
        DateTime.tryParse(_subData?['current']?['end_date']?.toString() ?? '');
    if (endDate == null) return 0;
    final today = caracasNow();
    final end = endDate.toLocal();
    final days = DateTime(end.year, end.month, end.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
    return days > 0 ? days : 0;
  }

  int _getGraceDaysRemaining() {
    final graceDate = DateTime.tryParse(
        _subData?['current']?['grace_end_date']?.toString() ?? '');
    if (graceDate == null) return 0;
    final today = caracasNow();
    final grace = graceDate.toLocal();
    final days = DateTime(grace.year, grace.month, grace.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
    return days > 0 ? days : 0;
  }

  Widget _buildSubscriptionCard() {
    final hasCurrent = _subData?['current'] != null;
    final isGrace = _subData?['current']?['status'] == 'grace_period';
    final rawPlan = _subData?['current']?['plan'] ?? 'none';
    final displayPlan = !hasCurrent
        ? 'Sin suscripción (Vencida)'
        : isGrace
            ? (rawPlan == 'sponsored'
                ? 'VIP (Período de gracia)'
                : rawPlan == 'featured'
                    ? 'Destacado (Período de gracia)'
                    : rawPlan == 'basic'
                        ? 'Básico (Período de gracia)'
                        : 'Período de gracia')
            : rawPlan == 'sponsored'
                ? 'VIP'
                : rawPlan == 'basic'
                    ? 'Básico'
                    : rawPlan == 'featured'
                        ? 'Destacado'
                        : rawPlan == 'clinic_vip'
                            ? 'VIP de Clínica'
                            : rawPlan == 'clinic_basic'
                                ? 'Básico de Clínica'
                                : rawPlan;
    final isClinicMember = _subData?['is_clinic_member'] == true;
    final cardBorderColor = !hasCurrent
        ? const Color(0xFFDC2626)
        : isGrace
            ? const Color(0xFFD97706)
            : const Color(0xFF0056B3);
    final buttonColor = !hasCurrent
        ? const Color(0xFFDC2626)
        : isGrace
            ? const Color(0xFFD97706)
            : const Color(0xFF0056B3);

    final buttonLabel = !hasCurrent
        ? 'Activar o Renovar Suscripción'
        : isGrace
            ? 'Renovar Plan (Quedan ${_getGraceDaysRemaining()} días de gracia)'
            : 'Renovar o Cambiar Plan (Quedan ${_getDaysRemaining()} días)';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: cardBorderColor.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Mi Suscripción',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0B2545),
                ),
              ),
              Icon(
                !hasCurrent
                    ? Icons.warning_amber_rounded
                    : isGrace
                        ? Icons.timer_outlined
                        : Icons.star_rounded,
                color: cardBorderColor,
                size: 24,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isClinicMember
                ? 'Plan activo: $displayPlan · ${_getDaysRemaining()} días restantes'
                : 'Plan Actual: $displayPlan',
            style: TextStyle(
              fontSize: 15,
              fontWeight: (!hasCurrent || isGrace) ? FontWeight.w600 : FontWeight.normal,
              color: (!hasCurrent || isGrace) ? cardBorderColor : const Color(0xFF475569),
            ),
          ),
          if (!isClinicMember && hasCurrent) ...[
            const SizedBox(height: 6),
            Text(
              isGrace
                  ? 'Venció: ${_subData?['current']?['end_date']?.toString().split('T')[0] ?? '--'} (Período de gracia de 3 días activo)'
                  : 'Vence: ${_subData?['current']?['end_date']?.toString().split('T')[0] ?? '--'}',
              style: TextStyle(
                fontSize: 14,
                color: isGrace ? const Color(0xFFD97706) : const Color(0xFF64748B),
                fontWeight: isGrace ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
          if (!isGooglePlayBuild && !isClinicMember) ...[
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () {
                  if (_userData != null) {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => SelectPlanScreen(
                            doctorData: _userData!, isRenewal: true)));
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text(
                  buttonLabel,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
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
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF0056B3)
                              : const Color(0xFFE0EAFC),
                          width: isSelected ? 3 : 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
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
  Widget build(BuildContext context) => SettingsScaffold(
        title: title,
        children: children,
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
  late final _docController = TextEditingController(
      text: formatIdentityDocument(widget.user['identity_document']));
  late final _emailController =
      TextEditingController(text: widget.user['email']?.toString());
  bool saving = false;
  late bool showWhatsapp = widget.user['show_whatsapp'] != false;
  late DateTime? birthDate =
      DateTime.tryParse(widget.user['birth_date']?.toString() ?? '');

  @override
  void dispose() {
    name.dispose();
    surname.dispose();
    phone.dispose();
    _docController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  int? get _age {
    final value = birthDate;
    if (value == null) return null;
    final today = DateTime.now();
    final beforeBirthday = today.month < value.month ||
        (today.month == value.month && today.day < value.day);
    return today.year - value.year - (beforeBirthday ? 1 : 0);
  }

  Future<void> _pickBirthDate() async {
    final today = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: birthDate ?? DateTime(today.year - 18, today.month, today.day),
      firstDate: DateTime(1900),
      lastDate: today,
      helpText: 'Fecha de nacimiento',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF0056B3),
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (selected != null) setState(() => birthDate = selected);
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.user['role']?.toString();
    final showBirthDate = role == 'patient' || role == 'doctor';

    return _SettingsPage(title: 'Información Personal', children: [
      const SettingsBanner(
        icon: Icons.badge_rounded,
        title: 'Tus datos personales',
        subtitle:
            'Mantén al día tu nombre, teléfono y datos de identificación en Salud Now.',
      ),
      const SizedBox(height: 16),
      SettingsCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SettingsSectionHeader(
              icon: Icons.person_rounded,
              iconColor: Color(0xFF0056B3),
              iconBg: Color(0xFFE0EAFC),
              title: 'Identidad y contacto',
              subtitle: 'Información principal vinculada a tu cuenta.',
            ),
            const SizedBox(height: 18),
            _field('Nombres', name,
                maxLength: 60, icon: Icons.person_outline_rounded),
            _field('Apellidos', surname,
                maxLength: 60, icon: Icons.person_outline_rounded),
            _field('Cédula / RIF', _docController,
                enabled: false, icon: Icons.credit_card_rounded),
            _field('Teléfono de contacto', phone,
                type: TextInputType.phone, icon: Icons.phone_outlined),
            _field('Correo electrónico', _emailController,
                enabled: false, icon: Icons.email_outlined),
          ],
        ),
      ),
      if (showBirthDate) ...[
        const SizedBox(height: 16),
        SettingsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SettingsSectionHeader(
                icon: Icons.cake_rounded,
                iconColor: Color(0xFFDB2777),
                iconBg: Color(0xFFFCE7F3),
                title: 'Fecha de nacimiento',
                subtitle: 'Nos ayuda a personalizar tu atención médica.',
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: saving ? null : _pickBirthDate,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F9FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFBAE6FD)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cake_outlined,
                          color: Color(0xFF0056B3), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Fecha seleccionada',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              birthDate == null
                                  ? 'Seleccionar fecha de nacimiento'
                                  : '${birthDate!.day.toString().padLeft(2, '0')}/${birthDate!.month.toString().padLeft(2, '0')}/${birthDate!.year}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0B2545),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_age != null)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0EAFC),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$_age años',
                            style: const TextStyle(
                              color: Color(0xFF0056B3),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0056B3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          birthDate == null ? 'Elegir' : 'Cambiar',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
      if (role == 'doctor') ...[
        const SizedBox(height: 16),
        SettingsCard(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.chat_rounded,
                  color: Color(0xFF059669),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mostrar mi WhatsApp en perfil y citas',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0B2545),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Si lo desactivas, se ocultará tu número y el botón de WhatsApp.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                activeThumbColor: const Color(0xFF059669),
                value: showWhatsapp,
                onChanged: saving
                    ? null
                    : (value) => setState(() => showWhatsapp = value),
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 24),
      SettingsGradientButton(
        label: saving ? 'Guardando…' : 'Guardar cambios',
        loading: saving,
        onPressed: () async {
          setState(() => saving = true);
          final response = await ApiClient.put('/users/me', {
            'first_name': name.text.trim(),
            'last_name': surname.text.trim(),
            'phone': phone.text.trim(),
            'birth_date': birthDate?.toIso8601String().split('T').first,
            'show_whatsapp': showWhatsapp,
          });
          if (context.mounted) {
            setState(() => saving = false);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(response.statusCode == 200
                    ? 'Información guardada.'
                    : 'No se pudo guardar.')));
          }
        },
      ),
    ]);
  }
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
  bool _saving = false;

  @override
  void dispose() {
    address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _SettingsPage(title: 'Mis Direcciones', children: [
        const SettingsBanner(
          icon: Icons.location_on_rounded,
          title: 'Tus direcciones registradas',
          subtitle:
              'Indica tu estado y dirección actual para ubicarte mejor en Salud Now.',
        ),
        const SizedBox(height: 16),
        SettingsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SettingsSectionHeader(
                icon: Icons.map_rounded,
                iconColor: Color(0xFF0056B3),
                iconBg: Color(0xFFE0EAFC),
                title: 'Ubicación de residencia',
                subtitle: 'Selecciona tu estado y detalla tu dirección.',
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                initialValue: _selectedState,
                decoration: settingsInputDecoration(
                  label: 'Estado',
                  icon: Icons.location_city_rounded,
                ),
                items: veStates
                    .map((value) =>
                        DropdownMenuItem(value: value, child: Text(value)))
                    .toList(),
                onChanged:
                    _saving ? null : (v) => setState(() => _selectedState = v),
              ),
              const SizedBox(height: 14),
              _field(
                'Dirección',
                address,
                lines: 3,
                icon: Icons.home_work_outlined,
                enabled: !_saving,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SettingsGradientButton(
          label: _saving ? 'Guardando…' : 'Guardar cambios',
          loading: _saving,
          onPressed: () async {
            setState(() => _saving = true);
            final r = await ApiClient.put('/users/me',
                {'state': _selectedState, 'address': address.text.trim()});
            if (context.mounted) {
              setState(() => _saving = false);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(r.statusCode == 200
                      ? 'Dirección guardada.'
                      : 'No se pudo guardar.')));
            }
          },
        ),
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
  final FocusNode _specialtyFocusNode = FocusNode();
  late final bio =
      TextEditingController(text: widget.doctor['bio']?.toString());
  late final location =
      TextEditingController(text: widget.doctor['clinic_info']?.toString());
  late final yearsExperience = TextEditingController(
      text: (widget.doctor['years_experience'] ?? 0).toString());
  late final _licenseController = TextEditingController(
      text: widget.doctor['medical_license_number']?.toString() ??
          'No registrada');
  late List<String> specialties =
      (widget.doctor['specialties'] as List? ?? const [])
          .map((value) => value.toString())
          .toSet()
          .take(5)
          .toList();
  bool _saving = false;

  @override
  void dispose() {
    _specialtySearch.dispose();
    _specialtyFocusNode.dispose();
    bio.dispose();
    location.dispose();
    yearsExperience.dispose();
    _licenseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _SettingsPage(title: 'Datos Laborales', children: [
        const SettingsBanner(
          icon: Icons.work_rounded,
          title: 'Tu perfil profesional',
          subtitle:
              'Destaca tu trayectoria, especialidades y ubicación de consultorio ante tus pacientes.',
        ),
        const SizedBox(height: 16),
        SettingsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SettingsSectionHeader(
                icon: Icons.workspace_premium_rounded,
                iconColor: Color(0xFF0056B3),
                iconBg: Color(0xFFE0EAFC),
                title: 'Trayectoria y credenciales',
                subtitle: 'Información visible en tu perfil médico público.',
              ),
              const SizedBox(height: 18),
              _field(
                'Matrícula sanitaria',
                _licenseController,
                enabled: false,
                icon: Icons.verified_user_outlined,
              ),
              _field(
                'Años de experiencia',
                yearsExperience,
                type: TextInputType.number,
                maxLength: 2,
                icon: Icons.timeline_rounded,
                enabled: !_saving,
              ),
              _field(
                'Biografía',
                bio,
                lines: 4,
                maxLength: 120,
                icon: Icons.description_outlined,
                enabled: !_saving,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SettingsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SettingsSectionHeader(
                icon: Icons.medical_services_rounded,
                iconColor: Color(0xFF059669),
                iconBg: Color(0xFFD1FAE5),
                title: 'Especialidades médicas',
                subtitle: 'Agrega hasta 5 especialidades en las que atiendes.',
              ),
              const SizedBox(height: 16),
              Autocomplete<String>(
                textEditingController: _specialtySearch,
                focusNode: _specialtyFocusNode,
                optionsBuilder: (value) => medicalSpecialties.where((item) =>
                    item
                        .toLowerCase()
                        .contains(value.text.trim().toLowerCase()) &&
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
                fieldViewBuilder:
                    (context, controller, focusNode, onSubmitted) => TextField(
                  controller: controller,
                  focusNode: focusNode,
                  enabled: !_saving,
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'[0-9]')),
                  ],
                  decoration: settingsInputDecoration(
                    label: 'Buscar especialidad',
                    icon: Icons.search_rounded,
                    enabled: !_saving,
                  ),
                ),
              ),
              if (specialties.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: specialties
                      .map((specialty) => Chip(
                            backgroundColor: const Color(0xFFE0EAFC),
                            side: const BorderSide(color: Color(0xFFBFDBFE)),
                            label: Text(
                              specialty,
                              style: const TextStyle(
                                color: Color(0xFF0B2545),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                            deleteIconColor: const Color(0xFF0056B3),
                            onDeleted: _saving
                                ? null
                                : () =>
                                    setState(() => specialties.remove(specialty)),
                          ))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        SettingsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SettingsSectionHeader(
                icon: Icons.local_hospital_rounded,
                iconColor: Color(0xFF6D28D9),
                iconBg: Color(0xFFEDE9FE),
                title: 'Consultorio',
                subtitle: 'Dirección o centro médico donde pasas consulta.',
              ),
              const SizedBox(height: 16),
              _field(
                'Ubicación de consultorio',
                location,
                lines: 2,
                icon: Icons.place_outlined,
                enabled: !_saving,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SettingsGradientButton(
          label: _saving ? 'Guardando…' : 'Guardar cambios',
          loading: _saving,
          onPressed: () async {
            final parsedExperience = int.tryParse(yearsExperience.text.trim());
            if (parsedExperience == null || parsedExperience > 80) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Ingresa entre 0 y 80 años de experiencia.')));
              return;
            }
            setState(() => _saving = true);
            final r = await ApiClient.put('/doctors/me', {
              'bio': bio.text.trim(),
              'years_experience': parsedExperience,
              'clinic_info': location.text.trim(),
              'specialties': specialties
            });
            if (context.mounted) {
              setState(() => _saving = false);
              var experienceSynced = false;
              if (r.statusCode == 200) {
                final prefs = await SharedPreferences.getInstance();
                if (!mounted) return;
                final doctorId =
                    int.tryParse(widget.doctor['id']?.toString() ?? '');
                if (doctorId != null) {
                  final cacheKey = 'doctor_years_experience_$doctorId';
                  var savedExperienceFromServer = -1;
                  try {
                    final body = jsonDecode(r.body);
                    savedExperienceFromServer =
                        (body['years_experience'] as num?)?.toInt() ?? -1;
                  } catch (_) {}
                  experienceSynced =
                      savedExperienceFromServer == parsedExperience;
                  if (experienceSynced) {
                    await prefs.remove(cacheKey);
                  } else {
                    await prefs.setInt(cacheKey, parsedExperience);
                  }
                }
                widget.doctor['years_experience'] = parsedExperience;
              }
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(r.statusCode == 200
                      ? experienceSynced
                          ? 'Datos laborales guardados.'
                          : 'Datos guardados en este dispositivo; el servidor aún no sincroniza la experiencia.'
                      : 'No se pudieron guardar.')));
            }
          },
        ),
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
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    description.dispose();
    location.dispose();
    specialties.dispose();
    phone2.dispose();
    phone.dispose();
    super.dispose();
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
        const SettingsBanner(
          icon: Icons.local_hospital_rounded,
          title: 'Información de tu clínica',
          subtitle:
              'Actualiza la descripción, especialidades y teléfonos de atención.',
        ),
        const SizedBox(height: 16),
        SettingsCard(
          child: Column(
            children: [
              _field('Descripción', description,
                  lines: 4, icon: Icons.description_outlined, enabled: !_saving),
              _field('Ubicación', location,
                  lines: 2, icon: Icons.place_outlined, enabled: !_saving),
              _field('Especialidades (separadas por coma)', specialties,
                  icon: Icons.medical_services_outlined, enabled: !_saving),
              _field('Número de contacto', phone,
                  type: TextInputType.phone,
                  maxLength: 11,
                  icon: Icons.phone_outlined,
                  enabled: !_saving),
              _field('Segundo número de contacto', phone2,
                  type: TextInputType.phone,
                  maxLength: 11,
                  icon: Icons.phone_in_talk_outlined,
                  enabled: !_saving),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SettingsGradientButton(
          label: _saving ? 'Guardando…' : 'Guardar cambios',
          loading: _saving,
          onPressed: () async {
            setState(() => _saving = true);
            final u = await ApiClient.put('/users/me',
                {'address': location.text.trim(), 'phone': phone.text.trim()});
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
              setState(() => _saving = false);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(u.statusCode == 200 && c.statusCode == 200
                      ? 'Datos guardados.'
                      : 'No se pudieron guardar los datos.')));
            }
          },
        ),
      ]);
}

class SecurityPage extends StatefulWidget {
  const SecurityPage({super.key});

  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage> {
  bool _biometricsEnabled = false;
  bool _isLoading = true;
  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    final prefs = await SharedPreferences.getInstance();
    final currentToken = prefs.getString('access_token');
    final userId = AuthHelper.getUserIdFromToken(currentToken) ?? 'default';
    if (mounted) {
      setState(() {
        _biometricsEnabled =
            prefs.getBool('biometrics_enabled_$userId') ?? false;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleBiometrics(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    final currentToken = prefs.getString('access_token');
    final userId = AuthHelper.getUserIdFromToken(currentToken) ?? 'default';
    if (kIsWeb) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('El acceso biométrico no está disponible en la web.')),
      );
      return;
    }

    if (value) {
      try {
        final canCheck = await _localAuth.canCheckBiometrics;
        final isSupported = await _localAuth.isDeviceSupported();
        if (!canCheck && !isSupported) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Tu dispositivo no cuenta con biometría configurada.')),
          );
          return;
        }

        final didAuth = await _localAuth.authenticate(
          localizedReason:
              'Confirma tu huella o rostro para activar el acceso biométrico',
          options: const AuthenticationOptions(biometricOnly: true),
        );

        if (!didAuth) return;

        if (currentToken != null) {
          await prefs.setString('saved_biometric_token', currentToken);
          await prefs.setString('saved_biometric_user_id', userId);
          final userEmail = AuthHelper.getEmailFromToken(currentToken);
          if (userEmail != null) {
            await prefs.setString('logged_username', userEmail);
          }
        }
        await prefs.setBool('biometrics_enabled_$userId', true);
        await prefs.setBool('biometrics_enabled', true);
        if (mounted) {
          setState(() => _biometricsEnabled = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Acceso biométrico activado.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al configurar biometría: $e')),
          );
        }
      }
    } else {
      await prefs.setBool('biometrics_enabled_$userId', false);
      await prefs.remove('saved_biometric_token');
      await prefs.remove('saved_biometric_user_id');
      await prefs.setBool('biometrics_enabled', false);
      if (mounted) {
        setState(() => _biometricsEnabled = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Acceso biométrico desactivado.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) =>
      _SettingsPage(title: 'Seguridad de tu cuenta', children: [
        const SettingsBanner(
          icon: Icons.shield_rounded,
          title: 'Protección de tu cuenta',
          subtitle:
              'Administra tu contraseña de acceso y métodos de autenticación.',
        ),
        const SizedBox(height: 16),
        SettingsCard(
          padding: const EdgeInsets.all(6),
          child: ListTile(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFE0EAFC),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.key_rounded,
                color: Color(0xFF0056B3),
                size: 22,
              ),
            ),
            title: const Text(
              'Cambiar clave de seguridad',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: Color(0xFF0B2545),
              ),
            ),
            subtitle: const Text(
              'Actualiza tu contraseña periódicamente para mayor protección.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            trailing: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.chevron_right_rounded,
                  color: Color(0xFF0056B3)),
            ),
            onTap: () async {
              final changed = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const _ChangePasswordPage()),
              );
              if (context.mounted && changed == true) {
                Navigator.of(context).pop(true);
              }
            },
          ),
        ),
        if (!kIsWeb) ...[
          const SizedBox(height: 16),
          SettingsCard(
            child: _isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _biometricsEnabled
                              ? const Color(0xFFD1FAE5)
                              : const Color(0xFFEDE9FE),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.fingerprint_rounded,
                          color: _biometricsEnabled
                              ? const Color(0xFF059669)
                              : const Color(0xFF6D28D9),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Usar datos biométricos',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0B2545),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Inicia sesión rápidamente con huella o rostro.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        activeThumbColor: const Color(0xFF059669),
                        value: _biometricsEnabled,
                        onChanged: _toggleBiometrics,
                      ),
                    ],
                  ),
          ),
        ],
      ]);
}

typedef _SecurityPage = SecurityPage;

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
  bool _obs1 = true;
  bool _obs2 = true;
  bool _obs3 = true;

  @override
  void initState() {
    super.initState();
    next.addListener(_onPwdChanged);
    repeat.addListener(_onPwdChanged);
  }

  void _onPwdChanged() {
    if (mounted) setState(() {});
  }

  Widget _pwdField(
      String label, TextEditingController c, bool obs, VoidCallback toggle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: c,
        enabled: !busy,
        obscureText: obs,
        onChanged: (_) => setState(() {}),
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Color(0xFF0F172A),
        ),
        decoration: settingsInputDecoration(
          label: label,
          icon: Icons.lock_outline_rounded,
          enabled: !busy,
          suffixIcon: IconButton(
            icon: Icon(
              obs ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: const Color(0xFF64748B),
              size: 20,
            ),
            onPressed: toggle,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    next.removeListener(_onPwdChanged);
    repeat.removeListener(_onPwdChanged);
    current.dispose();
    next.dispose();
    repeat.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final password = next.text;
    if (password != repeat.text ||
        password.length < 8 ||
        !RegExp(r'[A-Z]').hasMatch(password) ||
        !RegExp(r'[0-9]').hasMatch(password)) {
      _showError('La nueva contraseña no cumple los requisitos o no coincide.');
      return;
    }

    setState(() => busy = true);
    try {
      final response = await ApiClient.put('/users/me/password', {
        'current_password': current.text,
        'new_password': password,
      }).timeout(const Duration(seconds: 15));
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;

      if (response.statusCode == 200) {
        FocusScope.of(context).unfocus();
        current.clear();
        next.clear();
        repeat.clear();
        Navigator.of(context).pop(true);
        return;
      }
      _showError(response.statusCode == 400
          ? 'La contraseña actual es incorrecta.'
          : 'No se pudo cambiar la contraseña.');
    } catch (_) {
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        _showError('No se pudo confirmar el cambio de contraseña.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _reqRow(bool met, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: met ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              shape: BoxShape.circle,
            ),
            child: Icon(
              met ? Icons.check_rounded : Icons.close_rounded,
              size: 12,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 9),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: met ? FontWeight.w700 : FontWeight.w600,
              color: met ? const Color(0xFF065F46) : const Color(0xFFDC2626),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pwd = next.text;
    final hasLen = pwd.length >= 8;
    final hasUpper = RegExp(r'[A-Z]').hasMatch(pwd);
    final hasNum = RegExp(r'[0-9]').hasMatch(pwd);
    final matches = pwd.isNotEmpty && pwd == repeat.text;

    return _SettingsPage(title: 'Cambiar contraseña', children: [
      const SettingsBanner(
        icon: Icons.lock_reset_rounded,
        title: 'Actualiza tu contraseña',
        subtitle:
            'Elige una clave segura para mantener protegida tu cuenta en Salud Now.',
      ),
      const SizedBox(height: 16),
      SettingsCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SettingsSectionHeader(
              icon: Icons.password_rounded,
              iconColor: Color(0xFF0056B3),
              iconBg: Color(0xFFE0EAFC),
              title: 'Credenciales de acceso',
              subtitle: 'Ingresa tu contraseña actual y define la nueva.',
            ),
            const SizedBox(height: 18),
            _pwdField('Contraseña actual', current, _obs1,
                () => setState(() => _obs1 = !_obs1)),
            _pwdField('Nueva contraseña', next, _obs2,
                () => setState(() => _obs2 = !_obs2)),
            _pwdField('Repetir nueva contraseña', repeat, _obs3,
                () => setState(() => _obs3 = !_obs3)),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Requisitos de seguridad:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0B2545),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _reqRow(hasLen, 'Mínimo 8 caracteres'),
                  _reqRow(hasUpper, 'Al menos una letra mayúscula'),
                  _reqRow(hasNum, 'Al menos un número'),
                  _reqRow(matches, 'Las contraseñas coinciden'),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      SettingsGradientButton(
        label: busy ? 'Actualizando…' : 'Actualizar contraseña',
        loading: busy,
        onPressed: busy ? null : _changePassword,
      ),
    ]);
  }
}

class _AboutPage extends StatelessWidget {
  const _AboutPage({required this.onOpen, required this.menuRow});
  final void Function(String, Widget) onOpen;
  final Widget Function(String, VoidCallback) menuRow;
  @override
  Widget build(BuildContext context) =>
      _SettingsPage(title: 'Acerca de Salud Now', children: [
        const SettingsBanner(
          icon: Icons.info_outline_rounded,
          title: 'Salud Now',
          subtitle: 'Políticas, condiciones de uso y gestión de cuenta.',
        ),
        const SizedBox(height: 16),
        SettingsCard(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 6, 12, 4),
                child: Text(
                  'Preferencia de Datos',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0B2545),
                  ),
                ),
              ),
              menuRow(
                  'Política de Privacidad',
                  () => onOpen(
                      'Política de Privacidad', const PrivacyPolicyScreen())),
              menuRow('Cookies',
                  () => onOpen('Cookies', const CookiesPolicyScreen())),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SettingsCard(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 6, 12, 4),
                child: Text(
                  'Información Legal',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0B2545),
                  ),
                ),
              ),
              menuRow(
                  'Términos y Condiciones',
                  () => onOpen('Términos y Condiciones',
                      const TermsAndConditionsScreen())),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Eliminar Cuenta de Salud Now',
                    style: TextStyle(
                        color: Colors.red, fontWeight: FontWeight.w600)),
                onTap: () => _confirmDelete(context),
              ),
            ],
          ),
        ),
      ]);
  Future<void> _confirmDelete(BuildContext context) async {
    final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text('Eliminar cuenta'),
                content: const Text(
                    'Se eliminarán permanentemente tu cuenta y los datos asociados, incluidos tu perfil, citas, chats, suscripciones y datos de acceso. Esta acción no se puede deshacer. ¿Continuar?'),
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

Widget _field(
  String label,
  TextEditingController controller, {
  TextInputType? type,
  int lines = 1,
  bool secret = false,
  bool enabled = true,
  int? maxLength,
  IconData icon = Icons.edit_outlined,
}) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        keyboardType: type,
        maxLines: secret ? 1 : lines,
        obscureText: secret,
        enabled: enabled,
        maxLength: maxLength,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: enabled ? const Color(0xFF0F172A) : const Color(0xFF64748B),
        ),
        inputFormatters: label == 'Nombres' || label == 'Apellidos'
            ? [FilteringTextInputFormatter.deny(RegExp(r'[0-9]'))]
            : label == 'Años de experiencia'
                ? [FilteringTextInputFormatter.digitsOnly]
                : null,
        decoration: settingsInputDecoration(
          label: label,
          icon: icon,
          enabled: enabled,
        ),
      ),
    );
