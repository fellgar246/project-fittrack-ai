import 'json_parsing.dart';

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

  bool get hasTrend => measurementsCount > 1;

  factory MeasurementProgress.fromJson(Map<String, dynamic> json) {
    final count = json['measurements_count'];
    if (count is! int || count < 0) {
      throw const FormatException(
        'Invalid measurements_count in measurement progress response.',
      );
    }

    return MeasurementProgress(
      measurementsCount: count,
      startDate: optionalDate(json, 'start_date'),
      endDate: optionalDate(json, 'end_date'),
      startWeight: optionalDouble(json, 'start_weight'),
      endWeight: optionalDouble(json, 'end_weight'),
      weightChange: optionalDouble(json, 'weight_change'),
      startWaist: optionalDouble(json, 'start_waist'),
      endWaist: optionalDouble(json, 'end_waist'),
      waistChange: optionalDouble(json, 'waist_change'),
      startBodyFatEstimate: optionalDouble(json, 'start_body_fat_estimate'),
      endBodyFatEstimate: optionalDouble(json, 'end_body_fat_estimate'),
      bodyFatChange: optionalDouble(json, 'body_fat_change'),
    );
  }
}
