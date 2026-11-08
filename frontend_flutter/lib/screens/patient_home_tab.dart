import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/doctor_header.dart';
import '../widgets/profile_avatar.dart';
import '../core/api_client.dart';
import '../core/health_connect_helper.dart';
import '../core/profile_image_helper.dart';
import '../models/avatar_catalog.dart';
import '../models/ve_catalogs.dart';
import '../widgets/avatar_sprite.dart';
import '../widgets/home_search_bar.dart';
import '../widgets/top_clinics_section.dart';
import '../widgets/instagram_photo_preview.dart';
import '../widgets/health_today_section.dart';
import '../widgets/click_assistant_section.dart';
import 'doctor_profile_screen.dart';

class PatientHomeTab extends StatefulWidget {
  const PatientHomeTab(
      {super.key,
      this.onProfileTap,
      this.onSpecialtyTap,
      this.onSearchTap,
      this.onSearchSubmitted,
      this.onViewSchedule});
  final VoidCallback? onProfileTap;
  final ValueChanged<String>? onSpecialtyTap;
  final VoidCallback? onSearchTap;
  final ValueChanged<String>? onSearchSubmitted;
  final VoidCallback? onViewSchedule;

  @override
  State<PatientHomeTab> createState() => _PatientHomeTabState();
}

class _PatientHomeTabState extends State<PatientHomeTab> {
  List<dynamic> _appointments = [];
  bool _isLoadingAppointments = true;
  bool _isLoadingTopDoctors = true;
  List<Map<String, dynamic>> _topDoctors = [];
  Set<String> _favoriteDoctorIds = {};
  Map<String, dynamic>? _userData;
  Timer? _countdownTimer;
  final ScrollController _topDoctorsController = ScrollController();
  final ScrollController _homeScrollController = ScrollController();
  final GlobalKey<ClickAssistantSectionState> _clickSectionKey =
      GlobalKey<ClickAssistantSectionState>();

  @override
  void initState() {
    super.initState();
    _fetchData();
    _countdownTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
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

  Future<void> _fetchData() async {
    try {
      if (!kIsWeb) {
        unawaited(HealthConnectHelper.syncHealthData());
      }
      final userResponse = await ApiClient.get('/users/me');
      if (userResponse.statusCode == 200) {
        final user = Map<String, dynamic>.from(jsonDecode(userResponse.body));
        ProfileImageHelper.updateCurrentUserAvatar(
            user['avatar_url']?.toString());
        if (mounted) setState(() => _userData = user);
        await _fetchTopDoctors(user);
      } else {
        if (mounted) setState(() => _isLoadingTopDoctors = false);
      }

      final apptResponse = await ApiClient.get('/appointments/my');
      if (apptResponse.statusCode == 200) {
        if (mounted) {
          final allAppts = jsonDecode(apptResponse.body) as List<dynamic>;
          final now = caracasNow();
          final upcoming = allAppts.where((item) {
            final appt = Map<String, dynamic>.from(item as Map);
            final status = appt['status']?.toString().toLowerCase();
            final appointmentTime = _appointmentDateTime(appt);
            return status != 'cancelled' &&
                status != 'canceled' &&
                appointmentTime != null &&
                appointmentTime.isAfter(now);
          }).toList();
          upcoming.sort((a, b) {
            final dateA =
                _appointmentDateTime(Map<String, dynamic>.from(a as Map));
            final dateB =
                _appointmentDateTime(Map<String, dynamic>.from(b as Map));
            if (dateA == null || dateB == null) return 0;
            return dateA.compareTo(dateB);
          });

          setState(() {
            _appointments = upcoming;
            _isLoadingAppointments = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingAppointments = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingAppointments = false;
          _isLoadingTopDoctors = false;
        });
      }
    }
  }

  Future<void> _fetchTopDoctors(Map<String, dynamic> user) async {
    try {
      final state = user['state']?.toString().trim();
      final response = await ApiClient.get('/doctors/public');
      if (response.statusCode != 200 || state == null || state.isEmpty) {
        if (mounted) setState(() => _isLoadingTopDoctors = false);
        return;
      }

      final doctors = (jsonDecode(response.body) as List<dynamic>)
          .whereType<Map>()
          .map((doctor) => Map<String, dynamic>.from(doctor))
          .where((doctor) =>
              doctor['is_vip'] == true &&
              doctor['state']?.toString().trim() == state)
          .toList()
        ..shuffle(math.Random());

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
    final doctorId = doctor['id']?.toString();
    if (doctorId == null || doctorId.isEmpty) return;
    final wasFavorite = _favoriteDoctorIds.contains(doctorId);
    setState(() {
      if (wasFavorite) {
        _favoriteDoctorIds.remove(doctorId);
      } else {
        _favoriteDoctorIds.add(doctorId);
      }
    });

    try {
      final userId = _userData?['id']?.toString() ?? 'current';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'patient_favorite_doctors_$userId',
        _favoriteDoctorIds.toList(),
      );
    } catch (_) {
      // Keep the selection for this screen session if local storage is unavailable.
    }
  }

  Future<void> _refreshFavoriteDoctors() async {
    final userId = _userData?['id']?.toString() ?? 'current';
    final prefs = await SharedPreferences.getInstance();
    final favorites =
        prefs.getStringList('patient_favorite_doctors_$userId') ?? [];
    if (mounted) setState(() => _favoriteDoctorIds = favorites.toSet());
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
                  const Text('Próximas Citas',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0B2545))),
                  const SizedBox(height: 12),
                  if (_isLoadingAppointments)
                    const Center(child: CircularProgressIndicator())
                  else if (_appointments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Text('No tienes citas próximas.',
                          style: TextStyle(color: Colors.grey)),
                    )
                  else
                    ..._appointments
                        .where((a) => a['status'] != 'cancelled')
                        .take(1)
                        .map((a) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: _buildUpcomingAppointment(a),
                      );
                    }),
                  const SizedBox(height: 18),
                  _buildSpecialtiesSection(),
                  if (!kIsWeb) ...[
                    const SizedBox(height: 20),
                    const HealthTodaySection(),
                  ],
                  const SizedBox(height: 20),
                  _buildTopDoctorsSection(),
                  const SizedBox(height: 24),
                  const TopClinicsSection(),
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

  Widget _buildSpecialtiesSection() {
    const specialties = [
      _HomeSpecialtyOption(
        label: 'General',
        filter: 'General',
        icon: Icons.medical_services_outlined,
        background: Color(0xFFDDF0E7),
        foreground: Color(0xFF21836D),
      ),
      _HomeSpecialtyOption(
        label: 'Corazón',
        filter: 'Cardiología',
        icon: Icons.favorite,
        background: Color(0xFFF8E1DF),
        foreground: Color(0xFFE34F62),
      ),
      _HomeSpecialtyOption(
        label: 'Cerebro',
        filter: 'Neurología',
        icon: Icons.psychology_outlined,
        background: Color(0xFFE9E2F7),
        foreground: Color(0xFF7558A8),
      ),
      _HomeSpecialtyOption(
        label: 'Dental',
        filter: 'Odontología',
        icon: Icons.medical_information_outlined,
        background: Color(0xFFDDEFE7),
        foreground: Color(0xFF218A72),
      ),
      _HomeSpecialtyOption(
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
            const Text(
              'Especialidades',
              style: TextStyle(
                color: Color(0xFF0B2545),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
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
                        child: Icon(
                          specialty.icon,
                          size: 25,
                          color: specialty.foreground,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        specialty.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF26342F),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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

  Widget _buildTopDoctorsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Top doctores',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0B2545),
          ),
        ),
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
              thumbVisibility: defaultTargetPlatform == TargetPlatform.windows,
              trackVisibility: defaultTargetPlatform == TargetPlatform.windows,
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
  }

  Widget _buildTopDoctorCard(Map<String, dynamic> doctor) {
    final doctorId = doctor['id']?.toString() ?? '';
    final isFavorite = _favoriteDoctorIds.contains(doctorId);
    final rating = (doctor['rating'] as num?)?.toDouble() ?? 5.0;
    final feeValue = doctor['consultation_fee'];
    final fee = feeValue is num
        ? feeValue.toDouble()
        : double.tryParse(feeValue?.toString() ?? '');
    final price = fee == null || fee <= 0
        ? 'Consultar'
        : '\$${fee.toStringAsFixed(fee == fee.roundToDouble() ? 0 : 2)}';

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
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => DoctorProfileScreen(
                  doctor: doctor,
                  onViewSchedule: widget.onViewSchedule,
                ),
              ),
            );
            await _refreshFavoriteDoctors();
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
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onLongPress: () {
                            final name =
                                '${doctor['first_name'] ?? ''} ${doctor['last_name'] ?? ''}'
                                    .trim();
                            final specialties =
                                (doctor['specialties'] as List?)?.join(', ');
                            InstagramPhotoPreview.show(
                              context,
                              imageUrl: doctor['avatar_url']?.toString(),
                              fallbackRole: 'doctor',
                              title: name.isEmpty ? 'Doctor' : 'Dr. $name',
                              subtitle: specialties,
                            );
                          },
                          child: _buildSquareDoctorPhoto(
                              doctor['avatar_url']?.toString()),
                        ),
                      ),
                      Positioned(
                        top: 7,
                        right: 7,
                        child: Material(
                          color: Colors.white.withOpacity(0.94),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => _toggleDoctorFavorite(doctor),
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
                          color: Color(0xFF17212B),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        doctor['specialty']?.toString() ?? 'Especialista',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF475569),
                        ),
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
                          Text(
                            price,
                            style: const TextStyle(
                              color: Color(0xFF126B68),
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
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

  Widget _buildSquareDoctorPhoto(String? avatarUrl) {
    if (avatarUrl == null || avatarUrl.trim().isEmpty) {
      return _doctorPhotoPlaceholder();
    }
    final preset = AvatarCatalog.parse(avatarUrl);
    if (preset != null) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final size = math.min(constraints.maxWidth, constraints.maxHeight);
          return AvatarSprite(
            role: preset.role,
            index: preset.index,
            size: size,
          );
        },
      );
    }
    try {
      return Image(
        image: ProfileImageHelper.getProfileImageProvider(avatarUrl),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _doctorPhotoPlaceholder(),
      );
    } catch (_) {
      return _doctorPhotoPlaceholder();
    }
  }

  Widget _doctorPhotoPlaceholder() => LayoutBuilder(
        builder: (context, constraints) {
          final size = math.min(constraints.maxWidth, constraints.maxHeight);
          return AvatarSprite(role: 'doctor', index: 0, size: size);
        },
      );

  Widget _buildProfileSection() {
    final firstName = _userData?['first_name']?.toString().trim();
    final greeting = firstName == null || firstName.isEmpty
        ? (_userData == null ? '¡Hola!' : '¡Hola, Paciente!')
        : '¡Hola, $firstName!';
    final email = _userData?['email']?.toString();
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 320;
        final avatarSize = compact ? 62.0 : 80.0;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 24),
          child: Row(
            children: [
              InkWell(
                onTap: widget.onProfileTap,
                customBorder: const CircleBorder(),
                child: ProfileAvatar(
                    imageUrl: _userData?['avatar_url']?.toString(),
                    currentUser: true,
                    fallbackRole: 'patient',
                    displayName:
                        '${_userData?['first_name'] ?? ''} ${_userData?['last_name'] ?? ''}'
                            .trim(),
                    subtitle: 'Paciente',
                    size: avatarSize,
                    borderColor: const Color(0xFF0056B3),
                    borderWidth: compact ? 2 : 3),
              ),
              SizedBox(width: compact ? 10 : 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      maxLines: compact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 18 : 22,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0B2545),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                              color: const Color(0xFF38B6FF),
                              borderRadius: BorderRadius.circular(12)),
                          child: const Text('Paciente',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ),
                        if (!compact && email != null && email.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(email,
                                  style: const TextStyle(
                                      color: Color(0xFF475569), fontSize: 13),
                                  overflow: TextOverflow.ellipsis)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAppointmentDetails(Map<String, dynamic> appt) {
    final doctor = appt['doctor_name'] ?? 'Dr. Desconocido';
    final specialty = appt['doctor_specialty'] ?? 'General';
    final date = appt['date']?.toString() ?? '';
    final time = appt['time_block']?.toString() ?? 'Hora pendiente';
    final turn = appt['turn_number']?.toString() ?? '-';
    final location = appt['doctor_location']?.toString() ?? '';
    final reason = appt['appointment_reason']?.toString() ?? 'Consulta Médica';
    final status = (appt['status'] ?? 'scheduled').toString().toLowerCase();
    final avatarUrl = appt['doctor_avatar'] as String?;
    final countdown = _countdownLabel(
        (_appointmentDateTime(appt) ?? caracasNow()).difference(caracasNow()));
    final String displayStatus = status == 'scheduled'
        ? countdown
        : (status == 'completed'
            ? 'COMPLETADA'
            : (status == 'cancelled' ? 'CANCELADA' : status.toUpperCase()));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(24),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      ProfileAvatar(
                        imageUrl: avatarUrl,
                        size: 84,
                        fallbackRole: 'doctor',
                        borderWidth: 0,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        doctor,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0B2545),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        specialty,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF0056B3),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: status == 'scheduled'
                              ? const Color(0xFF0056B3)
                              : Colors.blueGrey,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          displayStatus,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2F1F8),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: const Color(0xFF0056B3).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.confirmation_number_outlined,
                          color: Color(0xFF0056B3), size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('TURNO ASIGNADO',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0056B3))),
                            Text('Turno #$turn',
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0B2545))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildDetailRow(Icons.calendar_today, 'Fecha', date),
                const SizedBox(height: 12),
                _buildDetailRow(Icons.access_time, 'Hora estimada', time),
                if (location.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildDetailRow(
                      Icons.location_on, 'Ubicación / Consultorio', location),
                ],
                if (reason.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.medical_services_outlined,
                      'Motivo de consulta', reason),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar',
                style: TextStyle(
                    color: Color(0xFF0056B3),
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF0056B3)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF0B2545),
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUpcomingAppointment(Map<String, dynamic> appt) {
    final doctor = appt['doctor_name']?.toString() ?? 'Dr. Desconocido';
    final specialty = appt['doctor_specialty']?.toString() ?? 'General';
    final avatarUrl = appt['doctor_avatar'] as String?;
    final appointmentDate = _appointmentDateTime(appt);
    final countdown = appointmentDate == null
        ? 'Fecha pendiente'
        : _countdownLabel(appointmentDate.difference(caracasNow()));
    final dateLabel = appointmentDate == null
        ? 'Fecha pendiente'
        : _shortSpanishDate(appointmentDate);
    final timeLabel = appointmentDate == null
        ? 'Hora pendiente'
        : _spanishTime(appointmentDate);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => _showAppointmentDetails(appt),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0756A4), Color(0xFF0A3D78)],
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0756A4).withOpacity(0.22),
                blurRadius: 16,
                offset: const Offset(0, 7),
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
                    'Próxima cita',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5485D),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      countdown,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: SizedBox(
                      width: 62,
                      height: 62,
                      child: _buildSquareDoctorPhoto(avatarUrl),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doctor,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          specialty,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 7,
                      runSpacing: 6,
                      children: [
                        _appointmentInfoChip(Icons.calendar_today, dateLabel),
                        _appointmentInfoChip(Icons.access_time, timeLabel),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward,
                      color: Color(0xFF0756A4),
                      size: 21,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _appointmentInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.11),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 13),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  DateTime? _appointmentDateTime(Map<String, dynamic> appointment) {
    final parsedDate = DateTime.tryParse(
      appointment['date']?.toString().split('T').first ?? '',
    );
    if (parsedDate == null) return null;

    final rawTime = appointment['time_block']?.toString() ?? '';
    final match = RegExp(
      r'(\d{1,2}):(\d{2})\s*([ap](?:\.?m\.?)?)?',
      caseSensitive: false,
    ).firstMatch(rawTime);
    if (match == null) return parsedDate;

    var hour = int.tryParse(match.group(1) ?? '') ?? 0;
    final minute = int.tryParse(match.group(2) ?? '') ?? 0;
    final suffix = (match.group(3) ?? '').toLowerCase().replaceAll('.', '');
    if (suffix.startsWith('p') && hour < 12) hour += 12;
    if (suffix.startsWith('a') && hour == 12) hour = 0;
    return DateTime(
        parsedDate.year, parsedDate.month, parsedDate.day, hour, minute);
  }

  String _countdownLabel(Duration remaining) {
    if (remaining <= Duration.zero) return 'En curso';
    if (remaining <= const Duration(hours: 24)) {
      final minutes = remaining.inMinutes;
      if (minutes < 60) return 'En menos de 1 h';
      final hours = minutes ~/ 60;
      final extraMinutes = minutes % 60;
      return extraMinutes == 0
          ? 'En $hours h'
          : 'En $hours h $extraMinutes min';
    }

    final days = remaining.inDays;
    if (days >= 7) {
      final weeks = days ~/ 7;
      final remainingDays = days % 7;
      final weekLabel = weeks == 1 ? 'semana' : 'semanas';
      if (remainingDays == 0) return 'En $weeks $weekLabel';
      return 'En $weeks sem · $remainingDays ${remainingDays == 1 ? 'día' : 'días'}';
    }
    return 'En $days ${days == 1 ? 'día' : 'días'}';
  }

  String _shortSpanishDate(DateTime date) {
    const weekdays = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
    const months = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic'
    ];
    return '${weekdays[date.weekday - 1]} ${date.day} ${months[date.month - 1]}';
  }

  String _spanishTime(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${date.hour >= 12 ? 'p. m.' : 'a. m.'}';
  }
}

class _HomeSpecialtyOption {
  const _HomeSpecialtyOption({
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
