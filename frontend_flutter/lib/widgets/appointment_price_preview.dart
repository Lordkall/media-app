import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/appointment_pricing.dart';

class AppointmentPricePreview extends StatefulWidget {
  const AppointmentPricePreview({
    super.key,
    required this.endpoint,
    this.onPriceChanged,
  });

  final String endpoint;
  final ValueChanged<Map<String, dynamic>?>? onPriceChanged;

  @override
  State<AppointmentPricePreview> createState() =>
      AppointmentPricePreviewState();
}

class AppointmentPricePreviewState extends State<AppointmentPricePreview> {
  late Future<Map<String, dynamic>> _request;
  int? _totalCents;

  // Require the quote to match the exact date, doctor and reason being booked.
  int? totalFor(String endpoint) =>
      endpoint == widget.endpoint ? _totalCents : null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AppointmentPricePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endpoint != widget.endpoint) _load();
  }

  void refresh() => setState(_load);

  void _load() {
    _totalCents = null;
    _request = _fetch(widget.endpoint);
  }

  Future<Map<String, dynamic>> _fetch(String endpoint) async {
    final response =
        await ApiClient.get(endpoint).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) throw StateError('Precio no disponible');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (mounted && endpoint == widget.endpoint) {
      widget.onPriceChanged?.call({...data, 'endpoint': endpoint});
    }
    return data;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _request,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF0056B3),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Consultando el precio…',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }
        final price = snapshot.data;
        final total = price?['total_cents'];
        if (total is! int) {
          return TextButton.icon(
            onPressed: refresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar consulta del precio'),
          );
        }
        _totalCents = total;
        final discount = price!['discount_percent'] as int;
        final baseCents = price['base_cents'] as int;
        final isDiscounted = discount > 0;
        final isFree = total == 0;
        final accent = (isDiscounted || isFree)
            ? const Color(0xFF059669)
            : const Color(0xFF0056B3);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: (isDiscounted || isFree)
                ? const Color(0xFFECFDF5)
                : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: (isDiscounted || isFree)
                  ? const Color(0xFFA7F3D0)
                  : const Color(0xFFCBD5E1),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isDiscounted
                      ? Icons.local_offer_rounded
                      : (isFree
                          ? Icons.check_circle_outline_rounded
                          : Icons.payments_outlined),
                  size: 18,
                  color: accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Text(
                      'Precio de la cita · ${appointmentPriceLabel(total)}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: (isDiscounted || isFree)
                                ? const Color(0xFF065F46)
                                : const Color(0xFF0B2545),
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    if (isDiscounted) ...[
                      Text(
                        priceInUsd(baseCents),
                        style: const TextStyle(
                          decoration: TextDecoration.lineThrough,
                          color: Color(0xFF64748B),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF059669),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$discount% de descuento',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
