import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';
import '../core/auth_helper.dart';
import '../widgets/profile_avatar.dart';
import 'doctor_profile_screen.dart';

class ClinicProfileScreen extends StatefulWidget {
  final Map<String, dynamic> clinic;
  const ClinicProfileScreen({super.key, required this.clinic});

  @override
  State<ClinicProfileScreen> createState() => _ClinicProfileScreenState();
}

class _ClinicProfileScreenState extends State<ClinicProfileScreen> {
  bool _isLoading = true;
  List<dynamic> _doctors = [];
  bool _isFavorite = false;
  String _favoriteStorageKey = 'patient_favorite_clinics_current';

  // Métricas y calificación de la clínica
  bool _isPatient = false;
  bool _canRateClinic = false;
  int? _myClinicRating;
  double _averageRating = 5.0;
  int _totalReviews = 0;
  int _totalPatientsCount = 0;
  int _yearsExperience = 0;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _doctorsSectionKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _fetchDoctorsAndStats();
    _loadFavoriteStatus();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchDoctorsAndStats() async {
    final clinicId = widget.clinic['id'];
    if (clinicId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      // 1. Verificar rol del usuario actual
      final role = (await AuthHelper.getRole())?.toLowerCase();
      final isPat = role == 'patient';
      if (mounted) setState(() => _isPatient = isPat);

      // 2. Obtener lista de doctores y estadísticas de la clínica en paralelo
      final responses = await Future.wait([
        ApiClient.get('/clinics/$clinicId/doctors'),
        ApiClient.get('/clinics/$clinicId/stats'),
      ]);

      List<dynamic> doctorsList = [];
      if (responses[0].statusCode == 200) {
        doctorsList = jsonDecode(responses[0].body) as List<dynamic>;
      }

      int patientsSum = 0;
      int maxExp = 0;
      double avgRating = 5.0;
      int reviewsCount = 0;
      bool canRate = false;
      int? myRate;

      if (responses[1].statusCode == 200) {
        final statsData = jsonDecode(responses[1].body) as Map<String, dynamic>;
        patientsSum = (statsData['patients_count'] as num?)?.toInt() ?? 0;
        maxExp = (statsData['years_experience'] as num?)?.toInt() ?? 0;
        avgRating = (statsData['rating'] as num?)?.toDouble() ?? 5.0;
        reviewsCount = (statsData['total_reviews'] as num?)?.toInt() ?? 0;
        canRate = statsData['can_rate'] == true;
        myRate = (statsData['my_rating'] as num?)?.toInt();
      } else {
        // Fallback: calcular la suma de pacientes atendidos directamente de los doctores
        for (var doc in doctorsList) {
          if (doc is Map) {
            patientsSum += (doc['patients_count'] as num?)?.toInt() ?? 0;
            final exp = (doc['years_experience'] as num?)?.toInt() ?? 0;
            if (exp > maxExp) maxExp = exp;
          }
        }
      }

      if (mounted) {
        setState(() {
          _doctors = doctorsList;
          _totalPatientsCount = patientsSum;
          _yearsExperience = maxExp;
          _averageRating = avgRating;
          _totalReviews = reviewsCount;
          _canRateClinic = canRate;
          _myClinicRating = myRate;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadFavoriteStatus() async {
    String? userId;
    try {
      final response = await ApiClient.get('/users/me');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        userId = data['id']?.toString();
      }
    } catch (_) {}

    _favoriteStorageKey = 'patient_favorite_clinics_${userId ?? 'current'}';
    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList(_favoriteStorageKey) ?? [];
    final clinicId = widget.clinic['id']?.toString() ?? '';
    if (mounted) {
      setState(() {
        _isFavorite = favorites.contains(clinicId);
      });
    }
  }

  Future<void> _toggleFavorite() async {
    final clinicId = widget.clinic['id']?.toString() ?? '';
    if (clinicId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList(_favoriteStorageKey) ?? [];
    setState(() {
      if (_isFavorite) {
        favorites.remove(clinicId);
        _isFavorite = false;
      } else {
        favorites.add(clinicId);
        _isFavorite = true;
      }
    });
    await prefs.setStringList(_favoriteStorageKey, favorites);
  }

  Future<void> _openRatingPicker() async {
    if (_myClinicRating != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ya calificaste a esta clínica con $_myClinicRating estrella(s).')),
      );
      return;
    }

    var selectedStars = 5;
    final rating = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Califica a esta clínica'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Tu opinión ayuda a otros pacientes a elegir.'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final value = index + 1;
                  return IconButton(
                    tooltip: '$value estrellas',
                    onPressed: () => setDialogState(() => selectedStars = value),
                    icon: Icon(
                      value <= selectedStars
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: const Color(0xFFF2B544),
                      size: 36,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              Text(
                '$selectedStars de 5 estrellas',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0B2545),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(selectedStars),
              child: const Text('Enviar'),
            ),
          ],
        ),
      ),
    );

    if (rating == null || !mounted) return;
    final clinicId = widget.clinic['id'];
    try {
      final response = await ApiClient.post(
        '/clinics/$clinicId/rating',
        {'rating': rating},
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          _averageRating = (data['rating'] as num?)?.toDouble() ?? rating.toDouble();
          _totalReviews = (data['total_reviews'] as num?)?.toInt() ?? 1;
          _myClinicRating = rating;
          _canRateClinic = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gracias por calificar a la clínica.')),
        );
      } else {
        final data = jsonDecode(response.body);
        final detail = data is Map ? data['detail']?.toString() : null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(detail ?? 'No se pudo registrar tu calificación.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al enviar calificación.')),
        );
      }
    }
  }

  void _scrollToDoctors() {
    final context = _doctorsSectionKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final clinic = widget.clinic;
    final name = clinic['first_name']?.toString() ??
        clinic['name']?.toString() ??
        'Clínica';
    final specialtiesList = clinic['specialties'] as List<dynamic>? ?? [];
    final specialtyDisplay = specialtiesList.isNotEmpty
        ? specialtiesList.first.toString()
        : 'Centro de Salud';
    final address = clinic['address']?.toString() ??
        clinic['city']?.toString() ??
        'Venezuela';
    final imageUrl = clinic['avatar_url']?.toString();
    final description = clinic['description']?.toString() ??
        'Centro de atención médica integral comprometido con la salud y bienestar de sus pacientes.';

    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const SizedBox.shrink(),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(4),
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            elevation: 2,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.maybePop(context),
              child: const SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: Icon(Icons.arrow_back_rounded,
                      color: Color(0xFF173A3B), size: 24),
                ),
              ),
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 2,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _toggleFavorite,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: Icon(
                      _isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: _isFavorite
                          ? const Color(0xFFE04F62)
                          : const Color(0xFF173A3B),
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Equipo Médico',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${_doctors.length} médicos activos',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0B2545),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              FilledButton.icon(
                onPressed: _scrollToDoctors,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0756A4),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.people_alt_outlined, size: 18),
                label: const Text(
                  'Ver doctores',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final topInset = MediaQuery.paddingOf(context).top;
          return Stack(
            children: [
              // Fondo azul médico con los 3 orbes animados rebotando
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 265 + topInset,
                child: DoctorHeaderMeshGlow(
                  height: 265 + topInset,
                  topInset: topInset,
                ),
              ),

              // Contenido con scroll
              SingleChildScrollView(
                controller: _scrollController,
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    SizedBox(height: topInset + 42),

                    // Avatar de la clínica (180x180 px con expansión Instagram)
                    Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE7F4FA),
                        borderRadius: BorderRadius.circular(38),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.20),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(38),
                        child: ProfileAvatar(
                          imageUrl: imageUrl,
                          fallbackRole: 'clinic',
                          size: 180,
                          displayName: name,
                          subtitle: specialtyDisplay,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Tarjeta blanca inferior
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(24, 30, 24, 32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(36),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 22,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Nombre de la clínica
                          Text(
                            name,
                            style: const TextStyle(
                              color: Color(0xFF0B2545),
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),

                          // Especialidad / Tipo
                          Text(
                            specialtyDisplay,
                            style: const TextStyle(
                              color: Color(0xFF007A78),
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Ubicación
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined,
                                  size: 16, color: Color(0xFF7C8A7B)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  address,
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 22),

                          // 3 Tarjetas de Estadísticas (Pacientes = Suma de doctores, Experiencia y Rating)
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  icon: Icons.people_outline,
                                  label: 'Pacientes',
                                  value: _totalPatientsCount.toString(),
                                  detail: 'atendidos (equipo)',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildStatCard(
                                  icon: Icons.military_tech_outlined,
                                  label: 'Experiencia',
                                  value: _yearsExperience > 0
                                      ? '$_yearsExperience años'
                                      : 'Destacada',
                                  detail: 'años equipo médico',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildStatCard(
                                  icon: Icons.star_rounded,
                                  label: 'Rating',
                                  value: _averageRating.toStringAsFixed(1),
                                  detail: _totalReviews == 0
                                      ? 'sin votos'
                                      : '$_totalReviews votos',
                                  onTap: _canRateClinic && _myClinicRating == null
                                      ? _openRatingPicker
                                      : null,
                                ),
                              ),
                            ],
                          ),

                          // Opción de calificar
                          if (_canRateClinic || _myClinicRating != null) ...[
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: _canRateClinic
                                  ? TextButton.icon(
                                      onPressed: _openRatingPicker,
                                      icon: const Icon(Icons.star_outline),
                                      label: const Text('Calificar a la clínica'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: const Color(0xFF0756A4),
                                      ),
                                    )
                                  : Text(
                                      'Tu calificación: $_myClinicRating de 5',
                                      style: const TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ],

                          const SizedBox(height: 24),

                          // Descripción / Biografía
                          const Text(
                            'Sobre el centro de salud',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0B2545),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            description,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF475569),
                              height: 1.5,
                            ),
                          ),

                          // Especialidades / Servicios
                          if (specialtiesList.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            const Text(
                              'Especialidades y Servicios',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0B2545),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: specialtiesList.map((spec) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEBF5FF),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: const Color(0xFF38BDF8)
                                          .withOpacity(0.35),
                                    ),
                                  ),
                                  child: Text(
                                    spec.toString(),
                                    style: const TextStyle(
                                      color: Color(0xFF0284C7),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],

                          const SizedBox(height: 28),

                          // Contacto y Teléfonos
                          const Text(
                            'Información de Contacto',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0B2545),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (clinic['phone'] != null &&
                              clinic['phone'].toString().trim().isNotEmpty) ...[
                            _buildContactRow(
                              icon: Icons.phone_outlined,
                              label: 'Teléfono Principal',
                              value: clinic['phone'].toString(),
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (clinic['contact_phone_2'] != null &&
                              clinic['contact_phone_2']
                                  .toString()
                                  .trim()
                                  .isNotEmpty) ...[
                            _buildContactRow(
                              icon: Icons.phone_android_outlined,
                              label: 'Teléfono Secundario',
                              value: clinic['contact_phone_2'].toString(),
                            ),
                            const SizedBox(height: 8),
                          ],
                          _buildContactRow(
                            icon: Icons.location_city_outlined,
                            label: 'Ubicación',
                            value: address,
                          ),

                          const SizedBox(height: 32),

                          // Sección de Doctores Asociados
                          Row(
                            key: _doctorsSectionKey,
                            children: [
                              const Text(
                                'Doctores Asociados',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0B2545),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0756A4),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${_doctors.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          if (_isLoading)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24.0),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          else if (_doctors.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: const Color(0xFFE2E8F0)),
                              ),
                              child: const Column(
                                children: [
                                  Icon(Icons.person_off_outlined,
                                      size: 32, color: Color(0xFF94A3B8)),
                                  SizedBox(height: 8),
                                  Text(
                                    'No hay doctores afiliados en esta clínica actualmente.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: Color(0xFF64748B), fontSize: 13),
                                  ),
                                ],
                              ),
                            )
                          else
                            ..._doctors.map((doc) => _buildDoctorCard(doc)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required String detail,
    VoidCallback? onTap,
  }) {
    return Material(
      color: const Color(0xFFF4F7FB),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 102),
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: const Color(0xFF0756A4)),
              const SizedBox(height: 6),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF17212B),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF475569),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF0756A4)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDoctorCard(dynamic doc) {
    if (doc is! Map) return const SizedBox.shrink();
    final doctorMap = Map<String, dynamic>.from(doc);
    final name = 'Dr. ${doctorMap['first_name'] ?? ''} ${doctorMap['last_name'] ?? ''}'.trim();
    final specialties = (doctorMap['specialties'] as List<dynamic>?)?.join(', ') ?? 'Médico General';
    final rawFee = doctorMap['consultation_fee'];
    final fee = rawFee is num ? rawFee.toDouble() : double.tryParse('$rawFee');
    final feeDisplay = fee == null || fee <= 0
        ? 'Consultar'
        : '\$${fee.toStringAsFixed(fee == fee.roundToDouble() ? 0 : 2)}';
    final rating = (doctorMap['rating'] as num?)?.toDouble() ?? 5.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DoctorProfileScreen(doctor: doctorMap),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: ProfileAvatar(
                    imageUrl: doctorMap['avatar_url']?.toString(),
                    fallbackRole: 'doctor',
                    displayName: name,
                    subtitle: specialties,
                    size: 68,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0B2545),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        specialties,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF007A78),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.star_rounded,
                                  color: Color(0xFFF2B544), size: 16),
                              const SizedBox(width: 3),
                              Text(
                                rating.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            feeDisplay,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0756A4),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
