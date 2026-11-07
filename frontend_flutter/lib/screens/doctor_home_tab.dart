import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import '../widgets/doctor_header.dart';
import '../core/api_client.dart';
import '../core/distribution_config.dart';
import '../core/profile_image_helper.dart';
import '../models/ve_catalogs.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/home_search_bar.dart';
import '../widgets/top_clinics_section.dart';
import '../widgets/health_today_section.dart';
import '../widgets/click_assistant_section.dart';
import '../screens/doctor_profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'select_plan_screen.dart';

class DoctorHomeTab extends StatefulWidget {
  const DoctorHomeTab({
    super.key,
    this.onProfileTap,
    this.onCitasHoyTap,
    this.onSearchTap,
    this.onSearchSubmitted,
    this.onSpecialtyTap,
  });
  final VoidCallback? onProfileTap;
  final VoidCallback? onCitasHoyTap;
  final VoidCallback? onSearchTap;
  final ValueChanged<String>? onSearchSubmitted;
  final ValueChanged<String>? onSpecialtyTap;

  @override
  State<DoctorHomeTab> createState() => _DoctorHomeTabState();
}

class _DoctorHomeTabState extends State<DoctorHomeTab> {
  List<dynamic> _invitations = [];
  bool _isLoadingProfile = true;
  int _citasHoy = 0;
  List<dynamic> _todayAppointments = [];
  List<Map<String, dynamic>> _topDoctors = [];
  Set<String> _favoriteDoctorIds = {};
  bool _isLoadingTopDoctors = true;
  bool _hasFetchedTopDoctors = false;
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _doctorData;
  Map<String, dynamic>? _subData;
  Timer? _pollingTimer;
  final ScrollController _topDoctorsController = ScrollController();
  final ScrollController _homeScrollController = ScrollController();
  final GlobalKey<ClickAssistantSectionState> _clickSectionKey =
      GlobalKey<ClickAssistantSectionState>();

  @override
  void initState() {
    super.initState();
    _fetchData();
    // Refresh today's schedule and account data periodically.
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _fetchData();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _topDoctorsController.dispose();
    _homeScrollController.dispose();
    super.dispose();
  }

  void _scrollToClick() {
    final state = _clickSectionKey.currentState;
    if (_homeScrollController.hasClients) {
      _homeScrollController.animateTo(
        _homeScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      ).then((_) {
        state?.focusAndScrollToInput();
      });
    } else {
      final ctx = _clickSectionKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 1.0,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
        ).then((_) {
          state?.focusAndScrollToInput();
        });
      }
    }
  }

  Future<void> _resolveInvitation(int clinicId, String action) async {
    try {
      final response = await ApiClient.post(
          '/doctors/me/clinic-invitations/$clinicId/$action', {});
      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invitación respondida.')));
        _fetchData(); // Refresh UI
      } else {
        var detail = 'Error al procesar invitación';
        try {
          detail = jsonDecode(response.body)['detail']?.toString() ?? detail;
        } catch (_) {}
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(detail)));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _fetchData() async {
    try {
      final responses = await Future.wait([
        ApiClient.get('/users/me'),
        ApiClient.get('/appointments/my'),
        ApiClient.get('/subscriptions/me'),
        ApiClient.get('/doctors/me/clinic-invitations'),
        ApiClient.get('/doctors/me'),
      ]);
      final user = responses[0].statusCode == 200
          ? Map<String, dynamic>.from(jsonDecode(responses[0].body))
          : null;
      final appointments = responses[1].statusCode == 200
          ? List<dynamic>.from(jsonDecode(responses[1].body))
          : <dynamic>[];
      final subscription = responses[2].statusCode == 200
          ? Map<String, dynamic>.from(jsonDecode(responses[2].body))
          : null;
      final invitations = responses[3].statusCode == 200
          ? List<dynamic>.from(jsonDecode(responses[3].body))
          : _invitations;
      final doctorData = responses[4].statusCode == 200
          ? Map<String, dynamic>.from(jsonDecode(responses[4].body))
          : _doctorData;
      final today = caracasNow().toIso8601String().split('T')[0];
      final appointmentsToday = appointments.where((appointment) {
        return appointment['date']?.toString().startsWith(today) == true &&
            appointment['status'] == 'scheduled';
      }).toList();
      if (user != null) {
        ProfileImageHelper.updateCurrentUserAvatar(
            user['avatar_url']?.toString());
      }
      if (mounted) {
        setState(() {
          _userData = user ?? _userData;
          _doctorData = doctorData;
          _invitations = invitations;
          _subData = subscription ?? _subData;
          _todayAppointments = appointmentsToday;
          _citasHoy = appointmentsToday.length;
          _isLoadingProfile = false;
        });
      }
      if (user != null && !_hasFetchedTopDoctors) {
        unawaited(_fetchTopDoctors(user));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
        });
      }
    }
  }

  Future<void> _fetchTopDoctors(Map<String, dynamic> user) async {
    if (_hasFetchedTopDoctors) return;
    _hasFetchedTopDoctors = true;
    try {
      final state = user['state']?.toString().trim() ?? '';
      final response = await ApiClient.get('/doctors/public');
      final doctors = response.statusCode == 200
          ? (jsonDecode(response.body) as List<dynamic>)
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .where((doctor) =>
                  doctor['is_vip'] == true &&
                  state.isNotEmpty &&
                  doctor['state']?.toString().trim() == state)
              .toList()
          : <Map<String, dynamic>>[];
      doctors.shuffle(math.Random());
      final userId = user['id']?.toString() ?? 'current';
      final prefs = await SharedPreferences.getInstance();
      final favorites =
          prefs.getStringList('patient_favorite_doctors_$userId') ?? [];
      if (!mounted) return;
      setState(() {
        _topDoctors = doctors.take(5).toList();
        _favoriteDoctorIds = favorites.toSet();
        _isLoadingTopDoctors = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingTopDoctors = false);
    }
  }

  Future<void> _toggleDoctorFavorite(Map<String, dynamic> doctor) async {
    final id = doctor['id']?.toString();
    if (id == null || id.isEmpty) return;
    final favorites = _favoriteDoctorIds.toSet();
    if (favorites.contains(id)) {
      favorites.remove(id);
    } else {
      favorites.add(id);
    }
    final userId = _userData?['id']?.toString() ?? 'current';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'patient_favorite_doctors_$userId',
      favorites.toList(),
    );
    if (mounted) setState(() => _favoriteDoctorIds = favorites);
  }

  Future<void> _refreshFavorites() async {
    final userId = _userData?['id']?.toString() ?? 'current';
    final prefs = await SharedPreferences.getInstance();
    final favorites =
        prefs.getStringList('patient_favorite_doctors_$userId') ?? [];
    if (mounted) setState(() => _favoriteDoctorIds = favorites.toSet());
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

  Widget _buildSpecialties() {
    const specialties = [
      _DoctorHomeSpecialty(
        label: 'General',
        filter: 'General',
        icon: Icons.medical_services_outlined,
        background: Color(0xFFDDF0E7),
        foreground: Color(0xFF21836D),
      ),
      _DoctorHomeSpecialty(
        label: 'Corazón',
        filter: 'Cardiología',
        icon: Icons.favorite,
        background: Color(0xFFF8E1DF),
        foreground: Color(0xFFE34F62),
      ),
      _DoctorHomeSpecialty(
        label: 'Cerebro',
        filter: 'Neurología',
        icon: Icons.psychology_outlined,
        background: Color(0xFFE9E2F7),
        foreground: Color(0xFF7558A8),
      ),
      _DoctorHomeSpecialty(
        label: 'Dental',
        filter: 'Odontología',
        icon: Icons.medical_information_outlined,
        background: Color(0xFFDDEFE7),
        foreground: Color(0xFF218A72),
      ),
      _DoctorHomeSpecialty(
        label: 'Ojos',
        filter: 'Oftalmología',
        icon: Icons.visibility_outlined,
        background: Color(0xFFE0EAF2),
        foreground: Color(0xFF5285A4),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Especialidades',
                style: TextStyle(
                    color: Color(0xFF0B2545),
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            TextButton(
              onPressed: () => widget.onSpecialtyTap?.call('Todos'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF0056B3),
                padding: EdgeInsets.zero,
                minimumSize: const Size(48, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Ver todas'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: specialties.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final specialty = specialties[index];
              return SizedBox(
                width: 62,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => widget.onSpecialtyTap?.call(specialty.filter),
                  child: Column(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: specialty.background,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(specialty.icon,
                            size: 25, color: specialty.foreground),
                      ),
                      const SizedBox(height: 5),
                      Text(specialty.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Color(0xFF26342F),
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTopDoctorsSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Top doctores',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0B2545))),
          const SizedBox(height: 12),
          if (_isLoadingTopDoctors)
            const SizedBox(
              height: 210,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_topDoctors.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Aún no hay doctores VIP disponibles en tu estado.',
                style: TextStyle(color: Color(0xFF475569)),
              ),
            )
          else
            SizedBox(
              height: 218,
              child: Scrollbar(
                controller: _topDoctorsController,
                thumbVisibility:
                    defaultTargetPlatform == TargetPlatform.windows,
                trackVisibility:
                    defaultTargetPlatform == TargetPlatform.windows,
                notificationPredicate: (_) =>
                    defaultTargetPlatform == TargetPlatform.windows,
                child: ScrollConfiguration(
                  behavior: const MaterialScrollBehavior().copyWith(
                    dragDevices: {
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                      PointerDeviceKind.trackpad,
                    },
                  ),
                  child: ListView.separated(
                    controller: _topDoctorsController,
                    scrollDirection: Axis.horizontal,
                    itemCount: _topDoctors.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) =>
                        _buildTopDoctorCard(_topDoctors[index]),
                  ),
                ),
              ),
            ),
        ],
      );

  Widget _buildTopDoctorCard(Map<String, dynamic> doctor) {
    final doctorId = doctor['id']?.toString() ?? '';
    final isFavorite = _favoriteDoctorIds.contains(doctorId);
    final feeValue = doctor['consultation_fee'];
    final fee = feeValue is num
        ? feeValue.toDouble()
        : double.tryParse(feeValue?.toString() ?? '');
    final price = fee == null || fee <= 0
        ? 'Consultar'
        : '\$${fee.toStringAsFixed(fee == fee.roundToDouble() ? 0 : 2)}';
    final rating = (doctor['rating'] as num?)?.toDouble() ?? 5.0;
    return SizedBox(
      width: 122,
      height: 206,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        elevation: 3,
        child: InkWell(
          onTap: () async {
            await Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => DoctorProfileScreen(doctor: doctor),
            ));
            await _refreshFavorites();
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(5),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(19),
                        child: ProfileAvatar(
                          imageUrl: doctor['avatar_url']?.toString(),
                          fallbackRole: 'doctor',
                          displayName:
                              '${doctor['first_name'] ?? ''} ${doctor['last_name'] ?? ''}'
                                  .trim(),
                          subtitle: (doctor['specialties'] as List?)?.join(', '),
                          size: 112,
                        ),
                      ),
                      Positioned(
                        top: 7,
                        right: 7,
                        child: Material(
                          color: Colors.white.withValues(alpha: .94),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: doctorId.isEmpty
                                ? null
                                : () => _toggleDoctorFavorite(doctor),
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Icon(
                                isFavorite
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                size: 17,
                                color: isFavorite
                                    ? const Color(0xFFE14B63)
                                    : const Color(0xFF344054),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(9, 4, 9, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doctor['name']?.toString() ?? 'Doctor',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF17212B)),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        doctor['specialty']?.toString() ?? 'Especialista',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 10, color: Color(0xFF475569)),
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.star_rounded,
                                  color: Color(0xFFF2B544), size: 15),
                              Text(rating.toStringAsFixed(1),
                                  style: const TextStyle(
                                      color: Color(0xFF475569), fontSize: 10)),
                            ],
                          ),
                          Text(price,
                              style: const TextStyle(
                                  color: Color(0xFF126B68),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodayAppointmentCard(Map<String, dynamic> appointment) {
    final patientName = appointment['patient_name']?.toString().trim();
    final time = appointment['time_block']?.toString() ?? 'Hora pendiente';
    final turn = appointment['turn_number']?.toString();
    final age = appointment['patient_age_display']?.toString();
    final subtitle = [
      if (age != null && age.isNotEmpty && age != 'null')
        age.endsWith('M') ? '$age de edad' : '$age años',
      if (appointment['appointment_reason']?.toString().isNotEmpty == true)
        appointment['appointment_reason'].toString(),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white.withValues(alpha: .86),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: widget.onCitasHoyTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ProfileAvatar(
                  imageUrl: appointment['doctor_avatar']?.toString(),
                  fallbackRole: 'patient',
                  size: 52,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patientName == null || patientName.isEmpty
                            ? 'Paciente'
                            : patientName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Color(0xFF0B2545),
                            fontWeight: FontWeight.w800),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Color(0xFF52647A), fontSize: 12)),
                      ],
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded,
                              size: 14, color: Color(0xFF0756A4)),
                          const SizedBox(width: 4),
                          Text(time,
                              style: const TextStyle(
                                  color: Color(0xFF334155),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12)),
                          if (turn != null) ...[
                            const SizedBox(width: 10),
                            Text('Turno #$turn',
                                style: const TextStyle(
                                    color: Color(0xFF64748B), fontSize: 12)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFF0756A4)),
              ],
            ),
          ),
        ),
      ),
    );
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DoctorHeader(),
            const SizedBox(height: 16),
            _buildProfileSection(),
            const SizedBox(height: 14),
            HomeSearchBar(
              onSearch: widget.onSearchSubmitted,
              onTap: widget.onSearchTap,
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _scrollToClick,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF003893), Color(0xFF00B4D8)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF003893).withValues(alpha: 0.18),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/click_mascot.jpg',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.smart_toy_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Asistente Virtual Click 🤖',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Encuentra doctores y agenda citas al instante • Toca aquí',
                                style: TextStyle(
                                  color: Color(0xFFE0F2FE),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_downward_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ListView(
                controller: _homeScrollController,
                cacheExtent: 3000,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Citas de hoy',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0B2545))),
                      TextButton(
                        onPressed: widget.onCitasHoyTap,
                        child: Text('Ver agenda ($_citasHoy)'),
                      ),
                    ],
                  ),
                  if (_isLoadingProfile && _todayAppointments.isEmpty)
                    const Center(child: CircularProgressIndicator())
                  else if (_todayAppointments.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .72),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Text(
                        'No tienes citas programadas para hoy.',
                        style: TextStyle(color: Color(0xFF52647A)),
                      ),
                    )
                  else
                    ..._todayAppointments.map((appointment) =>
                        _buildTodayAppointmentCard(
                            Map<String, dynamic>.from(appointment))),
                  const SizedBox(height: 20),
                  _buildSpecialties(),
                  if (!kIsWeb) ...[
                    const SizedBox(height: 20),
                    const HealthTodaySection(),
                  ],
                  const SizedBox(height: 20),
                  _buildTopDoctorsSection(),
                  const SizedBox(height: 20),
                  const TopClinicsSection(),
                  const SizedBox(height: 20),
                  if (_invitations.isNotEmpty) ...[
                    const Text('Invitaciones de Clínica',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0B2545))),
                    const SizedBox(height: 12),
                    ..._invitations.map((inv) => Card(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: ProfileAvatar(
                                imageUrl: inv['avatar_url']?.toString(),
                                size: 40,
                                fallbackRole: 'clinic'),
                            title: Text(inv['name'] ?? 'Clínica',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            subtitle: const Text('Te ha invitado a unirte'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.check,
                                      color: Colors.green),
                                  onPressed: () => _resolveInvitation(
                                      inv['clinic_id'], 'accept'),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close,
                                      color: Colors.red),
                                  onPressed: () => _resolveInvitation(
                                      inv['clinic_id'], 'reject'),
                                ),
                              ],
                            ),
                          ),
                        )),
                    const SizedBox(height: 16),
                  ],
                  const SizedBox(height: 24),
                  ClickAssistantSection(
                    key: _clickSectionKey,
                    onCitaAgendada: _fetchData,
                  ),
                  const SizedBox(height: 120),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection() {
    if (_isLoadingProfile) {
      return const SizedBox(
          height: 80, child: Center(child: CircularProgressIndicator()));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        children: [
          InkWell(
            onTap: widget.onProfileTap,
            customBorder: const CircleBorder(),
            child: ProfileAvatar(
              imageUrl: _userData?['avatar_url']?.toString(),
              currentUser: true,
              fallbackRole: _userData?['role']?.toString() ?? 'doctor',
              displayName:
                  '${_userData?['first_name'] ?? ''} ${_userData?['last_name'] ?? ''}'
                      .trim(),
              subtitle: 'Médico',
              size: 80,
              borderColor: const Color(0xFF0056B3),
              borderWidth: 3,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_greeting,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0B2545))),
                if (_userData?['role'] == 'assistant' &&
                    (_userData?['assistant_doctor_name']
                            ?.toString()
                            .isNotEmpty ??
                        false)) ...[
                  const SizedBox(height: 3),
                  Text('Asistente de ${_userData!['assistant_doctor_name']}',
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF475569))),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: const Color(0xFF38B6FF),
                          borderRadius: BorderRadius.circular(12)),
                      child: Text(
                          _userData?['role'] == 'assistant'
                              ? 'Asistente'
                              : 'Doctor',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(
                            _userData?['email'] ?? 'doctor@saludnow.com',
                            style: const TextStyle(
                                color: Color(0xFF475569), fontSize: 13),
                            overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _greeting {
    final user = _userData ?? const <String, dynamic>{};
    final role = user['role']?.toString();
    final firstName = user['first_name']?.toString().trim() ?? '';
    if (role == 'clinic') {
      return '¡Hola, ${firstName.isEmpty ? 'Clínica' : firstName}!';
    }
    if (role == 'assistant') {
      return '¡Hola, asistente ${firstName.isEmpty ? '' : firstName}!';
    }
    final lastName = user['last_name']?.toString().trim() ?? '';
    final gender = user['gender']?.toString().toLowerCase() ?? '';
    final title =
        gender.startsWith('f') || gender.contains('femen') ? 'Dra.' : 'Dr.';
    final fullName =
        [lastName, firstName].where((name) => name.isNotEmpty).join(' ');
    return '¡Hola, $title ${fullName.isEmpty ? 'Doctor' : fullName}!';
  }
}

class _DoctorHomeSpecialty {
  const _DoctorHomeSpecialty({
    required this.label,
    required this.filter,
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final String label;
  final String filter;
  final IconData icon;
  final Color background;
  final Color foreground;
}
