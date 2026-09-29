import 'dart:convert';
import 'package:flutter/services.dart';

import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../models/ve_catalogs.dart';

class ManualAppointmentSheet extends StatefulWidget {
  const ManualAppointmentSheet({super.key});

  @override
  State<ManualAppointmentSheet> createState() => _ManualAppointmentSheetState();
}

class _ManualAppointmentSheetState extends State<ManualAppointmentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  String? _reason;
  static const _reasons = ['Consulta', 'Entrega de examenes', 'Otros'];
  DateTime? _date;
  List<Map<String, dynamic>> _slots = [];
  int? _turn;
  bool _loadingSlots = false;
  bool _saving = false;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<void> _chooseDate() async {
    final today = caracasNow();
    final date = await showDatePicker(
      context: context,
      initialDate: _date ?? today,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: today.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    setState(() {
      _date = date;
      _slots = [];
      _turn = null;
      _loadingSlots = true;
    });
    try {
      final response = await ApiClient.get(
          '/appointments/manual/slots?appointment_date=${_formatDate(date)}');
      if (response.statusCode != 200) {
        throw Exception(_detail(response.body));
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _slots = List<Map<String, dynamic>>.from(data['slots'] as List);
        _loadingSlots = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingSlots = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron consultar los turnos: $error')),
      );
    }
  }

  String _detail(String body) {
    try {
      final value = jsonDecode(body);
      if (value is Map && value['detail'] != null) {
        return value['detail'].toString();
      }
    } catch (_) {}
    return body;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_date == null || _turn == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Selecciona la fecha y un turno disponible.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final response = await ApiClient.post('/appointments/manual', {
        'appointment_date': _formatDate(_date!),
        'turn_number': _turn,
        'patient_first_name': _firstName.text.trim(),
        'patient_last_name': _lastName.text.trim(),
        'patient_phone': _phone.text.trim(),
        'appointment_reason': _reason!,
      });
      if (response.statusCode == 201) {
        if (mounted) Navigator.of(context).pop(true);
      } else {
        throw Exception(_detail(response.body));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo agendar: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(5)),
                  ),
                ),
                const SizedBox(height: 18),
                const Text('Nueva cita manual',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextFormField(
                    controller: _firstName,
                    textCapitalization: TextCapitalization.words,
                    decoration: _decoration('Nombre'),
                    validator: _required),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _lastName,
                    textCapitalization: TextCapitalization.words,
                    decoration: _decoration('Apellido'),
                    validator: _required),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(11)
                    ],
                    maxLength: 11,
                    decoration: _decoration('Teléfono de contacto'),
                    validator: (value) => (value?.trim().length ?? 0) < 5 ||
                            (value?.trim().length ?? 0) > 11
                        ? 'Ingresa un teléfono válido'
                        : null),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _reason,
                  decoration: _decoration('Motivo de la cita'),
                  items: _reasons
                      .map((reason) =>
                          DropdownMenuItem(value: reason, child: Text(reason)))
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _reason = value),
                  validator: (value) =>
                      value == null ? 'Selecciona el motivo de la cita' : null,
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _chooseDate,
                  icon: const Icon(Icons.calendar_month),
                  label: Text(_date == null
                      ? 'Seleccionar fecha'
                      : 'Fecha: ${_date!.day.toString().padLeft(2, '0')}/${_date!.month.toString().padLeft(2, '0')}/${_date!.year}'),
                ),
                if (_loadingSlots)
                  const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(child: CircularProgressIndicator()))
                else if (_date != null && _slots.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text('No hay turnos disponibles para esta fecha.',
                        textAlign: TextAlign.center),
                  )
                else if (_slots.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('Turnos disponibles',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _slots.map((slot) {
                      final turn = slot['turn_number'] as int;
                      return ChoiceChip(
                        label: Text(slot['time_block'].toString()),
                        selected: _turn == turn,
                        onSelected: _saving
                            ? null
                            : (_) => setState(() => _turn = turn),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.event_available),
                  label: const Text('Agendar cita'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Campo requerido' : null;
}
