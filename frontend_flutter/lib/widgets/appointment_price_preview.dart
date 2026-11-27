import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/appointment_pricing.dart';

class AppointmentPricePreview extends StatefulWidget {
  const AppointmentPricePreview({super.key, required this.endpoint});

  final String endpoint;

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
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _request,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Text('Consultando el precio…');
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
        return Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 4,
          children: [
            Text('Precio de la cita · ${appointmentPriceLabel(total)}',
                style: Theme.of(context).textTheme.titleSmall),
            if (discount > 0) ...[
              Text(priceInUsd(price['base_cents'] as int),
                  style:
                      const TextStyle(decoration: TextDecoration.lineThrough)),
              Text('$discount% de descuento'),
            ],
          ],
        );
      },
    );
  }
}
