DateTime? optionalDateTime(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw FormatException('Invalid $key in workout response.');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw FormatException('Invalid $key in workout response.');
  }
  return parsed;
}

DateTime requiredDateTime(Map<String, dynamic> json, String key) {
  final parsed = optionalDateTime(json, key);
  if (parsed == null) {
    throw FormatException('Invalid $key in workout response.');
  }
  return parsed;
}

double? optionalDouble(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! num) {
    throw FormatException('Invalid $key in workout response.');
  }
  return value.toDouble();
}

int? optionalInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! int) {
    throw FormatException('Invalid $key in workout response.');
  }
  return value;
}

int requiredInt(Map<String, dynamic> json, String key) {
  final value = optionalInt(json, key);
  if (value == null) {
    throw FormatException('Invalid $key in workout response.');
  }
  return value;
}

int requiredPositiveInt(Map<String, dynamic> json, String key) {
  final value = requiredInt(json, key);
  if (value <= 0) {
    throw FormatException('Invalid $key in workout response.');
  }
  return value;
}

String requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Invalid $key in workout response.');
  }
  return value;
}

String? optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw FormatException('Invalid $key in workout response.');
  }
  return value;
}

bool requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) {
    throw FormatException('Invalid $key in workout response.');
  }
  return value;
}

String dateOnly(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
