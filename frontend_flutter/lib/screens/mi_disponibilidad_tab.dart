import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../models/ve_catalogs.dart';
import '../core/auth_helper.dart';
import '../widgets/settings_ui.dart';
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
  bool _isAssistant = false;
  List<Map<String, dynamic>> _assistantAvailability = [];

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
      _isAssistant = await AuthHelper.getRole() == 'assistant';
      if (_isAssistant) {
        final userRes = await ApiClient.get('/users/me');
        if (userRes.statusCode == 200) {
          final user = jsonDecode(userRes.body) as Map<String, dynamic>;
          final linkedDoctorId = user['linked_doctor_id'];
          if (linkedDoctorId != null) {
            final availabilityRes =
                await ApiClient.get('/doctors/$linkedDoctorId/availability');
            if (availabilityRes.statusCode == 200) {
              final List<dynamic> avails = jsonDecode(availabilityRes.body);
              if (!mounted) return;
              setState(() {
                _selectedDates =
                    avails.map((a) => a['date'].toString()).toSet();
                if (avails.isNotEmpty) {
                  _selectedStartTime =
                      avails.first['start_time'].toString().substring(0, 5);
                  _selectedEndTime =
                      avails.first['end_time'].toString().substring(0, 5);
                  _slotDurationMinutes =
                      (avails.first['slot_duration_minutes'] as num?)
                              ?.toInt() ??
                          30;
                }
              });
            }
          }
        }
      } else {
        final docRes = await ApiClient.get('/doctors/me');
        if (docRes.statusCode == 200) {
          final doc = jsonDecode(docRes.body);
          _doctorId = doc['id'];
          final availRes =
              await ApiClient.get('/doctors/$_doctorId/availability');
          if (availRes.statusCode == 200) {
            final List<dynamic> avails = jsonDecode(availRes.body);
            if (!mounted) return;
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
      }
    } catch (e) {
      debugPrint('$e');
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
      initialEntryMode: TimePickerEntryMode.input,
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
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text(
          'Mi Disponibilidad',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0056B3),
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0056B3)),
            )
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SettingsBanner(
                        icon: Icons.calendar_month_rounded,
                        title: 'Configura tu horario de atención',
                        subtitle:
                            'Define tu jornada laboral, la duración de cada consulta y tus días disponibles.',
                      ),
                      const SizedBox(height: 16),

                      // Tarjeta 1: Horario laboral (Inicio y Fin)
                      SettingsCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SettingsSectionHeader(
                              icon: Icons.schedule_rounded,
                              iconColor: Color(0xFF0056B3),
                              iconBg: Color(0xFFE0EAFC),
                              title: 'Horario laboral',
                              subtitle:
                                  'Selecciona la hora en la que inician y finalizan tus consultas.',
                            ),
                            const SizedBox(height: 18),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final wide = constraints.maxWidth >= 420;
                                final startTile = _timePickerTile(
                                  'Hora de inicio',
                                  _selectedStartTime,
                                  Icons.wb_sunny_outlined,
                                  () => _selectTime(isStart: true),
                                );
                                final endTile = _timePickerTile(
                                  'Hora de fin',
                                  _selectedEndTime,
                                  Icons.nights_stay_outlined,
                                  () => _selectTime(isStart: false),
                                );
                                if (wide) {
                                  return Row(
                                    children: [
                                      Expanded(child: startTile),
                                      const SizedBox(width: 12),
                                      Expanded(child: endTile),
                                    ],
                                  );
                                }
                                return Column(
                                  children: [
                                    startTile,
                                    const SizedBox(height: 12),
                                    endTile,
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Tarjeta 2: Duración de cada cita
                      SettingsCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SettingsSectionHeader(
                              icon: Icons.timelapse_rounded,
                              iconColor: Color(0xFF059669),
                              iconBg: Color(0xFFD1FAE5),
                              title: 'Duración de cada cita',
                              subtitle:
                                  'Este bloque se aplicará a los turnos de los días seleccionados.',
                            ),
                            const SizedBox(height: 18),
                            DropdownButtonFormField<int>(
                              initialValue: _slotDurationMinutes,
                              decoration: settingsInputDecoration(
                                label: 'Bloque por turno',
                                icon: Icons.timer_outlined,
                              ),
                              items: const [30, 60, 90, 120]
                                  .map((minutes) => DropdownMenuItem<int>(
                                        value: minutes,
                                        child: Text(minutes == 30
                                            ? '30 minutos'
                                            : minutes == 60
                                                ? '1 hora'
                                                : minutes == 90
                                                    ? '1 hora y 30 minutos'
                                                    : '2 horas'),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _slotDurationMinutes = value);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Selección de Días Laborables (intacta tal como le gusta al usuario)
                      _buildSectionTitle('Días Laborables'),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
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
                      const SizedBox(height: 24),
                      _isSuccess
                          ? SizedBox(
                              height: 54,
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isLoading ? null : _saveAvailability,
                                icon: const Icon(Icons.check,
                                    color: Colors.white),
                                label: const Text(
                                  '¡Guardado!',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF059669),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                              ),
                            )
                          : SettingsGradientButton(
                              label: 'Guardar Disponibilidad',
                              icon: Icons.save_rounded,
                              loading: _isLoading,
                              onPressed: _isLoading ? null : _saveAvailability,
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

  Widget _timePickerTile(
      String label, String value, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F9FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFBAE6FD)),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF0056B3), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: Color(0xFF0B2545),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF0056B3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Cambiar',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
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
                  color: const Color(0xFF38B6FF).withValues(alpha: 0.4),
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
