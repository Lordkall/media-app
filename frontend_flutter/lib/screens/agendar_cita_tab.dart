import 'package:flutter/material.dart';
import '../core/api_client.dart';
import 'dart:convert';
import 'package:table_calendar/table_calendar.dart';

class AgendarCitaTab extends StatefulWidget {
  final VoidCallback? onCitaAgendada;
  const AgendarCitaTab({super.key, this.onCitaAgendada});

  @override
  State<AgendarCitaTab> createState() => _AgendarCitaTabState();
}

class _AgendarCitaTabState extends State<AgendarCitaTab> {
  String? _selectedEstado;
  String? _selectedEspecialidad;
  String? _selectedMedico;
  String? _selectedMotivo;
  
  List<dynamic> _allDoctors = [];
  bool _isLoading = true;
  List<dynamic> _doctorAvailabilityInfo = [];
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fetchDoctors();
  }

  Future<void> _fetchDoctors() async {
    try {
      final response = await ApiClient.get('/admin/doctors');
      if (response.statusCode == 200) {
        final List<dynamic> docs = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _allDoctors = docs.where((d) => d['plan'] != 'Ninguno' || d['clinic_id'] != null).toList();
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<String> get _availableStates {
    return [
      'Amazonas', 'Anzoátegui', 'Apure', 'Aragua', 'Barinas', 'Bolívar', 'Carabobo', 'Cojedes', 'Delta Amacuro', 'Distrito Capital', 'Falcón', 'Guárico', 'Lara', 'Mérida', 'Miranda', 'Monagas', 'Nueva Esparta', 'Portuguesa', 'Sucre', 'Táchira', 'Trujillo', 'La Guaira', 'Yaracuy', 'Zulia'
    ];
  }

  List<String> get _availableSpecialties {
    List<String> specs = [];
    for (var doc in _allDoctors) {
      if (_selectedEstado != null && doc['state']?.toString() != _selectedEstado) continue;
      if (doc['specialties'] != null) {
        for (var s in doc['specialties']) {
          if (!specs.contains(s.toString())) specs.add(s.toString());
        }
      }
    }
    specs.sort();
    return specs;
  }

  List<String> get _availableDoctors {
    Set<String> docs = {};
    for (var doc in _allDoctors) {
      if (_selectedEstado != null && doc['state']?.toString() != _selectedEstado) continue;
      
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
      
      final name = 'Dr. ${doc['first_name']} ${doc['last_name']}';
      docs.add(name);
    }
    List<String> sortedDocs = docs.toList()..sort();
    return sortedDocs;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agendar Cita', style: TextStyle(color: Color(0xFF0056B3), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      backgroundColor: const Color(0xFFE2F1F8), // Match the light blue background
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
                  _selectedMedico = null;
                });
              },
            ),
            const SizedBox(height: 16),
            _buildDropdown(
              hint: 'Especialidad',
              value: _selectedEspecialidad,
              items: _availableSpecialties,
              onChanged: (val) {
                setState(() {
                  _selectedEspecialidad = val;
                  _selectedMedico = null;
                });
              },
            ),
            const SizedBox(height: 16),
            _buildDropdown(
              hint: 'Selecciona Médico',
              value: _selectedMedico,
              items: _availableDoctors,
              onChanged: (val) async {
                setState(() {
                  _selectedMedico = val;
                  _doctorAvailabilityInfo = [];
                });
                if (val != null) {
                  // Find doctor ID
                  final doc = _allDoctors.firstWhere((d) => 'Dr. ${d['first_name']} ${d['last_name']}' == val, orElse: () => null);
                  if (doc != null && doc['id'] != null) {
                    try {
                      final response = await ApiClient.get('/doctors/${doc['id']}/availability');
                      if (response.statusCode == 200) {
                        setState(() {
                          _doctorAvailabilityInfo = jsonDecode(response.body);
                        });
                      }
                    } catch (e) {
                      print('Error fetching availability: $e');
                    }
                  }
                }
              },
            ),
            const SizedBox(height: 16),
            _buildDropdown(
              hint: 'Motivo de Cita',
              value: _selectedMotivo,
              items: ['Consulta', 'Entrega de examenes', 'Otros'],
              onChanged: (val) => setState(() => _selectedMotivo = val),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Seleccione la fecha de atención', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0B2545))),
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      Icon(Icons.circle, color: Colors.red, size: 12),
                      SizedBox(width: 4),
                      Text('Día No Laborable', style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
                      SizedBox(width: 16),
                      Icon(Icons.circle, color: Colors.yellow, size: 12),
                      SizedBox(width: 4),
                      Text('Agenda Completa', style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
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
                      firstDay: DateTime.now().subtract(const Duration(days: 30)),
                      lastDay: DateTime.now().add(const Duration(days: 365)),
                      focusedDay: _selectedDate,
                      selectedDayPredicate: (day) => isSameDay(_selectedDate, day),
                      onDaySelected: (selectedDay, focusedDay) {
                        final dateString = selectedDay.toIso8601String().split('T')[0];
                        bool isAvailable = _doctorAvailabilityInfo.any((info) => info['date'] == dateString);
                        bool isFull = _doctorAvailabilityInfo.any((info) => info['date'] == dateString && info['is_full'] == true);
                        if (isAvailable && !isFull && _selectedMedico != null) {
                          setState(() {
                            _selectedDate = selectedDay;
                          });
                        }
                      },
                      calendarBuilders: CalendarBuilders(
                        defaultBuilder: (context, date, events) => _buildDayCell(date, isSelected: false),
                        disabledBuilder: (context, date, events) => _buildDayCell(date, isSelected: false, isDisabled: true),
                        selectedBuilder: (context, date, events) => _buildDayCell(date, isSelected: true),
                        todayBuilder: (context, date, events) => _buildDayCell(date, isSelected: false, isToday: true),
                      ),
                      headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (_selectedMedico == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor selecciona un médico.')));
                      return;
                    }

                    final doc = _allDoctors.firstWhere((d) => 'Dr. ${d['first_name']} ${d['last_name']}' == _selectedMedico, orElse: () => null);
                    if (doc == null || doc['id'] == null) return;

                    final reqBody = {
                      "doctor_id": doc['id'],
                      "appointment_date": _selectedDate.toIso8601String().split('T')[0]
                    };

                    try {
                      final response = await ApiClient.post('/appointments/', reqBody);
                      if (response.statusCode == 201) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cita agendada con éxito')));
                        setState(() {
                          _selectedEstado = null;
                          _selectedEspecialidad = null;
                          _selectedMedico = null;
                          _selectedMotivo = null;
                        });
                        if (widget.onCitaAgendada != null) {
                          widget.onCitaAgendada!();
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${response.body}')));
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  },
                  icon: const Icon(Icons.check_circle, color: Colors.white),
                  label: const Text('Confirmar Cita', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0056B3),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  Widget _buildDropdown({required String hint, required String? value, required List<String> items, required ValueChanged<String?> onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          hint: Text(hint, style: const TextStyle(color: Color(0xFF475569), fontSize: 16)),
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF475569)),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item, style: const TextStyle(color: Color(0xFF0B2545))),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildDayCell(DateTime date, {bool isSelected = false, bool isDisabled = false, bool isToday = false}) {
    if (_selectedMedico == null) {
       Color c = isDisabled ? Colors.grey : (isToday ? const Color(0xFF0056B3) : Colors.black);
       return Center(child: Text('${date.day}', style: TextStyle(color: c)));
    }
    
    final dateString = date.toIso8601String().split('T')[0];
    final info = _doctorAvailabilityInfo.where((i) => i['date'] == dateString).toList();
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
    return Center(child: Text('${date.day}', style: TextStyle(color: isDisabled ? Colors.grey : Colors.black)));
  }
}
