class MeasurementFormValidators {
  static double? parsePositiveNumber(String? value) {
    final normalized = _normalize(value);
    if (normalized == null) {
      return null;
    }
    final parsed = double.tryParse(normalized);
    if (parsed == null || parsed <= 0) {
      return null;
    }
    return parsed;
  }

  static double? parseBodyFat(String? value) {
    final normalized = _normalize(value);
    if (normalized == null) {
      return null;
    }
    final parsed = double.tryParse(normalized);
    if (parsed == null || parsed < 1 || parsed > 80) {
      return null;
    }
    return parsed;
  }

  static String? requiredWeight(String? value) {
    final parsed = parsePositiveNumber(value);
    if (parsed == null) {
      return 'Weight must be greater than 0.';
    }
    return null;
  }

  static String? optionalWaist(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    if (parsePositiveNumber(trimmed) == null) {
      return 'Waist must be greater than 0.';
    }
    return null;
  }

  static String? optionalBodyFat(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    if (parseBodyFat(trimmed) == null) {
      return 'Body fat must be between 1 and 80.';
    }
    return null;
  }

  static String? _normalize(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed.replaceAll(',', '.');
  }
}
