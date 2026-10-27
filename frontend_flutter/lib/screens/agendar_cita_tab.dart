import 'package:flutter/material.dart';
import '../core/api_client.dart';
import 'dart:convert';
import 'package:table_calendar/table_calendar.dart';
import '../models/ve_catalogs.dart';
import 'appointment_details_dialog.dart';
import '../core/app_navigator.dart';

class AgendarCitaTab extends StatefulWidget {
  final VoidCallback? onCitaAgendada;
  final int? initialDoctorId;
  const AgendarCitaTab({super.key, this.onCitaAgendada, this.initialDoctorId});

  @override
  State<AgendarCitaTab> createState() => _AgendarCitaTabState();
}

class _AgendarCitaTabState extends State<AgendarCitaTab> {
  String? _selectedEstado;
  String? _selectedEspecialidad;
  bool _allSpecialtiesSelected = false;
  int? _selectedDoctorId;
  int? _selectedTurnNumber;
  String? _selectedMotivo;
  bool _bookingForDependent = false;
  DateTime? _dependentBirthDate;
  String? _dependentRelationship;
  String? _dependentGender;
  final TextEditingController _dependentNameController =
      TextEditingController();
  final TextEditingController _customMotivoController = TextEditingController();

  List<dynamic> _allDoctors = [];
  bool _isLoading = true;
  List<dynamic> _doctorAvailabilityInfo = [];
  DateTime _selectedDate = caracasNow();

  @override
  void initState() {
    super.initState();
    _fetchDoctors();
  }

  Future<void> _fetchDoctors() async {
    try {
      final responses = await Future.wait([
        ApiClient.get('/doctors/public'),
        ApiClient.get('/users/me'),
      ]);
      final response = responses[0];
      if (response.statusCode == 200) {
        final List<dynamic> docs = jsonDecode(response.body);
        final user = responses[1].statusCode == 200
            ? jsonDecode(responses[1].body)
            : null;
        final profileState = user?['state']?.toString();
        if (mounted) {
          setState(() {
            _allDoctors = docs
                .where((d) => d['plan'] != 'Ninguno' || d['clinic_id'] != null)
                .toList();
            if (profileState != null && veStates.contains(profileState)) {
              _selectedEstado = profileState;
            }
            if (widget.initialDoctorId != null) {
              final doctor = _findDoctor(widget.initialDoctorId);
              if (doctor != null) {
                _selectedEstado = doctor['state']?.toString();
                final specialties = (doctor['specialties'] as List? ?? const [])
                    .map((item) => item.toString())
                    .toList();
                _selectedEspecialidad =
                    specialties.isEmpty ? null : specialties.first;
                _selectedDoctorId = widget.initialDoctorId;
              }
            }
            _isLoading = false;
          });
          if (widget.initialDoctorId != null) {
            final doctor = _findDoctor(widget.initialDoctorId);
            if (doctor != null) await _loadDoctorAvailability(doctor);
          }
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<String> get _availableStates {
    return veStates;
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<bool> _confirmSameDayAppointment(int doctorId, String date) async {
    try {
      final response = await ApiClient.get('/appointments/my');
      if (response.statusCode != 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('No se pudieron revisar tus citas. Inténtalo de nuevo.'),
          ));
        }
        return false;
      }
      final appointments = jsonDecode(response.body) as List<dynamic>;
      final sameDay = appointments
          .where((item) =>
              item['date']?.toString().startsWith(date) == true &&
              item['status']?.toString().toLowerCase() == 'scheduled')
          .toList();
      final sameDoctorCount = sameDay
          .where((item) => item['doctor_id']?.toString() == doctorId.toString())
          .length;
      if (sameDoctorCount >= 2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Ya tienes el máximo de dos citas con este doctor para ese día.'),
          ));
        }
        return false;
      }
      if (sameDay.isEmpty || !mounted) return true;
      return await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Ya tienes una cita ese día'),
              content: const Text(
                  'Ya tienes una cita programada para ese día. ¿Deseas agendar otra?'),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('No se pudieron revisar tus citas. Inténtalo de nuevo.'),
        ));
      }
      return false;
    }
  }

  Map<String, dynamic>? get _selectedDayAvailability {
    final date = _dateKey(_selectedDate);
    for (final item in _doctorAvailabilityInfo) {
      if (item['date'] == date) return Map<String, dynamic>.from(item);
    }
    return null;
  }

  List<Map<String, dynamic>> get _availableSlots {
    final slots = _selectedDayAvailability?['slots'] as List<dynamic>? ?? [];
    return slots
        .where((slot) => slot['available'] == true)
        .map((slot) => Map<String, dynamic>.from(slot))
        .toList();
  }

  List<String> get _availableSpecialties {
    List<String> specs = [];
    for (var doc in _allDoctors) {
      if (_selectedEstado != null &&
          doc['state']?.toString() != _selectedEstado) {
        continue;
      }
      if (doc['specialties'] != null) {
        for (var s in doc['specialties']) {
          if (!specs.contains(s.toString())) specs.add(s.toString());
        }
      }
    }
    specs.sort();
    return specs;
  }

  List<Map<String, dynamic>> get _availableDoctors {
    final docs = <Map<String, dynamic>>[];
    for (var doc in _allDoctors) {
      if (_selectedEstado != null &&
          doc['state']?.toString() != _selectedEstado) {
        continue;
      }

      bool hasSpec = false;
      if (doc['specialties'] != null) {
        for (var s in doc['specialties']) {
          if (s.toString() == _selectedEspecialidad) {
            hasSpec = true;
            break;
          }
        }
      }

      if (_selectedEspecialidad != null && !hasSpec) continue;

      docs.add(Map<String, dynamic>.from(doc));
    }
    docs.sort((a, b) => _doctorDisplayName(a).compareTo(_doctorDisplayName(b)));
    return docs;
  }

  String _doctorDisplayName(Map<String, dynamic> doctor) {
    final name = 'Dr. ${doctor['first_name']} ${doctor['last_name']}'.trim();
    final location =
        (doctor['clinic_info'] ?? doctor['address'])?.toString().trim();
    final state = doctor['state']?.toString().trim();
    final details = [
      if (location != null && location.isNotEmpty) location,
      if (state != null && state.isNotEmpty) state,
    ].join(' · ');
    return details.isEmpty ? name : '$name · $details';
  }

  Map<String, dynamic>? _findDoctor(int? id) {
    if (id == null) return null;
    for (final doctor in _allDoctors) {
      if (doctor is Map && int.tryParse(doctor['id'].toString()) == id) {
        return Map<String, dynamic>.from(doctor);
      }
    }
    return null;
  }

  Future<void> _loadDoctorAvailability(Map<String, dynamic> doctor) async {
    final id = doctor['id'];
    if (id == null) return;
    try {
      final response = await ApiClient.get('/doctors/$id/availability');
      if (response.statusCode != 200 || !mounted) return;
      final availabilities = List<dynamic>.from(jsonDecode(response.body));
      final today = _dateKey(caracasNow());
      final availableDays = availabilities
          .where((day) =>
              day['is_full'] != true &&
              day['date'].toString().compareTo(today) >= 0)
          .toList()
        ..sort((a, b) => a['date'].compareTo(b['date']));
      setState(() {
        _doctorAvailabilityInfo = availabilities;
        if (availableDays.isNotEmpty) {
          _selectedDate = DateTime.parse(availableDays.first['date']);
          final slots = availableDays.first['slots'] as List<dynamic>? ?? [];
          final firstSlot = slots.cast<Map>().firstWhere(
                (slot) => slot['available'] == true,
                orElse: () => <String, dynamic>{},
              );
          _selectedTurnNumber =
              firstSlot.isEmpty ? null : firstSlot['turn_number'] as int?;
        }
      });
    } catch (error) {
      debugPrint('Error fetching doctor availability: $error');
    }
  }

  Future<void> _selectSpecialty() async {
    final queryController = TextEditingController();
    final selected = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refreshDialog) {
          final query = queryController.text.trim().toLowerCase();
          final results = _availableSpecialties
              .where((item) => item.toLowerCase().contains(query))
              .toList();
          return AlertDialog(
            title: const Text('Buscar especialidad'),
            content: SizedBox(
              width: 420,
              height: 420,
              child: Column(
                children: [
                  TextField(
                    controller: queryController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Escribe una especialidad',
                    ),
                    onChanged: (_) => refreshDialog(() {}),
                  ),
                  ListTile(
                    title: const Text('Todas las especialidades'),
                    selected: _allSpecialtiesSelected,
                    trailing: _allSpecialtiesSelected
                        ? const Icon(Icons.check, color: Color(0xFF0056B3))
                        : null,
                    onTap: () => Navigator.pop(dialogContext, ''),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, index) => ListTile(
                        title: Text(results[index]),
                        selected: results[index] == _selectedEspecialidad,
                        onTap: () =>
                            Navigator.pop(dialogContext, results[index]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    queryController.dispose();
    if (!mounted || selected == null) return;
    setState(() {
      _selectedEspecialidad = selected.isEmpty ? null : selected;
      _allSpecialtiesSelected = selected.isEmpty;
      _selectedDoctorId = null;
      _selectedTurnNumber = null;
    });
  }

  @override
  void dispose() {
    _customMotivoController.dispose();
    _dependentNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agendar Cita',
            style: TextStyle(
                color: Color(0xFF0056B3), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      backgroundColor:
          const Color(0xFFE2F1F8), // Match the light blue background
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Agende su cita con su médico (por orden de llegada).',
              style: TextStyle(color: Color(0xFF475569), fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _buildDropdown(
              hint: 'Estado',
              value: _selectedEstado,
              items: _availableStates,
              onChanged: (val) {
                setState(() {
                  _selectedEstado = val;
                  _selectedEspecialidad = null;
                  _allSpecialtiesSelected = false;
                  _selectedDoctorId = null;
                  _selectedTurnNumber = null;
                });
              },
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _selectSpecialty,
              icon: const Icon(Icons.search),
              label: Align(
                alignment: Alignment.centerLeft,
                child: Text(_selectedEspecialidad ??
                    (_allSpecialtiesSelected
                        ? 'Todas las especialidades'
                        : 'Buscar especialidad')),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                alignment: Alignment.centerLeft,
                backgroundColor: Colors.white.withValues(alpha: 0.5),
                foregroundColor: const Color(0xFF0B2545),
                side: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              isExpanded: true,
              initialValue: _availableDoctors.any((doctor) =>
                      int.tryParse(doctor['id'].toString()) ==
                      _selectedDoctorId)
                  ? _selectedDoctorId
                  : null,
              decoration: InputDecoration(
                labelText: 'Selecciona Médico',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.5),
              ),
              items: _availableDoctors
                  .map((doctor) {
                    final id = int.tryParse(doctor['id'].toString());
                    return DropdownMenuItem<int>(
                      value: id,
                      child: Text(_doctorDisplayName(doctor),
                          overflow: TextOverflow.ellipsis),
                    );
                  })
                  .where((item) => item.value != null)
                  .toList(),
              onChanged: (val) async {
                setState(() {
                  _selectedDoctorId = val;
                  _doctorAvailabilityInfo = [];
                  _selectedTurnNumber = null;
                });
                final doctor = _findDoctor(val);
                if (doctor != null) await _loadDoctorAvailability(doctor);
              },
            ),
            const SizedBox(height: 16),
            _buildDropdown(
              hint: 'Motivo de Cita',
              value: _selectedMotivo,
              items: ['Consulta', 'Entrega de examenes', 'Cura', 'Otros'],
              onChanged: (val) => setState(() {
                _selectedMotivo = val;
                if (val != 'Otros') {
                  _customMotivoController.clear();
                }
              }),
            ),
            if (_selectedMotivo == 'Otros') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _customMotivoController,
                decoration: InputDecoration(
                  hintText: 'Describe el motivo de la cita...',
                  prefixIcon:
                      const Icon(Icons.edit_note, color: Color(0xFF0056B3)),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ],
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                  'La consulta es para un menor o alguien a mi cargo'),
              value: _bookingForDependent,
              onChanged: (value) => setState(() {
                _bookingForDependent = value ?? false;
                if (!_bookingForDependent) {
                  _dependentNameController.clear();
                  _dependentBirthDate = null;
                  _dependentRelationship = null;
                  _dependentGender = null;
                }
              }),
            ),
            if (_bookingForDependent) ...[
              TextField(
                controller: _dependentNameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Nombre completo del paciente',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final today = DateTime.now();
                  final selected = await showDatePicker(
                    context: context,
                    initialDate: _dependentBirthDate ??
                        DateTime(today.year - 10, today.month, today.day),
                    firstDate: DateTime(1900),
                    lastDate: today,
                    helpText: 'Nacimiento del paciente',
                  );
                  if (selected != null)
                    setState(() => _dependentBirthDate = selected);
                },
                icon: const Icon(Icons.cake_outlined),
                label: Text(_dependentBirthDate == null
                    ? 'Fecha de nacimiento del paciente'
                    : 'Nacimiento: ${_dependentBirthDate!.day.toString().padLeft(2, '0')}/${_dependentBirthDate!.month.toString().padLeft(2, '0')}/${_dependentBirthDate!.year}'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _dependentRelationship,
                decoration: const InputDecoration(
                  labelText: 'Parentesco',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
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
                    .map((item) =>
                        DropdownMenuItem(value: item, child: Text(item)))
                    .toList(),
                onChanged: (value) =>
                    setState(() => _dependentRelationship = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _dependentGender,
                decoration: const InputDecoration(
                  labelText: 'Género (opcional)',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: const [
                  'Masculino',
                  'Femenino',
                  'Otro / Prefiero no decirlo'
                ]
                    .map((item) =>
                        DropdownMenuItem(value: item, child: Text(item)))
                    .toList(),
                onChanged: (value) => setState(() => _dependentGender = value),
              ),
            ],
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Seleccione la fecha de atención',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0B2545))),
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      Icon(Icons.circle, color: Colors.red, size: 12),
                      SizedBox(width: 4),
                      Text('Día No Laborable',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFF475569))),
                      SizedBox(width: 16),
                      Icon(Icons.circle, color: Colors.yellow, size: 12),
                      SizedBox(width: 4),
                      Text('Agenda Completa',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFF475569))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Calendar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TableCalendar(
                      locale: 'es_ES',
                      availableGestures: AvailableGestures.horizontalSwipe,
                      firstDay: DateTime(caracasNow().year, caracasNow().month,
                          caracasNow().day),
                      lastDay: caracasNow().add(const Duration(days: 365)),
                      focusedDay: _selectedDate,
                      selectedDayPredicate: (day) =>
                          isSameDay(_selectedDate, day),
                      onDaySelected: (selectedDay, focusedDay) {
                        final dateString = _dateKey(selectedDay);
                        bool isAvailable = _doctorAvailabilityInfo
                            .any((info) => info['date'] == dateString);
                        bool isFull = _doctorAvailabilityInfo.any((info) =>
                            info['date'] == dateString &&
                            info['is_full'] == true);
                        final today = caracasNow();
                        final selectedDateOnly = DateTime(selectedDay.year,
                            selectedDay.month, selectedDay.day);
                        final todayOnly =
                            DateTime(today.year, today.month, today.day);
                        if (isAvailable &&
                            !isFull &&
                            _selectedDoctorId != null &&
                            !selectedDateOnly.isBefore(todayOnly)) {
                          setState(() {
                            _selectedDate = selectedDay;
                            final day = _doctorAvailabilityInfo.firstWhere(
                                (info) => info['date'] == dateString);
                            final slots = day['slots'] as List<dynamic>? ?? [];
                            final firstSlot = slots.cast<Map>().firstWhere(
                                  (slot) => slot['available'] == true,
                                  orElse: () => <String, dynamic>{},
                                );
                            _selectedTurnNumber = firstSlot.isEmpty
                                ? null
                                : firstSlot['turn_number'] as int?;
                          });
                        }
                      },
                      calendarBuilders: CalendarBuilders(
                        defaultBuilder: (context, date, events) =>
                            _buildDayCell(date, isSelected: false),
                        disabledBuilder: (context, date, events) =>
                            _buildDayCell(date,
                                isSelected: false, isDisabled: true),
                        selectedBuilder: (context, date, events) =>
                            _buildDayCell(date, isSelected: true),
                        todayBuilder: (context, date, events) => _buildDayCell(
                            date,
                            isSelected: false,
                            isToday: true),
                      ),
                      headerStyle: const HeaderStyle(
                          formatButtonVisible: false, titleCentered: true),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('Horarios disponibles',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0B2545))),
            const SizedBox(height: 10),
            if (_selectedDoctorId == null)
              const Text('Selecciona un médico para ver sus horarios.')
            else if (_availableSlots.isEmpty)
              const Text('No hay turnos disponibles para esta fecha.')
            else
              DropdownButtonFormField<int>(
                initialValue: _availableSlots.any(
                        (slot) => slot['turn_number'] == _selectedTurnNumber)
                    ? _selectedTurnNumber
                    : null,
                decoration: InputDecoration(
                  labelText: 'Selecciona hora y turno',
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.8),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                items: _availableSlots.map((slot) {
                  final turn = slot['turn_number'] as int;
                  return DropdownMenuItem<int>(
                    value: turn,
                    child: Text('${slot['time_block']} · Turno #$turn'),
                  );
                }).toList(),
                onChanged: (turn) => setState(() => _selectedTurnNumber = turn),
              ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (_selectedDoctorId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Por favor selecciona un médico.')));
                      return;
                    }
                    if (_selectedMotivo == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Por favor selecciona el motivo de la cita.')),
                      );
                      return;
                    }
                    if (_selectedTurnNumber == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Selecciona un turno disponible.')));
                      return;
                    }
                    if (_bookingForDependent &&
                        (_dependentNameController.text.trim().isEmpty ||
                            _dependentBirthDate == null ||
                            _dependentRelationship == null)) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text(
                              'Completa el nombre, nacimiento y parentesco del paciente.')));
                      return;
                    }

                    final doc = _findDoctor(_selectedDoctorId);
                    if (doc == null || doc['id'] == null) return;

                    final String motivoFinal = (_selectedMotivo == 'Otros' &&
                            _customMotivoController.text.trim().isNotEmpty)
                        ? _customMotivoController.text.trim()
                        : (_selectedMotivo ?? 'Consulta');

                    final appointmentDate = _dateKey(_selectedDate);
                    if (!await _confirmSameDayAppointment(
                        doc['id'] as int, appointmentDate)) {
                      return;
                    }

                    final reqBody = {
                      "doctor_id": doc['id'],
                      "appointment_date": appointmentDate,
                      "turn_number": _selectedTurnNumber,
                      "appointment_reason": motivoFinal,
                      "is_for_dependent": _bookingForDependent,
                      if (_bookingForDependent) ...{
                        "dependent_name": _dependentNameController.text.trim(),
                        "dependent_birth_date": _dateKey(_dependentBirthDate!),
                        "dependent_relationship": _dependentRelationship,
                        "dependent_gender": _dependentGender,
                      },
                    };

                    try {
                      final response =
                          await ApiClient.post('/appointments/', reqBody);
                      if (!context.mounted) return;
                      if (response.statusCode == 201) {
                        Map<String, dynamic>? appointmentDetails;
                        try {
                          final created =
                              jsonDecode(response.body) as Map<String, dynamic>;
                          final createdId = created['id']?.toString();
                          final listResponse =
                              await ApiClient.get('/appointments/my');
                          final decoded = jsonDecode(listResponse.body);
                          final appointments = decoded is List
                              ? decoded
                              : (decoded is Map && decoded['items'] is List
                                  ? decoded['items'] as List
                                  : <dynamic>[]);
                          for (final item in appointments) {
                            if (item is Map &&
                                item['id']?.toString() == createdId) {
                              appointmentDetails =
                                  Map<String, dynamic>.from(item);
                              break;
                            }
                          }
                        } catch (_) {}
                        final showDetails = await showDialog<bool>(
                          context: context,
                          barrierDismissible: false,
                          builder: (dialogContext) => AlertDialog(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24)),
                            backgroundColor: const Color(0xFFF4F7FC),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFFE1F3E8),
                                    border: Border.all(
                                        color: const Color(0xFF43A653),
                                        width: 2),
                                  ),
                                  child: const Icon(Icons.check_rounded,
                                      color: Color(0xFF329447), size: 44),
                                ),
                                const SizedBox(height: 18),
                                const Text('¡Su cita fue agendada con éxito!',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: Color(0xFF0B2545),
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                const Text(
                                    'La cita ya está confirmada. Puedes consultar sus detalles ahora.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: Color(0xFF52657A),
                                        fontSize: 14)),
                              ],
                            ),
                            actionsAlignment: MainAxisAlignment.center,
                            actions: [
                              TextButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, false),
                                  child: const Text('OK')),
                              FilledButton.icon(
                                  onPressed: appointmentDetails == null
                                      ? null
                                      : () =>
                                          Navigator.pop(dialogContext, true),
                                  icon: const Icon(Icons.event_note_outlined),
                                  label: const Text('Ver cita')),
                            ],
                          ),
                        );
                        if (!context.mounted) return;
                        setState(() {
                          _selectedEspecialidad = null;
                          _allSpecialtiesSelected = false;
                          _selectedDoctorId = null;
                          _selectedMotivo = null;
                          _customMotivoController.clear();
                          _dependentNameController.clear();
                          _bookingForDependent = false;
                          _dependentBirthDate = null;
                          _dependentRelationship = null;
                          _dependentGender = null;
                          _selectedTurnNumber = null;
                        });
                        if (widget.onCitaAgendada != null) {
                          widget.onCitaAgendada!();
                        }
                        if (showDetails == true && appointmentDetails != null) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            final rootContext = appNavigatorKey.currentContext;
                            if (rootContext != null && rootContext.mounted) {
                              showAppointmentDetailsDialog(
                                rootContext,
                                appointmentDetails!,
                                isDoctor: false,
                              );
                            }
                          });
                        }
                      } else {
                        var errorMessage = 'No se pudo agendar la cita.';
                        try {
                          errorMessage =
                              jsonDecode(response.body)['detail']?.toString() ??
                                  errorMessage;
                        } catch (_) {}
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(errorMessage)));
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  },
                  icon: const Icon(Icons.check_circle, color: Colors.white),
                  label: const Text('Confirmar Cita',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0056B3),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(
      {required String hint,
      required String? value,
      required List<String> items,
      required ValueChanged<String?> onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          hint: Text(hint,
              style: const TextStyle(color: Color(0xFF475569), fontSize: 16)),
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF475569)),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child:
                  Text(item, style: const TextStyle(color: Color(0xFF0B2545))),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildDayCell(DateTime date,
      {bool isSelected = false,
      bool isDisabled = false,
      bool isToday = false}) {
    if (_selectedDoctorId == null) {
      Color c = isDisabled
          ? Colors.grey
          : (isToday ? const Color(0xFF0056B3) : Colors.black);
      return Center(child: Text('${date.day}', style: TextStyle(color: c)));
    }

    final dateString = date.toIso8601String().split('T')[0];
    final info =
        _doctorAvailabilityInfo.where((i) => i['date'] == dateString).toList();
    Color? bgColor;
    Color textColor = Colors.black;

    if (isSelected) {
      bgColor = const Color(0xFF0056B3);
      textColor = Colors.white;
    } else if (info.isEmpty) {
      bgColor = Colors.red;
      textColor = Colors.white;
    } else if (info.first['is_full'] == true) {
      bgColor = Colors.yellow;
      textColor = Colors.black;
    } else if (isToday) {
      bgColor = const Color(0xFFB3C6DF);
    }

    if (bgColor != null) {
      return Container(
        margin: const EdgeInsets.all(6.0),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
        child: Text('${date.day}', style: TextStyle(color: textColor)),
      );
    }
    return Center(
        child: Text('${date.day}',
            style: TextStyle(color: isDisabled ? Colors.grey : Colors.black)));
  }
}
