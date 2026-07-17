DateTime? optionalDateTime(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw FormatException('Invalid $key in progress photo response.');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw FormatException('Invalid $key in progress photo response.');
  }
  return parsed;
}

DateTime requiredDateTime(Map<String, dynamic> json, String key) {
  final parsed = optionalDateTime(json, key);
  if (parsed == null) {
    throw FormatException('Invalid $key in progress photo response.');
  }
  return parsed;
}

DateTime requiredDate(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw FormatException('Invalid $key in progress photo response.');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw FormatException('Invalid $key in progress photo response.');
  }
  return DateTime(parsed.year, parsed.month, parsed.day);
}

int requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! num) {
    throw FormatException('Invalid $key in progress photo response.');
  }
  return value.toInt();
}

String requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Invalid $key in progress photo response.');
  }
  return value;
}

String? optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw FormatException('Invalid $key in progress photo response.');
  }
  return value;
}

String dateOnly(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

Map<String, String> requiredStringMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! Map) {
    throw FormatException('Invalid $key in progress photo response.');
  }
  return value.map((k, v) {
    if (k is! String || v is! String) {
      throw FormatException('Invalid $key in progress photo response.');
    }
    return MapEntry(k, v);
  });
}
