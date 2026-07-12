class MeasurementProgress {
  const MeasurementProgress({
    required this.measurementsCount,
    this.startDate,
    this.endDate,
    this.startWeight,
    this.endWeight,
    this.weightChange,
    this.startWaist,
    this.endWaist,
    this.waistChange,
    this.startBodyFatEstimate,
    this.endBodyFatEstimate,
    this.bodyFatChange,
  });

  final int measurementsCount;
  final DateTime? startDate;
  final DateTime? endDate;
  final double? startWeight;
  final double? endWeight;
  final double? weightChange;
  final double? startWaist;
  final double? endWaist;
  final double? waistChange;
  final double? startBodyFatEstimate;
  final double? endBodyFatEstimate;
  final double? bodyFatChange;

  bool get isEmpty => measurementsCount == 0;

  factory MeasurementProgress.fromJson(Map<String, dynamic> json) {
    final count = json['measurements_count'];
    if (count is! int || count < 0) {
      throw const FormatException(
        'Invalid measurements_count in measurement progress response.',
      );
    }

    return MeasurementProgress(
      measurementsCount: count,
      startDate: _optionalDate(json, 'start_date'),
      endDate: _optionalDate(json, 'end_date'),
      startWeight: _optionalDouble(json, 'start_weight'),
      endWeight: _optionalDouble(json, 'end_weight'),
      weightChange: _optionalDouble(json, 'weight_change'),
      startWaist: _optionalDouble(json, 'start_waist'),
      endWaist: _optionalDouble(json, 'end_waist'),
      waistChange: _optionalDouble(json, 'waist_change'),
      startBodyFatEstimate: _optionalDouble(json, 'start_body_fat_estimate'),
      endBodyFatEstimate: _optionalDouble(json, 'end_body_fat_estimate'),
      bodyFatChange: _optionalDouble(json, 'body_fat_change'),
    );
  }
}

DateTime? _optionalDate(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw FormatException('Invalid $key in measurement progress response.');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw FormatException('Invalid $key in measurement progress response.');
  }
  return parsed;
}

double? _optionalDouble(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! num) {
    throw FormatException('Invalid $key in measurement progress response.');
  }
  return value.toDouble();
}
