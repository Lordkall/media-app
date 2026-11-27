import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:salud_now/widgets/appointment_price_preview.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
      'Shows free appointments and refreshes the quote when the date changes',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    const first =
        '/doctors/8/appointment-price?appointment_date=2026-11-26&category=exam_delivery';
    const second =
        '/doctors/8/appointment-price?appointment_date=2026-11-27&category=exam_delivery';
    final preview = GlobalKey<AppointmentPricePreviewState>();
    final endpoint = ValueNotifier(first);
    addTearDown(endpoint.dispose);

    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ValueListenableBuilder(
          valueListenable: endpoint,
          builder: (_, url, __) =>
              AppointmentPricePreview(key: preview, endpoint: url),
        )),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Precio de la cita · Sin costo'), findsOneWidget);
      expect(preview.currentState!.totalFor(first), 0);

      endpoint.value = second;
      await tester.pumpAndSettle();
      expect(preview.currentState!.totalFor(first), isNull);
      expect(preview.currentState!.totalFor(second), 1500);
      expect(find.text('Precio de la cita · USD 15.00'), findsOneWidget);
      expect(find.text('USD 20.00'), findsOneWidget);
      expect(find.text('25% de descuento'), findsOneWidget);
    },
        () => MockClient((request) async {
              final firstDate =
                  request.url.queryParameters['appointment_date'] ==
                      '2026-11-26';
              return http.Response(
                  jsonEncode({
                    'base_cents': firstDate ? 0 : 2000,
                    'total_cents': firstDate ? 0 : 1500,
                    'discount_percent': firstDate ? 0 : 25,
                  }),
                  200);
            }));
  });
}
