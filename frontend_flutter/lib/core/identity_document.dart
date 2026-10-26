String formatIdentityDocument(Object? value) {
  final normalized = value?.toString().trim().toUpperCase() ?? '';
  final match = RegExp(r'^([VEJGRP])-?(\d{1,12})$').firstMatch(normalized);
  if (match == null) return normalized;
  return '${match.group(1)}-${match.group(2)}';
}
