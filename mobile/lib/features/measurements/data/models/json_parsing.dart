DateTime? optionalDate(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw FormatException('Invalid $key in measurement response.');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw FormatException('Invalid $key in measurement response.');
  }
  return parsed;
}

DateTime requiredDate(Map<String, dynamic> json, String key) {
  final parsed = optionalDate(json, key);
  if (parsed == null) {
    throw FormatException('Invalid $key in measurement response.');
  }
  return parsed;
}

double? optionalDouble(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! num) {
    throw FormatException('Invalid $key in measurement response.');
  }
  return value.toDouble();
}

double requiredDouble(Map<String, dynamic> json, String key) {
  final value = optionalDouble(json, key);
  if (value == null) {
    throw FormatException('Invalid $key in measurement response.');
  }
  return value;
}

String requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Invalid $key in measurement response.');
  }
  return value;
}

String? optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw FormatException('Invalid $key in measurement response.');
  }
  return value;
}

String dateOnly(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
