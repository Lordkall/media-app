import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../core/auth_helper.dart';
import '../core/profile_image_helper.dart';
import '../models/avatar_catalog.dart';
import '../models/ve_catalogs.dart';
import '../widgets/avatar_sprite.dart';
import '../widgets/instagram_photo_preview.dart';
import 'appointment_success_screen.dart';

class DoctorProfileScreen extends StatefulWidget {
  final Map<String, dynamic> doctor;
  final VoidCallback? onViewSchedule;

  const DoctorProfileScreen(
      {super.key, required this.doctor, this.onViewSchedule});

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  late Map<String, dynamic> _doctor = Map<String, dynamic>.from(widget.doctor);
  bool _isFavorite = false;
  bool _favoriteReady = false;
  String _favoriteStorageKey = 'patient_favorite_doctors_current';
  bool _canRateDoctor = false;
  bool _isPatient = false;
  bool _isSelf = false;
  bool _isLoadingRatingState = true;
  int? _myDoctorRating;
  double _averageRating = 5;
  int _totalReviews = 0;
  int _patientsCount = 0;
  late final Future<List<Map<String, dynamic>>> _availability =
      _loadAvailability();
  final ScrollController _bookingDaysController = ScrollController();
  bool _canScrollDaysLeft = false;
  bool _canScrollDaysRight = true;
  DateTime? _selectedBookingDate;
  int? _selectedTurnNumber;
  String? _selectedReason;
  bool _isSubmittingBooking = false;
  final _customReasonController = TextEditingController();
  bool _bookingForDependent = false;
  double? _bcvRate;
  final _dependentNameController = TextEditingController();
  DateTime? _dependentBirthDate;
  String? _dependentRelationship;
  String? _dependentGender;

  @override
  void initState() {
    super.initState();
    _bookingDaysController.addListener(_handleBookingDaysScroll);
    _refreshPublicDoctorData();
    _loadBcvRate();
    _loadRatingState();
    _loadFavoriteStatus();
  }

  Future<void> _loadBcvRate() async {
    try {
      final response = await ApiClient.get('/users/bcv-rate');
      if (response.statusCode != 200) return;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final rawRate = data['rate'];
      final rate =
          rawRate is num ? rawRate.toDouble() : double.tryParse('$rawRate');
      if (rate != null && rate > 0 && mounted) {
        setState(() => _bcvRate = rate);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _customReasonController.dispose();
    _dependentNameController.dispose();
    _bookingDaysController.dispose();
    super.dispose();
  }

  Future<void> _refreshPublicDoctorData() async {
    try {
      final response = await ApiClient.get('/doctors/public');
      if (response.statusCode != 200) return;
      final doctors = jsonDecode(response.body) as List<dynamic>;
      Map<String, dynamic>? current;
      for (final item in doctors) {
        if (item is Map &&
            item['id']?.toString() == widget.doctor['id']?.toString()) {
          current = Map<String, dynamic>.from(item);
          break;
        }
      }
      if (current != null && mounted) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final cacheKey = 'doctor_years_experience_${current['id']}';
          final cachedExperience = prefs.getInt(cacheKey);
          final apiExperience =
              (current['years_experience'] as num?)?.toInt() ?? 0;
          if (cachedExperience != null && apiExperience == 0) {
            current['years_experience'] = cachedExperience;
          } else if (cachedExperience != null) {
            await prefs.remove(cacheKey);
          }
        } catch (_) {}
        if (!mounted) return;
        setState(() {
          _doctor = current!;
          _averageRating = (current['rating'] as num?)?.toDouble() ?? 5.0;
          _totalReviews = (current['total_reviews'] as num?)?.toInt() ?? 0;
          _patientsCount = (current['patients_count'] as num?)?.toInt() ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadRatingState() async {
    final doctorId = _doctor['id'];
    if (doctorId == null) {
      if (mounted) setState(() => _isLoadingRatingState = false);
      return;
    }
    try {
      final currentUserId = await AuthHelper.getUserId();
      final doctorUserId = _doctor['user_id']?.toString();
      if (currentUserId != null && doctorUserId != null && currentUserId == doctorUserId) {
        if (mounted) {
          setState(() {
            _isSelf = true;
            _canRateDoctor = false;
            _isLoadingRatingState = false;
          });
        }
        return;
      }

      final response = await ApiClient.get('/doctors/$doctorId/rating/me');
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final isSelf = data['is_self'] == true;
        _isSelf = isSelf;
        _canRateDoctor = data['can_rate'] == true && !isSelf;
        _myDoctorRating = (data['my_rating'] as num?)?.toInt();
      } else {
        _canRateDoctor = false;
      }
    } catch (_) {
      _canRateDoctor = false;
    }
    if (mounted) setState(() => _isLoadingRatingState = false);
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
    final key = 'patient_favorite_doctors_${userId ?? 'current'}';
    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList(key) ?? [];
    if (!mounted) return;
    setState(() {
      _favoriteStorageKey = key;
      _isFavorite = favorites.contains(_doctor['id']?.toString());
      _favoriteReady = true;
    });
  }

  Future<void> _toggleFavorite() async {
    final doctorId = _doctor['id']?.toString();
    if (doctorId == null || !_favoriteReady) return;
    final prefs = await SharedPreferences.getInstance();
    final favorites = (prefs.getStringList(_favoriteStorageKey) ?? []).toSet();
    if (_isFavorite) {
      favorites.remove(doctorId);
    } else {
      favorites.add(doctorId);
    }
    await prefs.setStringList(_favoriteStorageKey, favorites.toList());
    if (mounted) setState(() => _isFavorite = !_isFavorite);
  }

  Future<void> _submitDoctorRating(int stars) async {
    final doctorId = _doctor['id'];
    if (doctorId == null || _isSelf) return;
    try {
      final response = await ApiClient.post(
        '/doctors/$doctorId/rating',
        {'rating': stars},
      );
      if (!mounted) return;
      final data = jsonDecode(response.body);
      if ((response.statusCode == 200 || response.statusCode == 201) && data is Map) {
        setState(() {
          _averageRating =
              (data['rating'] as num?)?.toDouble() ?? stars.toDouble();
          _totalReviews = (data['total_reviews'] as num?)?.toInt() ?? 1;
          _myDoctorRating = stars;
          _canRateDoctor = false;
          _doctor['rating'] = _averageRating;
          _doctor['total_reviews'] = _totalReviews;
        });
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gracias por calificar al doctor.')));
      } else {
        final detail = data is Map ? data['detail']?.toString() : null;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(detail ?? 'No se pudo guardar tu calificación.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No se pudo conectar para enviar tu calificación.')));
      }
    }
  }

  Future<void> _openRatingPicker() async {
    if (_isSelf) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No puedes calificarte a ti mismo.')),
      );
      return;
    }
    if (_myDoctorRating != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ya calificaste a este doctor con $_myDoctorRating estrella(s).')));
      return;
    }
    var selectedStars = 5;
    final rating = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Califica a este doctor'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Tu opinión ayuda a otros pacientes.'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final value = index + 1;
                  return IconButton(
                    tooltip: '$value estrellas',
                    onPressed: () =>
                        setDialogState(() => selectedStars = value),
                    icon: Icon(
                      value <= selectedStars ? Icons.star : Icons.star_border,
                      color: const Color(0xFFF2B544),
                      size: 32,
                    ),
                  );
                }),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Ahora no'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, selectedStars),
              child: const Text('Enviar'),
            ),
          ],
        ),
      ),
    );
    if (rating != null) await _submitDoctorRating(rating);
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<List<Map<String, dynamic>>> _loadAvailability() async {
    final id = widget.doctor['id'];
    if (id == null) return [];
    try {
      final response = await ApiClient.get('/doctors/$id/availability');
      if (response.statusCode != 200) return [];
      final rows = (jsonDecode(response.body) as List<dynamic>)
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      final today = _dateKey(caracasNow());
      return rows.where((day) {
        final slots = day['slots'] as List<dynamic>? ?? [];
        return (day['date']?.toString() ?? '').compareTo(today) >= 0 &&
            day['is_full'] != true &&
            slots.any((slot) => slot is Map && slot['available'] == true);
      }).toList()
        ..sort((a, b) => a['date'].toString().compareTo(b['date'].toString()));
    } catch (_) {
      return [];
    }
  }

  List<Map<String, dynamic>> _availableSlots(Map<String, dynamic> day) =>
      ((day['slots'] as List<dynamic>?) ?? [])
          .whereType<Map>()
          .where((slot) => slot['available'] == true)
          .map((slot) => Map<String, dynamic>.from(slot))
          .toList();

  Future<void> _bookAppointment(List<Map<String, dynamic>> days) async {
    if (_isSubmittingBooking) return;
    final date = _selectedBookingDate;
    if (_selectedReason == null) {
      _showBookingMessage('Selecciona el motivo de la cita.');
      return;
    }
    if (_selectedReason == 'Otros' &&
        _customReasonController.text.trim().isEmpty) {
      _showBookingMessage('Describe brevemente el motivo de la cita.');
      return;
    }
    if (date == null || _selectedTurnNumber == null) {
      _showBookingMessage('Selecciona un día y un turno disponible.');
      return;
    }
    if (_bookingForDependent &&
        (_dependentNameController.text.trim().isEmpty ||
            _dependentBirthDate == null ||
            _dependentRelationship == null)) {
      _showBookingMessage('Completa los datos de la persona que atenderás.');
      return;
    }

    final reason = _selectedReason == 'Otros'
        ? _customReasonController.text.trim()
        : _selectedReason!;
    final request = <String, dynamic>{
      'doctor_id': int.tryParse(_doctor['id'].toString()),
      'appointment_date': _dateKey(date),
      'turn_number': _selectedTurnNumber,
      'appointment_reason': reason,
      'is_for_dependent': _bookingForDependent,
      if (_bookingForDependent) ...{
        'dependent_name': _dependentNameController.text.trim(),
        'dependent_birth_date': _dateKey(_dependentBirthDate!),
        'dependent_relationship': _dependentRelationship,
        'dependent_gender': _dependentGender,
      },
    };

    try {
      setState(() => _isSubmittingBooking = true);
      if (!await _confirmSameDayAppointment(_dateKey(date))) return;
      final response = await ApiClient.post('/appointments/', request);
      if (!mounted) return;
      if (response.statusCode != 201) {
        var message = 'No se pudo agendar la cita.';
        try {
          message = jsonDecode(response.body)['detail']?.toString() ?? message;
        } catch (_) {}
        _showBookingMessage(message);
        return;
      }

      final matchingDay = days.firstWhere(
        (item) => item['date']?.toString() == _dateKey(date),
        orElse: () => <String, dynamic>{},
      );
      final slot = _availableSlots(matchingDay).firstWhere(
        (item) => item['turn_number'] == _selectedTurnNumber,
        orElse: () => <String, dynamic>{},
      );
      final specialties = _doctor['specialties'] as List<dynamic>? ?? [];
      final appointment = <String, dynamic>{
        'date': _dateKey(date),
        'time_block': slot['time_block'] ?? 'Hora por confirmar',
        'turn_number': _selectedTurnNumber,
        'doctor_name': 'Dr. ${_doctor['first_name']} ${_doctor['last_name']}',
        'doctor_specialty':
            specialties.isEmpty ? 'Especialista' : specialties.first,
        'doctor_avatar': _doctor['avatar_url'],
      };
      final successAction = await Navigator.of(context, rootNavigator: true)
          .push<AppointmentSuccessAction>(MaterialPageRoute(
        builder: (_) => AppointmentSuccessScreen(
          doctor: _doctor,
          appointment: appointment,
        ),
      ));
      if (successAction == AppointmentSuccessAction.viewSchedule) {
        widget.onViewSchedule?.call();
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) _showBookingMessage('No se pudo conectar para agendar.');
    } finally {
      if (mounted) setState(() => _isSubmittingBooking = false);
    }
  }

  Future<bool> _confirmSameDayAppointment(String date) async {
    try {
      final response = await ApiClient.get('/appointments/my');
      if (response.statusCode != 200) {
        _showBookingMessage(
            'No se pudieron revisar tus citas. Inténtalo de nuevo.');
        return false;
      }
      final items = jsonDecode(response.body) as List<dynamic>;
      final sameDay = items
          .where((item) =>
              item['date']?.toString().startsWith(date) == true &&
              item['status']?.toString().toLowerCase() == 'scheduled' &&
              item['doctor_id']?.toString() == _doctor['id']?.toString())
          .length;
      if (sameDay >= 2) {
        _showBookingMessage(
            'Ya tienes el máximo de dos citas con este doctor para ese día.');
        return false;
      }
      if (sameDay == 0 || !mounted) return true;
      return await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Ya tienes una cita con este doctor'),
              content: const Text(
                  'Ya tienes una cita programada con este doctor para ese día. ¿Deseas agendar otra?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Continuar'),
                ),
              ],
            ),
          ) ??
          false;
    } catch (_) {
      if (mounted) _showBookingMessage('No se pudieron revisar tus citas.');
      return false;
    }
  }

  void _showBookingMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildSquarePortrait(String? imageUrl) {
    final preset = AvatarCatalog.parse(imageUrl);
    final defaultAvatar = imageUrl == null || imageUrl.trim().isEmpty;
    final doctorName =
        'Dr. ${_doctor['first_name'] ?? ''} ${_doctor['last_name'] ?? ''}'.trim();
    final specialties =
        (_doctor['specialties'] as List<dynamic>?)?.join(', ');
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () {
        InstagramPhotoPreview.show(
          context,
          imageUrl: imageUrl,
          fallbackRole: 'doctor',
          title: doctorName.isEmpty ? 'Doctor' : doctorName,
          subtitle: specialties,
        );
      },
      child: Container(
        width: 180,
        height: 180,
        decoration: BoxDecoration(
          color: const Color(0xFFE7F4FA),
          borderRadius: BorderRadius.circular(38),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .2),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(38),
          child: preset != null || defaultAvatar
              ? AvatarSprite(
                  role: preset?.role ?? 'doctor',
                  index: preset?.index ?? 0,
                  size: 180,
                )
              : Image(
                  image: ProfileImageHelper.getProfileImageProvider(imageUrl),
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, __, ___) => const ColoredBox(
                    color: Color(0xFFE0EAFC),
                    child:
                        Icon(Icons.person, size: 90, color: Color(0xFF0056B3)),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildBookingSection() => FutureBuilder<List<Map<String, dynamic>>>(
        future: _availability,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF0056B3))),
            );
          }
          final days = snapshot.data ?? const <Map<String, dynamic>>[];
          if (days.isEmpty) {
            return _bookingCard(
              title: 'Agenda tu cita',
              child: const Text('Este doctor aún no tiene turnos disponibles.'),
            );
          }
          final firstAvailableDate =
              DateTime.parse(days.first['date'].toString());
          final selectedDate = _selectedBookingDate ?? firstAvailableDate;
          final selectedDay = days.firstWhere(
            (day) => day['date']?.toString() == _dateKey(selectedDate),
            orElse: () => days.first,
          );
          final slots = _availableSlots(selectedDay);
          final selectedTurn = _selectedTurnNumber ??
              (slots.isEmpty ? null : slots.first['turn_number'] as int?);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _bookingCard(
                title: 'Elige un día',
                child: Builder(
                  builder: (context) {
                    final showArrows = days.length > 3;
                    return Row(
                      children: [
                        if (showArrows)
                          _bookingDayArrow(
                            icon: Icons.arrow_back_ios_new_rounded,
                            tooltip: 'Ver días anteriores',
                            enabled: _canScrollDaysLeft,
                            onPressed: () => _scrollBookingDays(-1),
                          ),
                        Expanded(
                          child: SizedBox(
                            height: 84,
                            child: ListView.separated(
                              controller: _bookingDaysController,
                              scrollDirection: Axis.horizontal,
                              itemCount: days.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 10),
                              itemBuilder: (context, index) {
                                final day = days[index];
                                final date =
                                    DateTime.parse(day['date'].toString());
                                final selected =
                                    _dateKey(date) == _dateKey(selectedDate);
                                return _buildBookingDayCard(
                                  day: day,
                                  date: date,
                                  isSelected: selected,
                                  onTap: () {
                                    final options = _availableSlots(day);
                                    setState(() {
                                      _selectedBookingDate = date;
                                      _selectedTurnNumber = options.isEmpty
                                          ? null
                                          : options.first['turn_number']
                                              as int?;
                                    });
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                        if (showArrows)
                          _bookingDayArrow(
                            icon: Icons.arrow_forward_ios_rounded,
                            tooltip: 'Ver más días',
                            enabled: _canScrollDaysRight,
                            onPressed: () => _scrollBookingDays(1),
                          ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              _bookingCard(
                title: 'Elige una hora',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: slots.map((slot) {
                    final turn = slot['turn_number'] as int?;
                    final chosen = turn == selectedTurn;
                    return ChoiceChip(
                      label: Text('${slot['time_block'] ?? 'Turno'}'),
                      selected: chosen,
                      selectedColor: const Color(0xFF0056B3),
                      backgroundColor: const Color(0xFFEAF2FC),
                      labelStyle: TextStyle(
                        color: chosen ? Colors.white : const Color(0xFF0B2545),
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (_) => setState(() {
                        _selectedBookingDate = selectedDate;
                        _selectedTurnNumber = turn;
                      }),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 14),
              _bookingCard(
                title: 'Motivo de la cita',
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedReason,
                      decoration:
                          _bookingFieldDecoration('Selecciona un motivo'),
                      items: const [
                        DropdownMenuItem(
                            value: 'Consulta', child: Text('Consulta')),
                        DropdownMenuItem(
                            value: 'Entrega de examenes',
                            child: Text('Entrega de exámenes')),
                        DropdownMenuItem(value: 'Cura', child: Text('Cura')),
                        DropdownMenuItem(
                            value: 'Otros', child: Text('Otro motivo')),
                      ],
                      onChanged: (value) => setState(() {
                        _selectedReason = value;
                        if (value != 'Otros') _customReasonController.clear();
                      }),
                    ),
                    if (_selectedReason == 'Otros') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _customReasonController,
                        decoration:
                            _bookingFieldDecoration('Describe el motivo'),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _bookingCard(
                title: '¿La cita es para ti?',
                child: Column(
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        activeColor: const Color(0xFF0056B3),
                        title:
                            const Text('Es para un menor o alguien a mi cargo'),
                        subtitle:
                            const Text('Agrega sus datos para la reserva.'),
                        value: _bookingForDependent,
                        onChanged: (value) => setState(() {
                          _bookingForDependent = value;
                          if (!value) {
                            _dependentNameController.clear();
                            _dependentBirthDate = null;
                            _dependentRelationship = null;
                            _dependentGender = null;
                          }
                        }),
                      ),
                    ),
                    if (_bookingForDependent) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _dependentNameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: _bookingFieldDecoration('Nombre completo'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _selectDependentBirthDate,
                        icon: const Icon(Icons.cake_outlined),
                        label: Text(_dependentBirthDate == null
                            ? 'Fecha de nacimiento'
                            : 'Nacimiento: ${_dateLabel(_dependentBirthDate!)}'),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: _dependentRelationship,
                        decoration: _bookingFieldDecoration('Parentesco'),
                        items: const [
                          'Hijo',
                          'Hija',
                          'Abuelo',
                          'Abuela',
                          'Padre',
                          'Madre',
                          'Tutor',
                          'Representante legal'
                        ]
                            .map((value) => DropdownMenuItem(
                                value: value, child: Text(value)))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _dependentRelationship = value),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: _dependentGender,
                        decoration:
                            _bookingFieldDecoration('Género (opcional)'),
                        items: const [
                          'Masculino',
                          'Femenino',
                          'Otro / Prefiero no decirlo'
                        ]
                            .map((value) => DropdownMenuItem(
                                value: value, child: Text(value)))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _dependentGender = value),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      );

  Widget _bookingCard({required String title, required Widget child}) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0B2545).withValues(alpha: .06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    color: Color(0xFF0B2545),
                    fontWeight: FontWeight.w800,
                    fontSize: 16)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );

  InputDecoration _bookingFieldDecoration(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF7FAFE),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD5E2F1)),
        ),
      );

  String _weekdayShort(DateTime date) =>
      const ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'][date.weekday - 1];

  String _monthShort(DateTime date) => const [
        'Ene',
        'Feb',
        'Mar',
        'Abr',
        'May',
        'Jun',
        'Jul',
        'Ago',
        'Sep',
        'Oct',
        'Nov',
        'Dic'
      ][date.month - 1];

  String _dateLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  Future<void> _selectDependentBirthDate() async {
    final today = caracasNow();
    final date = await showDatePicker(
      context: context,
      initialDate: _dependentBirthDate ?? today,
      firstDate: DateTime(1900),
      lastDate: today,
      helpText: 'Nacimiento del paciente',
    );
    if (date != null && mounted) setState(() => _dependentBirthDate = date);
  }

  void _handleBookingDaysScroll() {
    if (!_bookingDaysController.hasClients || !mounted) return;
    final position = _bookingDaysController.position;
    final canScrollLeft = position.pixels > 2;
    final canScrollRight = position.pixels < position.maxScrollExtent - 2;
    if (canScrollLeft != _canScrollDaysLeft ||
        canScrollRight != _canScrollDaysRight) {
      setState(() {
        _canScrollDaysLeft = canScrollLeft;
        _canScrollDaysRight = canScrollRight;
      });
    }
  }

  void _scrollBookingDays(int direction) {
    if (!_bookingDaysController.hasClients) return;
    final position = _bookingDaysController.position;
    final nextOffset = (position.pixels + direction * 180)
        .clamp(0.0, position.maxScrollExtent);
    _bookingDaysController.animateTo(
      nextOffset,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _bookingDayArrow({
    required IconData icon,
    required String tooltip,
    required bool enabled,
    required VoidCallback onPressed,
  }) =>
      SizedBox(
        width: 32,
        child: IconButton(
          tooltip: tooltip,
          onPressed: enabled ? onPressed : null,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 32, height: 44),
          style: IconButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: Icon(icon, color: const Color(0xFF0056B3), size: 17),
        ),
      );

  Widget _buildBookingDayCard({
    required Map<String, dynamic> day,
    required DateTime date,
    required bool isSelected,
    required VoidCallback onTap,
  }) =>
      InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedScale(
          scale: isSelected ? 1.04 : 1,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutBack,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            width: 68,
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF0756A4), Color(0xFF0A3D78)],
                    )
                  : null,
              color: isSelected ? null : const Color(0xFFEAF2FC),
              borderRadius: BorderRadius.circular(16),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF0756A4).withValues(alpha: .22),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : const [],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_weekdayShort(date),
                    style: TextStyle(
                        color: isSelected
                            ? Colors.white70
                            : const Color(0xFF64748B),
                        fontSize: 11)),
                const SizedBox(height: 3),
                Text('${date.day}',
                    style: TextStyle(
                        color:
                            isSelected ? Colors.white : const Color(0xFF0B2545),
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
                Text(_monthShort(date),
                    style: TextStyle(
                        color: isSelected
                            ? Colors.white70
                            : const Color(0xFF64748B),
                        fontSize: 10)),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final doctor = _doctor;
    final name = 'Dr. ${doctor['first_name']} ${doctor['last_name']}';
    final specialties = (doctor['specialties'] as List<dynamic>?)?.join(', ') ??
        'Médico General';
    final clinicAddress = [
      doctor['address'],
      doctor['clinic_info'],
      doctor['state'],
    ]
        .map((value) => value?.toString().trim() ?? '')
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    final imageUrl = doctor['avatar_url'];
    final rawFee = doctor['consultation_fee'];
    final consultationFee =
        rawFee is num ? rawFee.toDouble() : double.tryParse('$rawFee') ?? 50;

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
              color: const Color(0xFFF7F4EA),
              shape: const CircleBorder(),
              child: IconButton(
                tooltip:
                    _isFavorite ? 'Quitar de favoritos' : 'Agregar a favoritos',
                onPressed: _favoriteReady ? _toggleFavorite : null,
                icon: Icon(
                  _isFavorite ? Icons.favorite : Icons.favorite_border_rounded,
                  color: _isFavorite
                      ? const Color(0xFFE34F62)
                      : const Color(0xFF67736F),
                  size: 23,
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0B2545).withValues(alpha: .12),
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
                    const Text('Consulta',
                        style: TextStyle(color: Color(0xFF64748B))),
                    Text(
                      '\$${consultationFee.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Color(0xFF0B2545),
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (_bcvRate != null)
                      Text(
                        'Bs. ${(consultationFee * _bcvRate!).toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Color(0xFF0056B3),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 52,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF0756A4), Color(0xFF0A3D78)],
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _isSubmittingBooking
                          ? null
                          : () => _availability.then(_bookAppointment),
                      icon: _isSubmittingBooking
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.calendar_month_rounded),
                      label: Text(
                          _isSubmittingBooking ? 'Agendando…' : 'Agendar cita'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        surfaceTintColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final topInset = MediaQuery.paddingOf(context).top;
          return Stack(
            children: [
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
              SingleChildScrollView(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    SizedBox(height: topInset + 42),
                    _buildSquarePortrait(imageUrl?.toString()),
                    const SizedBox(height: 20),
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
                            color: Colors.black.withValues(alpha: .12),
                            blurRadius: 22,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: const TextStyle(
                                  fontSize: 25,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0B2545))),
                          const SizedBox(height: 5),
                          Text(specialties,
                              style: const TextStyle(
                                  fontSize: 16, color: Color(0xFF475569))),
                          if (clinicAddress.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.location_on_outlined,
                                    size: 17, color: Color(0xFF0056B3)),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(clinicAddress,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF475569))),
                                ),
                              ],
                            ),
                          ],
                          if (doctor['medical_license_number']
                                  ?.toString()
                                  .isNotEmpty ??
                              false) ...[
                            const SizedBox(height: 5),
                            Text('Cédula: ${doctor['medical_license_number']}',
                                style: const TextStyle(
                                    fontSize: 13, color: Color(0xFF64748B))),
                          ],
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  icon: Icons.people_alt_outlined,
                                  label: 'Pacientes',
                                  value: _formatPatientCount(_patientsCount),
                                  detail: 'atendidos',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildStatCard(
                                  icon: Icons.workspace_premium_outlined,
                                  label: 'Experiencia',
                                  value:
                                      '${(doctor['years_experience'] as num?)?.toInt() ?? 0}',
                                  detail: 'años',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildStatCard(
                                  icon: Icons.star_rounded,
                                  label: 'Rating',
                                  value: _averageRating.toStringAsFixed(1),
                                  detail: _totalReviews == 0
                                      ? 'sin votos'
                                      : '$_totalReviews votos',
                                  onTap: !_isSelf &&
                                          !_isLoadingRatingState &&
                                          _myDoctorRating == null
                                      ? _openRatingPicker
                                      : null,
                                ),
                              ),
                            ],
                          ),
                          if (!_isLoadingRatingState && !_isSelf) ...[
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: _canRateDoctor
                                  ? TextButton.icon(
                                      onPressed: _openRatingPicker,
                                      icon: const Icon(Icons.star_outline),
                                      label: const Text('Calificar al doctor'),
                                      style: TextButton.styleFrom(
                                        foregroundColor:
                                            const Color(0xFF0756A4),
                                      ),
                                    )
                                  : (_myDoctorRating != null
                                      ? Text(
                                          'Tu calificación: $_myDoctorRating de 5',
                                          style: const TextStyle(
                                            color: Color(0xFF64748B),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        )
                                      : const SizedBox.shrink()),
                            ),
                          ],
                          const SizedBox(height: 22),
                          const Text('Biografía',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0B2545))),
                          const SizedBox(height: 8),
                          Text(
                            doctor['bio']?.toString().isNotEmpty == true
                                ? doctor['bio'].toString()
                                : 'Médico especialista con atención integral y personalizada.',
                            style: const TextStyle(
                                fontSize: 14, color: Color(0xFF475569)),
                          ),
                          const SizedBox(height: 24),
                          _buildBookingSection(),
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

  String _formatPatientCount(int count) {
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required String detail,
    VoidCallback? onTap,
  }) {
    final radius = BorderRadius.circular(18);
    return Material(
      color: const Color(0xFFE5EFFB),
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          constraints: const BoxConstraints(minHeight: 102),
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 17, color: const Color(0xFF0756A4)),
              const SizedBox(height: 5),
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Color(0xFF17212B),
                      fontSize: 17,
                      fontWeight: FontWeight.w800)),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Color(0xFF475569),
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
              Text(detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(color: Color(0xFF64748B), fontSize: 9)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Encabezado con efecto Mesh Gradient / Orbes de luz flotantes
/// que dan un efecto de halo brillante, limpio y moderno detrás de la foto del doctor.
class DoctorHeaderMeshGlow extends StatefulWidget {
  final double height;
  final double topInset;

  const DoctorHeaderMeshGlow({
    super.key,
    required this.height,
    required this.topInset,
  });

  @override
  State<DoctorHeaderMeshGlow> createState() => _DoctorHeaderMeshGlowState();
}

class _DoctorHeaderMeshGlowState extends State<DoctorHeaderMeshGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Controlador continuo de alta precisión para las físicas de rebote
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 120),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Calcula la posición rebotando elásticamente entre [min] y [max]
  double _bounce({
    required double t,
    required double speed,
    required double offset,
    required double min,
    required double max,
  }) {
    final range = max - min;
    if (range <= 0) return min;
    // Ciclo continuo que rebota en 0 y en 1
    final progress = (t * speed + offset) % 2.0;
    final factor = progress > 1.0 ? 2.0 - progress : progress;
    // Frena al tocar la pared y acelera al rebotar (curva senoidal)
    final smooth = (1.0 - math.cos(factor * math.pi)) / 2.0;
    return min + smooth * range;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final headerHeight = widget.height;
    // Centro del avatar (ubicado en topInset + 42 y 180 px de altura)
    final avatarCenterY = widget.topInset + 42 + 90;
    final centerX = screenWidth * 0.5;

    return ClipRect(
      child: Container(
        height: headerHeight,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF062952), Color(0xFF0A4480)],
          ),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            // Tiempo continuo transcurrido en segundos
            final t = _controller.value * 120.0;

            // --- Orbe 1: Cian Eléctrico (260 px) ---
            const s1 = 260.0;
            final x1 = _bounce(
              t: t,
              speed: 0.17,
              offset: 0.2,
              min: -s1 * 0.35,
              max: screenWidth - s1 * 0.65,
            );
            final y1 = _bounce(
              t: t,
              speed: 0.13,
              offset: 0.7,
              min: -s1 * 0.25,
              max: headerHeight - s1 * 0.70,
            );

            // --- Orbe 2: Azul Cielo / Índigo Neón (280 px) ---
            const s2 = 280.0;
            final x2 = _bounce(
              t: t,
              speed: 0.14,
              offset: 1.1,
              min: -s2 * 0.35,
              max: screenWidth - s2 * 0.65,
            );
            final y2 = _bounce(
              t: t,
              speed: 0.21,
              offset: 0.3,
              min: -s2 * 0.25,
              max: headerHeight - s2 * 0.70,
            );

            // --- Orbe 3: Turquesa Menta Brillante (240 px) ---
            const s3 = 240.0;
            final x3 = _bounce(
              t: t,
              speed: 0.22,
              offset: 1.6,
              min: -s3 * 0.35,
              max: screenWidth - s3 * 0.65,
            );
            final y3 = _bounce(
              t: t,
              speed: 0.16,
              offset: 1.2,
              min: -s3 * 0.25,
              max: headerHeight - s3 * 0.70,
            );

            return Stack(
              clipBehavior: Clip.none,
              children: [
                // Orbe 1: Cian eléctrico (#00E5FF a #38BDF8)
                Positioned(
                  left: x1,
                  top: y1,
                  child: Container(
                    width: s1,
                    height: s1,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF00E5FF).withOpacity(0.70),
                          const Color(0xFF38BDF8).withOpacity(0.45),
                          const Color(0xFF0284C7).withOpacity(0.20),
                          const Color(0xFF0284C7).withOpacity(0.0),
                        ],
                        stops: const [0.0, 0.32, 0.65, 1.0],
                      ),
                    ),
                  ),
                ),

                // Orbe 2: Azul cielo / Índigo neón (#60A5FA a #818CF8)
                Positioned(
                  left: x2,
                  top: y2,
                  child: Container(
                    width: s2,
                    height: s2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF60A5FA).withOpacity(0.65),
                          const Color(0xFF818CF8).withOpacity(0.40),
                          const Color(0xFF1D4ED8).withOpacity(0.18),
                          const Color(0xFF1D4ED8).withOpacity(0.0),
                        ],
                        stops: const [0.0, 0.35, 0.68, 1.0],
                      ),
                    ),
                  ),
                ),

                // Orbe 3: Turquesa menta luminosa (#2DD4BF a #38BDF8)
                Positioned(
                  left: x3,
                  top: y3,
                  child: Container(
                    width: s3,
                    height: s3,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF2DD4BF).withOpacity(0.65),
                          const Color(0xFF38BDF8).withOpacity(0.38),
                          const Color(0xFF0EA5E9).withOpacity(0.16),
                          const Color(0xFF0EA5E9).withOpacity(0.0),
                        ],
                        stops: const [0.0, 0.32, 0.65, 1.0],
                      ),
                    ),
                  ),
                ),

                // Halo sutil constante detrás de la foto para rim-light perfecto
                Positioned(
                  left: centerX - 120,
                  top: avatarCenterY - 120,
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFBAE6FD).withOpacity(0.40),
                          const Color(0xFF38BDF8).withOpacity(0.18),
                          const Color(0xFF38BDF8).withOpacity(0.0),
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
