import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/appointment_pricing.dart';
import '../models/ve_catalogs.dart';

class DoctorPricingScreen extends StatefulWidget {
  const DoctorPricingScreen({super.key});

  @override
  State<DoctorPricingScreen> createState() => _DoctorPricingScreenState();
}

class _DoctorPricingScreenState extends State<DoctorPricingScreen> {
  final _form = GlobalKey<FormState>();
  final _consultation = TextEditingController();
  final _examDelivery = TextEditingController();
  final _woundCare = TextEditingController();
  final _percent = TextEditingController();
  bool _loading = true;
  bool _loadFailed = false;
  bool _saving = false;
  bool _showInVes = false;
  bool _offerEnabled = false;
  String _offerCategory = 'all';
  DateTimeRange? _offerDates;

  static final _feePattern = RegExp(r'^\d{1,10}([.,]\d{1,2})?$');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _consultation.dispose();
    _examDelivery.dispose();
    _woundCare.dispose();
    _percent.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final response = await ApiClient.get('/doctors/me').timeout(
        const Duration(seconds: 12),
      );
      if (response.statusCode != 200) throw StateError('Perfil no disponible');
      final doctor = jsonDecode(response.body) as Map<String, dynamic>;
      if (!mounted) return;
      _consultation.text =
          (doctor['consultation_fee'] as num? ?? 50).toStringAsFixed(2);
      _examDelivery.text = doctor['exam_delivery_fee']?.toString() ?? '';
      _woundCare.text = doctor['wound_care_fee']?.toString() ?? '';
      _showInVes = doctor['show_fee_in_ves'] == true;
      final offer = doctor['appointment_offer'];
      if (offer is Map) {
        _offerEnabled = true;
        _percent.text = offer['percent'].toString();
        _offerCategory = offer['category'] as String;
        _offerDates = DateTimeRange(
          start: DateTime.parse(offer['starts_on'] as String),
          end: DateTime.parse(offer['ends_on'] as String),
        );
      }
    } catch (_) {
      _loadFailed = true;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _isoDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<void> _selectDates() async {
    final today = DateUtils.dateOnly(caracasNow());
    final previous = _offerDates;
    final last = DateTime(today.year + 5, today.month, today.day);
    final dates = await showDateRangePicker(
      context: context,
      firstDate: today,
      lastDate: last,
      currentDate: today,
      initialDateRange: previous != null &&
              !previous.start.isBefore(today) &&
              !previous.end.isAfter(last)
          ? previous
          : null,
      helpText: 'Vigencia de la oferta',
    );
    if (dates != null && mounted) setState(() => _offerDates = dates);
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final dates = _offerDates;
    if (_offerEnabled && dates == null) {
      _message('Selecciona las fechas de la oferta.');
      return;
    }
    setState(() => _saving = true);
    try {
      String? fee(TextEditingController controller) {
        final text = controller.text.trim().replaceAll(',', '.');
        return text.isEmpty ? null : text;
      }

      final response = await ApiClient.put('/doctors/me', {
        'consultation_fee': fee(_consultation),
        'exam_delivery_fee': fee(_examDelivery),
        'wound_care_fee': fee(_woundCare),
        'show_fee_in_ves': _showInVes,
        'appointment_offer': _offerEnabled && dates != null
            ? {
                'starts_on': _isoDate(dates.start),
                'ends_on': _isoDate(dates.end),
                'percent': int.parse(_percent.text.trim()),
                'category': _offerCategory,
              }
            : null,
      }).timeout(const Duration(seconds: 12));
      if (!mounted) return;
      if (response.statusCode != 200) {
        _message('No se pudieron guardar las tarifas y la oferta.');
        return;
      }
      final saved = jsonDecode(response.body) as Map<String, dynamic>;
      if (!saved.containsKey('appointment_offer')) {
        _message('La configuración de tarifas todavía no está disponible.');
        return;
      }
      _message('Tarifas y oferta guardadas.');
      Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        _message('No se pudo confirmar que los cambios se guardaron.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _fee(String title, TextEditingController controller,
      {bool optional = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        enabled: !_saving,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: title,
          suffixText: 'USD',
          helperText: optional
              ? 'Vacío: precio de consulta. Escribe 0 si es gratis.'
              : null,
          helperMaxLines: 2,
          border: const OutlineInputBorder(),
        ),
        validator: (value) {
          final text = value?.trim() ?? '';
          if (optional && text.isEmpty) return null;
          return _feePattern.hasMatch(text)
              ? null
              : 'Ingresa un importe válido.';
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dates = _offerDates;
    final format = MaterialLocalizations.of(context).formatCompactDate;
    return Scaffold(
      appBar: AppBar(title: const Text('Tarifas y ofertas')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadFailed
              ? Center(
                  child: TextButton(
                      onPressed: _load, child: const Text('Reintentar')))
              : Form(
                  key: _form,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _fee('Consulta', _consultation),
                      _fee('Entrega de exámenes', _examDelivery,
                          optional: true),
                      _fee('Cura', _woundCare, optional: true),
                      const ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Otros motivos'),
                        subtitle: Text('Usan el precio de la consulta.'),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Mostrar conversión a bolívares'),
                        value: _showInVes,
                        onChanged: _saving
                            ? null
                            : (value) => setState(() => _showInVes = value),
                      ),
                      const Divider(height: 32),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Ofrecer un descuento'),
                        subtitle: const Text(
                            'Aplica a citas dentro de las fechas elegidas.'),
                        value: _offerEnabled,
                        onChanged: _saving
                            ? null
                            : (value) => setState(() => _offerEnabled = value),
                      ),
                      if (_offerEnabled) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _offerCategory,
                          decoration: const InputDecoration(
                            labelText: 'Motivo con descuento',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem(
                                value: 'all', child: Text('Todos los motivos')),
                            for (final reason in appointmentCategories.entries)
                              DropdownMenuItem(
                                  value: reason.value,
                                  child: Text(appointmentReasons[reason.key]!)),
                          ],
                          onChanged: _saving
                              ? null
                              : (value) =>
                                  setState(() => _offerCategory = value!),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _percent,
                          enabled: !_saving,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Descuento',
                            suffixText: '%',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final percent = int.tryParse(value?.trim() ?? '');
                            return percent != null &&
                                    percent >= 1 &&
                                    percent <= 100
                                ? null
                                : 'Ingresa un porcentaje entre 1 y 100.';
                          },
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: _saving ? null : _selectDates,
                          icon: const Icon(Icons.date_range_outlined),
                          label: Text(dates == null
                              ? 'Seleccionar fechas de la oferta'
                              : '${format(dates.start)} – ${format(dates.end)}'),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        child: Text(_saving ? 'Guardando…' : 'Guardar cambios'),
                      ),
                    ],
                  ),
                ),
    );
  }
}
