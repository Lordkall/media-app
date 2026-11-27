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
    _consultation.addListener(_onInputChanged);
    _examDelivery.addListener(_onInputChanged);
    _woundCare.addListener(_onInputChanged);
    _percent.addListener(_onInputChanged);
    _load();
  }

  void _onInputChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _consultation.removeListener(_onInputChanged);
    _examDelivery.removeListener(_onInputChanged);
    _woundCare.removeListener(_onInputChanged);
    _percent.removeListener(_onInputChanged);
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

  int? _previewDiscountedCents(int baseCents, int discountPercent) {
    if (baseCents <= 0 || discountPercent <= 0) return null;
    return (baseCents * (100 - discountPercent) + 50) // round half up
        ~/
        100;
  }

  int? _parseCents(String raw) {
    final clean = raw.trim().replaceAll(',', '.');
    if (clean.isEmpty) return null;
    final val = double.tryParse(clean);
    if (val == null || val < 0) return null;
    return (val * 100).round();
  }

  Widget _sectionHeader({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0B2545),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _card({required Widget child, Color? borderColor}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: borderColor ?? const Color(0xFFE2E8F0),
          width: borderColor != null ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B2545).withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? suffixText,
    String? helperText,
  }) {
    return InputDecoration(
      labelText: label,
      helperText: helperText,
      helperMaxLines: 2,
      prefixIcon: Icon(icon, color: const Color(0xFF0056B3), size: 20),
      suffix: suffixText != null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFE0EAFC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                suffixText,
                style: const TextStyle(
                  color: Color(0xFF0056B3),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          : null,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF0056B3), width: 1.8),
      ),
    );
  }

  Widget _fee(
    String title,
    TextEditingController controller, {
    required IconData icon,
    bool optional = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        enabled: !_saving,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Color(0xFF0F172A),
        ),
        decoration: _inputDecoration(
          label: title,
          icon: icon,
          suffixText: 'USD',
          helperText: optional
              ? 'Vacío usa tarifa de consulta · Escribe 0 si es gratis.'
              : null,
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

  Widget? _buildOfferPreview() {
    if (!_offerEnabled) return null;
    final pct = int.tryParse(_percent.text.trim());
    if (pct == null || pct < 1 || pct > 100) return null;

    final consultCents = _parseCents(_consultation.text) ?? 5000;
    int? targetBase;
    String targetName;
    if (_offerCategory == 'exam_delivery') {
      targetName = 'Entrega de exámenes';
      targetBase = _parseCents(_examDelivery.text) ?? consultCents;
    } else if (_offerCategory == 'wound_care') {
      targetName = 'Cura';
      targetBase = _parseCents(_woundCare.text) ?? consultCents;
    } else if (_offerCategory == 'other') {
      targetName = 'Otros motivos';
      targetBase = consultCents;
    } else {
      targetName = _offerCategory == 'all' ? 'Consulta (y todos)' : 'Consulta';
      targetBase = consultCents;
    }

    final discounted = _previewDiscountedCents(targetBase, pct);
    if (discounted == null) return null;

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.visibility_outlined,
              color: Color(0xFF059669), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  'Vista previa ($targetName):',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF065F46),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  priceInUsd(targetBase),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                Text(
                  appointmentPriceLabel(discounted),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF059669),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '-$pct% DTO',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dates = _offerDates;
    final format = MaterialLocalizations.of(context).formatCompactDate;
    final offerPreview = _buildOfferPreview();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text(
          'Tarifas y ofertas',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0056B3),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0056B3)),
            )
          : _loadFailed
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: Color(0xFF64748B), size: 42),
                      const SizedBox(height: 10),
                      const Text(
                        'No se pudo cargar tu configuración.',
                        style: TextStyle(color: Color(0xFF475569)),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : Form(
                  key: _form,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
                        children: [
                          // Banner superior explicativo
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF003893), Color(0xFF0077B6)],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF003893)
                                      .withValues(alpha: 0.22),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.sell_rounded,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Gestiona tus precios y promociones',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      SizedBox(height: 3),
                                      Text(
                                        'Personaliza tarifas por motivo y activa descuentos temporales para destacar en Salud Now.',
                                        style: TextStyle(
                                          color: Color(0xFFE0F2FE),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Tarjeta 1: Tarifas por motivo
                          _card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _sectionHeader(
                                  icon: Icons.medical_services_rounded,
                                  iconColor: const Color(0xFF0056B3),
                                  iconBg: const Color(0xFFE0EAFC),
                                  title: 'Tarifas por motivo',
                                  subtitle:
                                      'Define el costo de cada tipo de atención en USD.',
                                ),
                                const SizedBox(height: 18),
                                _fee(
                                  'Consulta',
                                  _consultation,
                                  icon: Icons.medical_information_rounded,
                                ),
                                _fee(
                                  'Entrega de exámenes',
                                  _examDelivery,
                                  icon: Icons.assignment_turned_in_outlined,
                                  optional: true,
                                ),
                                _fee(
                                  'Cura',
                                  _woundCare,
                                  icon: Icons.healing_outlined,
                                  optional: true,
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.info_outline_rounded,
                                          size: 18, color: Color(0xFF475569)),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Otros motivos aplican automáticamente el precio base de Consulta.',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF475569),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Tarjeta 2: Conversión a bolívares
                          _card(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEDE9FE),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.currency_exchange_rounded,
                                    color: Color(0xFF6D28D9),
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Mostrar conversión a bolívares',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0B2545),
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Calcula el monto equivalente a tasa BCV del día.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch.adaptive(
                                  activeThumbColor: const Color(0xFF0056B3),
                                  value: _showInVes,
                                  onChanged: _saving
                                      ? null
                                      : (value) =>
                                          setState(() => _showInVes = value),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Tarjeta 3: Promociones y descuentos
                          _card(
                            borderColor: _offerEnabled
                                ? const Color(0xFF10B981)
                                : null,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: _offerEnabled
                                            ? const Color(0xFFD1FAE5)
                                            : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(
                                        Icons.local_offer_rounded,
                                        color: _offerEnabled
                                            ? const Color(0xFF059669)
                                            : const Color(0xFF64748B),
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Ofrecer un descuento',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF0B2545),
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            'Aplica a citas dentro de las fechas elegidas.',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch.adaptive(
                                      activeThumbColor: const Color(0xFF059669),
                                      value: _offerEnabled,
                                      onChanged: _saving
                                          ? null
                                          : (value) => setState(
                                              () => _offerEnabled = value),
                                    ),
                                  ],
                                ),
                                AnimatedSize(
                                  duration: const Duration(milliseconds: 240),
                                  curve: Curves.easeOutCubic,
                                  child: _offerEnabled
                                      ? Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: 18),
                                            DropdownButtonFormField<String>(
                                              initialValue: _offerCategory,
                                              decoration: _inputDecoration(
                                                label: 'Motivo con descuento',
                                                icon: Icons.category_outlined,
                                              ),
                                              items: [
                                                const DropdownMenuItem(
                                                    value: 'all',
                                                    child: Text(
                                                        'Todos los motivos')),
                                                for (final reason
                                                    in appointmentCategories
                                                        .entries)
                                                  DropdownMenuItem(
                                                      value: reason.value,
                                                      child: Text(
                                                          appointmentReasons[
                                                              reason.key]!)),
                                              ],
                                              onChanged: _saving
                                                  ? null
                                                  : (value) => setState(() =>
                                                      _offerCategory = value!),
                                            ),
                                            const SizedBox(height: 14),
                                            TextFormField(
                                              controller: _percent,
                                              enabled: !_saving,
                                              keyboardType:
                                                  TextInputType.number,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF0F172A),
                                              ),
                                              decoration: _inputDecoration(
                                                label: 'Porcentaje de descuento',
                                                icon: Icons.percent_rounded,
                                                suffixText: '%',
                                              ),
                                              validator: (value) {
                                                final percent = int.tryParse(
                                                    value?.trim() ?? '');
                                                return percent != null &&
                                                        percent >= 1 &&
                                                        percent <= 100
                                                    ? null
                                                    : 'Ingresa un porcentaje entre 1 y 100.';
                                              },
                                            ),
                                            const SizedBox(height: 10),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 6,
                                              children: [10, 15, 20, 25, 30, 50]
                                                  .map((pct) {
                                                final selected =
                                                    _percent.text.trim() ==
                                                        '$pct';
                                                return ChoiceChip(
                                                  label: Text('$pct%'),
                                                  selected: selected,
                                                  selectedColor:
                                                      const Color(0xFF059669),
                                                  backgroundColor:
                                                      const Color(0xFFF1F5F9),
                                                  labelStyle: TextStyle(
                                                    color: selected
                                                        ? Colors.white
                                                        : const Color(
                                                            0xFF0F172A),
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 12,
                                                  ),
                                                  onSelected: _saving
                                                      ? null
                                                      : (_) => setState(() {
                                                            _percent.text =
                                                                '$pct';
                                                          }),
                                                );
                                              }).toList(),
                                            ),
                                            const SizedBox(height: 14),
                                            InkWell(
                                              onTap:
                                                  _saving ? null : _selectDates,
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 14,
                                                        vertical: 12),
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFFF0F9FF),
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                  border: Border.all(
                                                    color:
                                                        const Color(0xFFBAE6FD),
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.date_range_rounded,
                                                      color: Color(0xFF0056B3),
                                                      size: 20,
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          const Text(
                                                            'Vigencia de la oferta',
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              color: Color(
                                                                  0xFF64748B),
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              height: 2),
                                                          Text(
                                                            dates == null
                                                                ? 'Seleccionar fechas de inicio y fin'
                                                                : '${format(dates.start)} – ${format(dates.end)}',
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              color: dates ==
                                                                      null
                                                                  ? const Color(
                                                                      0xFF0056B3)
                                                                  : const Color(
                                                                      0xFF0B2545),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 10,
                                                          vertical: 5),
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                            0xFF0056B3),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(10),
                                                      ),
                                                      child: Text(
                                                        dates == null
                                                            ? 'Elegir'
                                                            : 'Cambiar',
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            if (offerPreview != null)
                                              offerPreview,
                                          ],
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Botón Guardar cambios estilizado
                          SizedBox(
                            height: 54,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF0056B3),
                                    Color(0xFF0A3D78)
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF0056B3)
                                        .withValues(alpha: 0.28),
                                    blurRadius: 14,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: ElevatedButton.icon(
                                onPressed: _saving ? null : _save,
                                icon: _saving
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white),
                                      )
                                    : const Icon(
                                        Icons.check_circle_outline_rounded),
                                label: Text(
                                  _saving ? 'Guardando…' : 'Guardar cambios',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
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
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }
}
