import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../models/ve_catalogs.dart';
import 'dart:convert';
import 'dart:async';

class MiDisponibilidadTab extends StatefulWidget {
  const MiDisponibilidadTab({super.key});

  @override
  State<MiDisponibilidadTab> createState() => _MiDisponibilidadTabState();
}

class _MiDisponibilidadTabState extends State<MiDisponibilidadTab> {
  bool _isSuccess = false;
  String _selectedStartTime = '09:00';
  String _selectedEndTime = '18:00';
  int _slotDurationMinutes = 30;
  int _weekOffset = 0;
  Timer? _weekRefreshTimer;

  String _formatWeek(DateTime start) {
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
    final end = start.add(const Duration(days: 6));
    return '${months[start.month - 1]} ${start.day} - ${start.month == end.month ? '' : '${months[end.month - 1]} '}${end.day}';
  }

  List<Map<String, dynamic>> get _currentWeekDays {
    final today = caracasNow();
    final monday = today
        .subtract(Duration(days: today.weekday - 1))
        .add(Duration(days: _weekOffset * 7));

    final daysNames = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo'
    ];
    List<Map<String, dynamic>> res = [];
    for (int i = 0; i < 7; i++) {
      final d = monday.add(Duration(days: i));
      final dateStr =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      res.add({
        'dayName': daysNames[i],
        'date': d.day.toString(),
        'fullDate': dateStr,
        'selected': _selectedDates.contains(dateStr),
      });
    }
    return res;
  }

  Set<String> _selectedDates = {};
  bool _isLoading = true;
  int? _doctorId;

  @override
  void initState() {
    super.initState();
    _fetchAvailability();
    _weekRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted || _weekOffset != 0) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _weekRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchAvailability() async {
    try {
      final docRes = await ApiClient.get('/doctors/me');
      if (docRes.statusCode == 200) {
        final doc = jsonDecode(docRes.body);
        _doctorId = doc['id'];
        final availRes =
            await ApiClient.get('/doctors/$_doctorId/availability');
        if (availRes.statusCode == 200) {
          final List<dynamic> avails = jsonDecode(availRes.body);
          setState(() {
            _selectedDates = avails.map((a) => a['date'].toString()).toSet();
            if (avails.isNotEmpty) {
              _selectedStartTime =
                  avails.first['start_time'].toString().substring(0, 5);
              _selectedEndTime =
                  avails.first['end_time'].toString().substring(0, 5);
              _slotDurationMinutes =
                  (avails.first['slot_duration_minutes'] as num?)?.toInt() ??
                      30;
            }
          });
        }
      }
    } catch (e) {
      print(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAvailability() async {
    final start = _timeToMinutes(_selectedStartTime);
    final end = _timeToMinutes(_selectedEndTime);
    if (end <= start) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('La hora de fin debe ser posterior a la hora de inicio.')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final avails = _selectedDates
          .map((date) => {
                'date': date,
                'start_time': _selectedStartTime,
                'end_time': _selectedEndTime,
                'slot_duration_minutes': _slotDurationMinutes,
              })
          .toList();

      final res = await ApiClient.post(
          '/doctors/me/availability', {'availabilities': avails});

      if (res.statusCode == 200 || res.statusCode == 201) {
        if (mounted) {
          setState(() => _isSuccess = true);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Disponibilidad Guardada exitosamente.'),
              backgroundColor: Colors.green));
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) setState(() => _isSuccess = false);
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Error al guardar: ${res.statusCode}'),
              backgroundColor: Colors.red));
        }
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

  int _timeToMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  Future<void> _selectTime({required bool isStart}) async {
    final value = isStart ? _selectedStartTime : _selectedEndTime;
    final parts = value.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime:
          TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
    );
    if (picked == null || !mounted) return;
    final formatted =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    setState(() {
      if (isStart) {
        _selectedStartTime = formatted;
      } else {
        _selectedEndTime = formatted;
      }
    });
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
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('Mi Disponibilidad',
                style: TextStyle(
                    color: Color(0xFF0B2545), fontWeight: FontWeight.bold)),
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            automaticallyImplyLeading:
                false, // It's a tab, no back button usually
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSectionTitle('Hora de Inicio Laboral'),
                      const SizedBox(height: 8),
                      const Text(
                        'Selecciona la hora en la que inician tus consultas.',
                        style:
                            TextStyle(color: Color(0xFF475569), fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      _timePickerTile('Hora de inicio', _selectedStartTime,
                          () => _selectTime(isStart: true)),
                      const SizedBox(height: 32),
                      _buildSectionTitle('Hora de Fin Laboral'),
                      const SizedBox(height: 8),
                      const Text(
                          'Selecciona la hora en la que finalizan tus consultas.',
                          style: TextStyle(
                              color: Color(0xFF475569), fontSize: 14)),
                      const SizedBox(height: 16),
                      _timePickerTile('Hora de fin', _selectedEndTime,
                          () => _selectTime(isStart: false)),
                      const SizedBox(height: 32),
                      _buildSectionTitle('Duración de cada cita'),
                      const SizedBox(height: 8),
                      const Text(
                        'Este bloque se aplicará a los turnos de los días seleccionados.',
                        style:
                            TextStyle(color: Color(0xFF475569), fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        value: _slotDurationMinutes,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.timelapse,
                              color: Color(0xFF0056B3)),
                        ),
                        items: const [30, 60, 120]
                            .map((minutes) => DropdownMenuItem<int>(
                                  value: minutes,
                                  child: Text(minutes == 30
                                      ? '30 minutos'
                                      : minutes == 60
                                          ? '1 hora'
                                          : '2 horas'),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _slotDurationMinutes = value);
                          }
                        },
                      ),
                      const SizedBox(height: 32),
                      _buildSectionTitle('Días Laborables'),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            const Text('TOQUE PARA SELECCIONAR DÍAS LABORABLES',
                                style: TextStyle(
                                    color: Color(0xFF475569),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('SEMANA ACTUAL',
                                      style: TextStyle(
                                          color: Color(0xFF38B6FF),
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 8),
                                  Row(
                                    children: [
                                      IconButton(
                                          icon: const Icon(Icons.chevron_left,
                                              color: Color(0xFF0056B3)),
                                          onPressed: () {
                                            setState(() => _weekOffset--);
                                          }),
                                      Text(
                                          _formatWeek(caracasNow()
                                              .subtract(Duration(
                                                  days:
                                                      caracasNow().weekday - 1))
                                              .add(Duration(
                                                  days: _weekOffset * 7))),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF0B2545))),
                                      IconButton(
                                          icon: const Icon(Icons.chevron_right,
                                              color: Color(0xFF0056B3)),
                                          onPressed: () {
                                            setState(() => _weekOffset++);
                                          }),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              alignment: WrapAlignment.center,
                              children: _currentWeekDays
                                  .map((day) => _buildDayCard(day))
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _saveAvailability,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : Icon(_isSuccess ? Icons.check : Icons.save,
                                  color: Colors.white),
                          label: Text(
                              _isSuccess
                                  ? '¡Guardado!'
                                  : 'Guardar Disponibilidad',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isSuccess
                                ? Colors.green
                                : const Color(0xFF0056B3),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
          fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0B2545)),
    );
  }

  Widget _timePickerTile(String label, String value, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: const Color(0xFF0056B3).withOpacity(0.35)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label,
                    style: const TextStyle(
                        color: Color(0xFF475569), fontSize: 12)),
                const SizedBox(height: 4),
                Text(value,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Color(0xFF0B2545))),
              ]),
              const Icon(Icons.access_time, color: Color(0xFF0056B3)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDayCard(Map<String, dynamic> day) {
    bool isSelected = day['selected'];
    final dateStr = day['fullDate'];
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedDates.remove(dateStr);
          } else {
            _selectedDates.add(dateStr);
          }
        });
      },
      child: Container(
        width: 90,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF38B6FF) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border:
              isSelected ? null : Border.all(color: const Color(0xFF38B6FF)),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                  color: const Color(0xFF38B6FF).withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          children: [
            Text(day['dayName'],
                style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF475569),
                    fontSize: 12)),
            const SizedBox(height: 4),
            Text(day['date'],
                style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF0B2545),
                    fontSize: 24,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Icon(isSelected ? Icons.check_circle : Icons.crop_square,
                color: isSelected ? Colors.white : const Color(0xFF475569),
                size: 20),
            const SizedBox(height: 4),
            Text(isSelected ? 'SELECCIONADO' : 'NO LABORAL',
                style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF475569),
                    fontSize: 9,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
