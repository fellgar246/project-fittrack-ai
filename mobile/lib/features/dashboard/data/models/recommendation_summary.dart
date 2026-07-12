class RecommendationSummary {
  const RecommendationSummary({
    required this.id,
    required this.weekStart,
    required this.weekEnd,
    required this.summary,
    required this.insights,
    required this.recommendation,
    this.safetyNotes,
  });

  final String id;
  final DateTime weekStart;
  final DateTime weekEnd;
  final String summary;
  final List<String> insights;
  final String recommendation;
  final String? safetyNotes;

  factory RecommendationSummary.fromJson(Map<String, dynamic> json) {
    return RecommendationSummary(
      id: _requiredString(json, 'id'),
      weekStart: _requiredDate(json, 'week_start'),
      weekEnd: _requiredDate(json, 'week_end'),
      summary: _requiredString(json, 'summary'),
      insights: _requiredStringList(json, 'insights'),
      recommendation: _requiredString(json, 'recommendation'),
      safetyNotes: _optionalString(json, 'safety_notes'),
    );
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Invalid $key in recommendation response.');
  }
  return value;
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw FormatException('Invalid $key in recommendation response.');
  }
  return value;
}

DateTime _requiredDate(Map<String, dynamic> json, String key) {
  final value = _requiredString(json, key);
  final date = DateTime.tryParse(value);
  if (date == null) {
    throw FormatException('Invalid $key in recommendation response.');
  }
  return date;
}

List<String> _requiredStringList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List || value.any((item) => item is! String)) {
    throw FormatException('Invalid $key in recommendation response.');
  }
  return List<String>.unmodifiable(value.cast<String>());
}
