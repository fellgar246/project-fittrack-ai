import '../../../measurements/data/models/measurement_progress.dart';

class WeeklySummaryUser {
  const WeeklySummaryUser({
    required this.id,
    required this.name,
    required this.goal,
  });

  final String id;
  final String name;
  final String goal;

  factory WeeklySummaryUser.fromJson(Map<String, dynamic> json) {
    return WeeklySummaryUser(
      id: _requiredString(json, 'id'),
      name: _requiredString(json, 'name'),
      goal: _requiredString(json, 'goal'),
    );
  }
}

class WeeklySummaryPeriod {
  const WeeklySummaryPeriod({
    required this.weekStart,
    required this.weekEnd,
  });

  final DateTime weekStart;
  final DateTime weekEnd;

  factory WeeklySummaryPeriod.fromJson(Map<String, dynamic> json) {
    return WeeklySummaryPeriod(
      weekStart: _requiredDate(json, 'week_start'),
      weekEnd: _requiredDate(json, 'week_end'),
    );
  }
}

class WeeklyWorkouts {
  const WeeklyWorkouts({
    required this.totalLogs,
    required this.totalSets,
    required this.totalReps,
    required this.uniqueExercises,
    required this.workoutDays,
  });

  final int totalLogs;
  final int totalSets;
  final int totalReps;
  final int uniqueExercises;
  final int workoutDays;

  factory WeeklyWorkouts.fromJson(Map<String, dynamic> json) {
    return WeeklyWorkouts(
      totalLogs: _requiredNonNegativeInt(json, 'total_logs'),
      totalSets: _requiredNonNegativeInt(json, 'total_sets'),
      totalReps: _requiredNonNegativeInt(json, 'total_reps'),
      uniqueExercises: _requiredNonNegativeInt(json, 'unique_exercises'),
      workoutDays: _requiredNonNegativeInt(json, 'workout_days'),
    );
  }
}

class WeeklyNutrition {
  const WeeklyNutrition({
    required this.daysLogged,
    this.avgCalories,
    this.avgProtein,
    this.avgCarbs,
    this.avgFats,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFats,
  });

  final int daysLogged;
  final double? avgCalories;
  final double? avgProtein;
  final double? avgCarbs;
  final double? avgFats;
  final int totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFats;

  factory WeeklyNutrition.fromJson(Map<String, dynamic> json) {
    return WeeklyNutrition(
      daysLogged: _requiredNonNegativeInt(json, 'days_logged'),
      avgCalories: _optionalDouble(json, 'avg_calories'),
      avgProtein: _optionalDouble(json, 'avg_protein'),
      avgCarbs: _optionalDouble(json, 'avg_carbs'),
      avgFats: _optionalDouble(json, 'avg_fats'),
      totalCalories: _requiredNonNegativeInt(json, 'total_calories'),
      totalProtein: _requiredNonNegativeDouble(json, 'total_protein'),
      totalCarbs: _requiredNonNegativeDouble(json, 'total_carbs'),
      totalFats: _requiredNonNegativeDouble(json, 'total_fats'),
    );
  }
}

class WeeklyDataQuality {
  const WeeklyDataQuality({
    required this.hasWorkoutData,
    required this.hasNutritionData,
    required this.hasMeasurementData,
    required this.nutritionDaysLogged,
    required this.measurementEntries,
    required this.isReadyForAiRecommendation,
    required this.missingData,
  });

  final bool hasWorkoutData;
  final bool hasNutritionData;
  final bool hasMeasurementData;
  final int nutritionDaysLogged;
  final int measurementEntries;
  final bool isReadyForAiRecommendation;
  final List<String> missingData;

  factory WeeklyDataQuality.fromJson(Map<String, dynamic> json) {
    return WeeklyDataQuality(
      hasWorkoutData: _requiredBool(json, 'has_workout_data'),
      hasNutritionData: _requiredBool(json, 'has_nutrition_data'),
      hasMeasurementData: _requiredBool(json, 'has_measurement_data'),
      nutritionDaysLogged:
          _requiredNonNegativeInt(json, 'nutrition_days_logged'),
      measurementEntries: _requiredNonNegativeInt(json, 'measurement_entries'),
      isReadyForAiRecommendation:
          _requiredBool(json, 'is_ready_for_ai_recommendation'),
      missingData: _requiredStringList(json, 'missing_data'),
    );
  }
}

class WeeklySummary {
  const WeeklySummary({
    required this.user,
    required this.period,
    required this.workouts,
    required this.nutrition,
    required this.measurements,
    required this.dataQuality,
  });

  final WeeklySummaryUser user;
  final WeeklySummaryPeriod period;
  final WeeklyWorkouts workouts;
  final WeeklyNutrition nutrition;
  final MeasurementProgress measurements;
  final WeeklyDataQuality dataQuality;

  DateTime get weekStart => period.weekStart;
  DateTime get weekEnd => period.weekEnd;
  int get workoutLogs => workouts.totalLogs;
  int get workoutDays => workouts.workoutDays;
  int get nutritionDaysLogged => nutrition.daysLogged;
  bool get isReadyForRecommendation => dataQuality.isReadyForAiRecommendation;
  List<String> get missingData => dataQuality.missingData;

  factory WeeklySummary.fromJson(Map<String, dynamic> json) {
    return WeeklySummary(
      user: WeeklySummaryUser.fromJson(_requiredMap(json, 'user')),
      period: WeeklySummaryPeriod.fromJson(_requiredMap(json, 'period')),
      workouts: WeeklyWorkouts.fromJson(_requiredMap(json, 'workouts')),
      nutrition: WeeklyNutrition.fromJson(_requiredMap(json, 'nutrition')),
      measurements: MeasurementProgress.fromJson(
        _requiredMap(json, 'measurements'),
      ),
      dataQuality:
          WeeklyDataQuality.fromJson(_requiredMap(json, 'data_quality')),
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

double _requiredNonNegativeDouble(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! num || value < 0) {
    throw FormatException('Invalid $key in weekly summary response.');
  }
  return value.toDouble();
}

double? _optionalDouble(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! num) {
    throw FormatException('Invalid $key in weekly summary response.');
  }
  return value.toDouble();
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

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Invalid $key in weekly summary response.');
  }
  return value;
}
