class AvatarCatalog {
  static const int patientCount = 15;
  static const int doctorCount = 15;
  static const int assistantCount = 15;
  static const int clinicCount = 6;

  static String normalizeRole(String? role) {
    switch (role?.toLowerCase()) {
      case 'doctor':
        return 'doctor';
      case 'assistant':
        return 'assistant';
      case 'clinic':
        return 'clinic';
      default:
        return 'patient';
    }
  }

  static String assetForRole(String role) {
    switch (normalizeRole(role)) {
      case 'doctor':
        return 'assets/avatars/doctors.png';
      case 'assistant':
        return 'assets/avatars/assistants.png';
      case 'clinic':
        return 'assets/avatars/clinics.png';
      default:
        return 'assets/avatars/patients.png';
    }
  }

  static int columnsForRole(String role) =>
      normalizeRole(role) == 'clinic' ? 3 : 5;

  static int rowsForRole(String role) =>
      normalizeRole(role) == 'clinic' ? 2 : 3;

  static int countForRole(String role) {
    switch (normalizeRole(role)) {
      case 'doctor':
        return doctorCount;
      case 'assistant':
        return assistantCount;
      case 'clinic':
        return clinicCount;
      default:
        return patientCount;
    }
  }

  static String presetUrl(String role, int index) =>
      'preset:${normalizeRole(role)}:$index';

  static ({String role, int index})? parse(String? value) {
    if (value == null || !value.startsWith('preset:')) return null;
    final parts = value.split(':');
    if (parts.length != 3) return null;
    final role = normalizeRole(parts[1]);
    final index = int.tryParse(parts[2]);
    if (index == null || index < 0 || index >= countForRole(role)) return null;
    return (role: role, index: index);
  }
}
