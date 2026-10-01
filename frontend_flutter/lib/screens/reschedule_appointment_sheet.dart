import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../core/api_client.dart';
import '../models/ve_catalogs.dart';

class RescheduleAppointmentSheet extends StatefulWidget {
  final int appointmentId;
  final int doctorId;

  const RescheduleAppointmentSheet({
    super.key,
    required this.appointmentId,
    required this.doctorId,
  });

  @override
  State<RescheduleAppointmentSheet> createState() => _RescheduleAppointmentSheetState();
}

class _RescheduleAppointmentSheetState extends State<RescheduleAppointmentSheet> {
  final _formKey = GlobalKey<FormState>();
  DateTime _selectedDate = caracasNow();
  int? _turn;
  bool _loading = true;
  bool _saving = false;
  List<dynamic> _doctorAvailabilityInfo = [];

  @override
  void initState() {
    super.initState();
    _fetchAvailability();
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<void> _fetchAvailability() async {
    try {
      final response = await ApiClient.get('/doctors/${widget.doctorId}/availability');
      if (response.statusCode == 200) {
        final availabilities = List<dynamic>.from(jsonDecode(response.body));
        final today = _dateKey(caracasNow());
        final availableDays = availabilities
            .where((day) =>
                day['is_full'] != true &&
                day['date'].toString().compareTo(today) >= 0)
            .toList()
          ..sort((a, b) => a['date'].compareTo(b['date']));
          
        if (mounted) {
          setState(() {
            _doctorAvailabilityInfo = availabilities;
            if (availableDays.isNotEmpty) {
              _selectedDate = DateTime.parse(availableDays.first['date']);
              final slots = availableDays.first['slots'] as List<dynamic>? ?? [];
              final firstSlot = slots.cast<Map>().firstWhere(
                    (slot) => slot['available'] == true,
                    orElse: () => <String, dynamic>{},
                  );
              _turn = firstSlot.isEmpty ? null : firstSlot['turn_number'] as int?;
            }
            _loading = false;
          });
        }
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _turn == null) return;
    setState(() => _saving = true);
    
    try {
      final dateStr = _dateKey(_selectedDate);
      final resp = await ApiClient.patch(
        '/appointments/${widget.appointmentId}/reschedule',
        {
          "appointment_date": dateStr,
          "turn_number": _turn,
        },
      );
      if (mounted) {
        if (resp.statusCode == 200) {
          Navigator.of(context).pop(true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${resp.body}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error de conexión: $e')),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  Widget _buildDayCell(DateTime date,
      {bool isSelected = false,
      bool isDisabled = false,
      bool isToday = false}) {
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
            style: TextStyle(
                color: isDisabled
                    ? Colors.grey
                    : (isToday ? const Color(0xFF0056B3) : Colors.black))));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(48.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: bottomInset > 0 ? bottomInset + 24 : 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Reprogramar Cita',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.circle, color: Colors.red, size: 12),
                SizedBox(width: 4),
                Text('Día No Laborable',
                    style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
                SizedBox(width: 16),
                Icon(Icons.circle, color: Colors.yellow, size: 12),
                SizedBox(width: 4),
                Text('Agenda Completa',
                    style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
              ],
            ),
            const SizedBox(height: 16),
            TableCalendar(
              locale: 'es_ES',
              firstDay: DateTime(caracasNow().year, caracasNow().month, caracasNow().day),
              lastDay: caracasNow().add(const Duration(days: 365)),
              focusedDay: _selectedDate,
              selectedDayPredicate: (day) => isSameDay(_selectedDate, day),
              onDaySelected: (selectedDay, focusedDay) {
                final dateString = _dateKey(selectedDay);
                bool isAvailable = _doctorAvailabilityInfo
                    .any((info) => info['date'] == dateString);
                bool isFull = _doctorAvailabilityInfo.any((info) =>
                    info['date'] == dateString && info['is_full'] == true);
                final today = caracasNow();
                final selectedDateOnly = DateTime(selectedDay.year,
                    selectedDay.month, selectedDay.day);
                final todayOnly = DateTime(today.year, today.month, today.day);
                if (isAvailable && !isFull && !selectedDateOnly.isBefore(todayOnly)) {
                  setState(() {
                    _selectedDate = selectedDay;
                    final day = _doctorAvailabilityInfo.firstWhere(
                        (info) => info['date'] == dateString);
                    final slots = day['slots'] as List<dynamic>? ?? [];
                    final firstSlot = slots.cast<Map>().firstWhere(
                          (slot) => slot['available'] == true,
                          orElse: () => <String, dynamic>{},
                        );
                    _turn = firstSlot.isEmpty ? null : firstSlot['turn_number'] as int?;
                  });
                }
              },
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, date, events) =>
                    _buildDayCell(date, isSelected: false),
                disabledBuilder: (context, date, events) =>
                    _buildDayCell(date, isSelected: false, isDisabled: true),
                selectedBuilder: (context, date, events) =>
                    _buildDayCell(date, isSelected: true),
                todayBuilder: (context, date, events) =>
                    _buildDayCell(date, isSelected: false, isToday: true),
              ),
              headerStyle: const HeaderStyle(
                  formatButtonVisible: false, titleCentered: true),
            ),
            const SizedBox(height: 16),
            if (_availableSlots.isEmpty)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  'No hay turnos disponibles para esta fecha.',
                  style: TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              )
            else
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(labelText: 'Turno disponible'),
                value: _availableSlots.any((slot) => slot['turn_number'] == _turn) ? _turn : null,
                items: _availableSlots.map((s) {
                  final t = s['turn_number'];
                  final time = s['time_block'];
                  return DropdownMenuItem<int>(
                    value: t,
                    child: Text('$time · Turno #$t'),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _turn = v),
                validator: (v) => v == null ? 'Seleccione turno' : null,
              ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Guardar Cambios'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
