import 'package:flutter/material.dart';
import '../core/api_client.dart';
import 'dart:convert';

class MiDisponibilidadTab extends StatefulWidget {
  const MiDisponibilidadTab({super.key});

  @override
  State<MiDisponibilidadTab> createState() => _MiDisponibilidadTabState();
}

class _MiDisponibilidadTabState extends State<MiDisponibilidadTab> {
  final TextEditingController _maxPatientsController = TextEditingController(text: '999');
  bool _sinLimites = true;
  String _selectedStartTime = '09:00';
  int _weekOffset = 0;
  
  List<Map<String, dynamic>> get _currentWeekDays {
    final today = DateTime.now();
    final monday = today.subtract(Duration(days: today.weekday - 1)).add(Duration(days: _weekOffset * 7));
    
    final daysNames = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    List<Map<String, dynamic>> res = [];
    for (int i = 0; i < 7; i++) {
      final d = monday.add(Duration(days: i));
      final dateStr = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
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
  }

  Future<void> _fetchAvailability() async {
    try {
      final docRes = await ApiClient.get('/doctors/me');
      if (docRes.statusCode == 200) {
        final doc = jsonDecode(docRes.body);
        _doctorId = doc['id'];
        if (doc['max_patients_per_day'] != null && doc['max_patients_per_day'] < 999) {
          _maxPatientsController.text = doc['max_patients_per_day'].toString();
          _sinLimites = false;
        } else {
          _maxPatientsController.text = '999';
          _sinLimites = true;
        }
        
        final availRes = await ApiClient.get('/doctors/$_doctorId/availability');
        if (availRes.statusCode == 200) {
          final List<dynamic> avails = jsonDecode(availRes.body);
          setState(() {
            _selectedDates = avails.map((a) => a['date'].toString()).toSet();
            if (avails.isNotEmpty) {
              _selectedStartTime = avails.first['start_time'].toString().substring(0, 5);
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
    setState(() => _isLoading = true);
    try {
      int maxP = _sinLimites ? 999 : int.tryParse(_maxPatientsController.text) ?? 999;
      await ApiClient.put('/doctors/me', {
        'max_patients_per_day': maxP
      });
      
      List<Map<String, String>> avails = _selectedDates.map((date) => {
        'date': date,
        'start_time': _selectedStartTime,
        'end_time': '18:00' // Hardcoded default end time for now
      }).toList();
      
      final res = await ApiClient.post('/doctors/me/availability', {
        'availabilities': avails
      });
      
      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Disponibilidad Guardada')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
            title: const Text('Mi Disponibilidad', style: TextStyle(color: Color(0xFF0B2545), fontWeight: FontWeight.bold)),
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            automaticallyImplyLeading: false, // It's a tab, no back button usually
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSectionTitle('Configuración de Pacientes'),
                const SizedBox(height: 8),
                const Text(
                  'Establece cuántos pacientes deseas atender como máximo por día.',
                  style: TextStyle(color: Color(0xFF475569), fontSize: 14),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _maxPatientsController,
                        enabled: !_sinLimites,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Máximo',
                          filled: true,
                          fillColor: _sinLimites ? Colors.grey.withOpacity(0.2) : Colors.white.withOpacity(0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Row(
                      children: [
                        Checkbox(
                          value: _sinLimites,
                          onChanged: (val) {
                            setState(() {
                              _sinLimites = val ?? false;
                            });
                          },
                          activeColor: const Color(0xFF0056B3),
                        ),
                        const Text('Sin Limites', style: TextStyle(fontSize: 16, color: Color(0xFF0B2545))),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                
                _buildSectionTitle('Hora de Inicio Laboral'),
                const SizedBox(height: 8),
                const Text(
                  'Selecciona la hora en la que inician tus consultas.',
                  style: TextStyle(color: Color(0xFF475569), fontSize: 14),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey),
                  ),
                  child: InkWell(
                    onTap: () async {
                      final parts = _selectedStartTime.split(':');
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
                        builder: (context, child) {
                          return MediaQuery(
                            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
                            child: child!,
                          );
                        },
                      );
                      if (time != null) {
                        setState(() {
                          _selectedStartTime = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                        });
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_selectedStartTime, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const Icon(Icons.access_time, color: Color(0xFF0056B3)),
                        ],
                      ),
                    ),
                  ),
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
                      const Text('TOQUE PARA SELECCIONAR DÍAS LABORABLES', style: TextStyle(color: Color(0xFF475569), fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('SEMANA ACTUAL', style: TextStyle(color: Color(0xFF38B6FF), fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.chevron_left, color: Color(0xFF0056B3)), 
                                  onPressed: () { setState(() => _weekOffset--); }
                                ),
                                Text('Sep ${21 + (_weekOffset * 7)} - ${27 + (_weekOffset * 7)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0B2545))),
                                IconButton(
                                  icon: const Icon(Icons.chevron_right, color: Color(0xFF0056B3)), 
                                  onPressed: () { setState(() => _weekOffset++); }
                                ),
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
                        children: _currentWeekDays.map((day) => _buildDayCard(day)).toList(),
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
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save, color: Colors.white),
                    label: const Text('Guardar Disponibilidad', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0056B3),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0B2545)),
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
          border: isSelected ? null : Border.all(color: const Color(0xFF38B6FF)),
          boxShadow: [
            if (isSelected) BoxShadow(color: const Color(0xFF38B6FF).withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          children: [
            Text(day['dayName'], style: TextStyle(color: isSelected ? Colors.white : const Color(0xFF475569), fontSize: 12)),
            const SizedBox(height: 4),
            Text(day['date'], style: TextStyle(color: isSelected ? Colors.white : const Color(0xFF0B2545), fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Icon(isSelected ? Icons.check_circle : Icons.crop_square, color: isSelected ? Colors.white : const Color(0xFF475569), size: 20),
            const SizedBox(height: 4),
            Text(isSelected ? 'SELECCIONADO' : 'NO LABORAL', style: TextStyle(color: isSelected ? Colors.white : const Color(0xFF475569), fontSize: 9, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
