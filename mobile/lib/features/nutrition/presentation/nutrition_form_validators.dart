class NutritionFormValidators {
  static int? parseNonNegativeInt(String? value) {
    final normalized = _normalize(value);
    if (normalized == null) {
      return null;
    }
    final parsed = int.tryParse(normalized);
    if (parsed == null || parsed < 0) {
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

  static String? requiredCalories(String? value) {
    final parsed = parseNonNegativeInt(value);
    if (parsed == null) {
      return 'Calories must be zero or greater.';
    }
    return null;
  }

  static String? requiredProtein(String? value) {
    final parsed = parseNonNegativeNumber(value);
    if (parsed == null) {
      return 'Protein must be zero or greater.';
    }
    return null;
  }

  static String? requiredCarbs(String? value) {
    final parsed = parseNonNegativeNumber(value);
    if (parsed == null) {
      return 'Carbs must be zero or greater.';
    }
    return null;
  }

  static String? requiredFats(String? value) {
    final parsed = parseNonNegativeNumber(value);
    if (parsed == null) {
      return 'Fats must be zero or greater.';
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
