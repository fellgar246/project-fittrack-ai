class WorkoutFormValidators {
  static int? parsePositiveInt(String? value) {
    final normalized = _normalize(value);
    if (normalized == null) {
      return null;
    }
    final parsed = int.tryParse(normalized);
    if (parsed == null || parsed <= 0) {
      return null;
    }
    return parsed;
  }

  static double? parseNonNegativeNumber(String? value) {
    final normalized = _normalize(value);
    if (normalized == null) {
      return null;
    }
    final parsed = double.tryParse(normalized);
    if (parsed == null || parsed < 0) {
      return null;
    }
    return parsed;
  }

  static String? requiredSets(String? value) {
    final parsed = parsePositiveInt(value);
    if (parsed == null) {
      return 'Sets must be greater than zero.';
    }
    return null;
  }

  static String? requiredReps(String? value) {
    final parsed = parsePositiveInt(value);
    if (parsed == null) {
      return 'Reps must be greater than zero.';
    }
    return null;
  }

  static String? optionalWeight(String? value) {
    final normalized = _normalize(value);
    if (normalized == null) {
      return null;
    }
    final parsed = parseNonNegativeNumber(value);
    if (parsed == null) {
      return 'Weight must be zero or greater.';
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
