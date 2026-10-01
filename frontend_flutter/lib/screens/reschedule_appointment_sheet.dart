import 'dart:convert';
import 'package:flutter/material.dart';
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
  DateTime? _date;
  List<Map<String, dynamic>> _slots = [];
  int? _turn;
  bool _loadingSlots = false;
  bool _saving = false;

  Future<void> _fetchSlots() async {
    if (_date == null) return;
    setState(() {
      _loadingSlots = true;
      _slots.clear();
      _turn = null;
    });

    try {
      final dateStr = _date!.toIso8601String().split('T')[0];
      final resp = await ApiClient.get(
          '/appointments/available-slots?doctor_id=${widget.doctorId}&date=$dateStr');
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as List;
        setState(() {
          _slots = data.map((e) => e as Map<String, dynamic>).toList();
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingSlots = false);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _date == null || _turn == null) return;
    setState(() => _saving = true);
    
    try {
      final dateStr = _date!.toIso8601String().split('T')[0];
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

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
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
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_month, color: Colors.blue),
              title: Text(_date == null
                  ? 'Seleccionar fecha'
                  : '${_date!.day}/${_date!.month}/${_date!.year}'),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: caracasNow(),
                  firstDate: caracasNow(),
                  lastDate: caracasNow().add(const Duration(days: 60)),
                );
                if (d != null) {
                  setState(() => _date = d);
                  _fetchSlots();
                }
              },
            ),
            if (_loadingSlots)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_date != null) ...[
              if (_slots.isEmpty)
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
                  decoration: const InputDecoration(labelText: 'Turno'),
                  value: _turn,
                  items: _slots.map((s) {
                    final t = s['turn_number'];
                    final time = s['start_time'];
                    return DropdownMenuItem<int>(
                      value: t,
                      child: Text('Turno #$t - $time'),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _turn = v),
                  validator: (v) => v == null ? 'Seleccione turno' : null,
                ),
            ],
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
