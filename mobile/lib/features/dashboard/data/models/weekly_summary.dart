import '../../../measurements/data/models/measurement_progress.dart';

class WeeklySummary {
  const WeeklySummary({
    required this.weekStart,
    required this.weekEnd,
    required this.workoutLogs,
    required this.workoutDays,
    required this.nutritionDaysLogged,
    required this.measurements,
    required this.isReadyForRecommendation,
    required this.missingData,
  });

  final DateTime weekStart;
  final DateTime weekEnd;
  final int workoutLogs;
  final int workoutDays;
  final int nutritionDaysLogged;
  final MeasurementProgress measurements;
  final bool isReadyForRecommendation;
  final List<String> missingData;

  factory WeeklySummary.fromJson(Map<String, dynamic> json) {
    final period = _requiredMap(json, 'period');
    final workouts = _requiredMap(json, 'workouts');
    final nutrition = _requiredMap(json, 'nutrition');
    final measurementJson = _requiredMap(json, 'measurements');
    final dataQuality = _requiredMap(json, 'data_quality');

    return WeeklySummary(
      weekStart: _requiredDate(period, 'week_start'),
      weekEnd: _requiredDate(period, 'week_end'),
      workoutLogs: _requiredNonNegativeInt(workouts, 'total_logs'),
      workoutDays: _requiredNonNegativeInt(workouts, 'workout_days'),
      nutritionDaysLogged: _requiredNonNegativeInt(nutrition, 'days_logged'),
      measurements: MeasurementProgress.fromJson(measurementJson),
      isReadyForRecommendation:
          _requiredBool(dataQuality, 'is_ready_for_ai_recommendation'),
      missingData: _requiredStringList(dataQuality, 'missing_data'),
    );
  }
}

Map<String, dynamic> _requiredMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! Map<String, dynamic>) {
    throw FormatException('Invalid $key in weekly summary response.');
  }
  return value;
}

DateTime _requiredDate(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw FormatException('Invalid $key in weekly summary response.');
  }
  final date = DateTime.tryParse(value);
  if (date == null) {
    throw FormatException('Invalid $key in weekly summary response.');
  }
  return date;
}

int _requiredNonNegativeInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int || value < 0) {
    throw FormatException('Invalid $key in weekly summary response.');
  }
  return value;
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) {
    throw FormatException('Invalid $key in weekly summary response.');
  }
  return value;
}

List<String> _requiredStringList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List || value.any((item) => item is! String)) {
    throw FormatException('Invalid $key in weekly summary response.');
  }
  return List<String>.unmodifiable(value.cast<String>());
}
