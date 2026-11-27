const appointmentReasons = {
  'Consulta': 'Consulta',
  'Entrega de examenes': 'Entrega de exámenes',
  'Cura': 'Cura',
  'Otros': 'Otros',
};

const appointmentCategories = {
  'Consulta': 'consultation',
  'Entrega de examenes': 'exam_delivery',
  'Cura': 'wound_care',
  'Otros': 'other',
};

String appointmentPriceEndpoint({
  int? doctorId,
  required String date,
  required String reason,
}) {
  final path = doctorId == null ? '/appointments/manual' : '/doctors/$doctorId';
  return '$path/appointment-price?appointment_date=$date&category=${appointmentCategories[reason]}';
}

String priceInUsd(int cents) => 'USD ${(cents / 100).toStringAsFixed(2)}';

String appointmentPriceLabel(int cents) =>
    cents == 0 ? 'Sin costo' : priceInUsd(cents);

String? savedAppointmentPrice(Map<String, dynamic> appointment) {
  final price = appointment['price'];
  final cents = price is Map ? price['total_cents'] : null;
  return cents is int ? appointmentPriceLabel(cents) : null;
}
