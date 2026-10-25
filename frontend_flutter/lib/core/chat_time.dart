String formatChatDateTime(dynamic rawValue) {
  final parsed = DateTime.tryParse(rawValue?.toString() ?? '');
  if (parsed == null) return '';
  final value = parsed.toLocal();
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final suffix = value.hour >= 12 ? 'p. m.' : 'a. m.';
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} · ${hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')} $suffix';
}
