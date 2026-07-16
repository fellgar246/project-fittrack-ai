import 'package:fittrack_ai/features/measurements/data/models/measurement_progress.dart';
import 'package:fittrack_ai/features/weekly_summary/data/models/weekly_recommendation.dart';
import 'package:fittrack_ai/features/weekly_summary/data/models/weekly_summary.dart';
import 'package:fittrack_ai/features/weekly_summary/data/models/weekly_summary_data.dart';

WeeklySummary buildTestWeeklySummary({
  DateTime? weekStart,
  DateTime? weekEnd,
  int workoutLogs = 2,
  int workoutDays = 2,
  int nutritionDaysLogged = 4,
  MeasurementProgress? measurements,
  bool isReadyForRecommendation = true,
  List<String> missingData = const [],
}) {
  final start = weekStart ?? DateTime(2026, 7, 6);
  final end = weekEnd ?? DateTime(2026, 7, 12);
  final progress = measurements ??
      const MeasurementProgress(
        measurementsCount: 2,
        endDate: null,
        endWeight: 68.5,
      );

  return WeeklySummary(
    user: const WeeklySummaryUser(
      id: 'user-id',
      name: 'Demo User',
      goal: 'body recomposition',
    ),
    period: WeeklySummaryPeriod(weekStart: start, weekEnd: end),
    workouts: WeeklyWorkouts(
      totalLogs: workoutLogs,
      totalSets: workoutLogs * 8,
      totalReps: workoutLogs * 40,
      uniqueExercises: workoutLogs,
      workoutDays: workoutDays,
    ),
    nutrition: WeeklyNutrition(
      daysLogged: nutritionDaysLogged,
      avgCalories: nutritionDaysLogged > 0 ? 2100 : null,
      avgProtein: nutritionDaysLogged > 0 ? 140 : null,
      avgCarbs: nutritionDaysLogged > 0 ? 220 : null,
      avgFats: nutritionDaysLogged > 0 ? 70 : null,
      totalCalories: nutritionDaysLogged * 2100,
      totalProtein: nutritionDaysLogged * 140,
      totalCarbs: nutritionDaysLogged * 220,
      totalFats: nutritionDaysLogged * 70,
    ),
    measurements: progress,
    dataQuality: WeeklyDataQuality(
      hasWorkoutData: workoutLogs > 0,
      hasNutritionData: nutritionDaysLogged > 0,
      hasMeasurementData: progress.measurementsCount > 0,
      nutritionDaysLogged: nutritionDaysLogged,
      measurementEntries: progress.measurementsCount,
      isReadyForAiRecommendation: isReadyForRecommendation,
      missingData: missingData,
    ),
  );
}

final testWeeklySummary = buildTestWeeklySummary();

final testWeeklyRecommendation = WeeklyRecommendation(
  id: 'recommendation-id',
  weekStart: DateTime(2026, 6, 29),
  weekEnd: DateTime(2026, 7, 5),
  summary: 'Recovery is on track.',
  insights: const ['Training consistency improved.'],
  recommendation: 'Maintain calories and prioritise recovery.',
  safetyNotes: 'This does not replace medical advice.',
);

final testWeeklySummaryData = WeeklySummaryData(
  summary: testWeeklySummary,
  latestRecommendation: testWeeklyRecommendation,
);

Map<String, dynamic> fullWeeklySummaryJson({
  bool ready = true,
  List<String> missingData = const [],
}) {
  return {
    'user': {
      'id': 'user-id',
      'name': 'Demo User',
      'goal': 'body recomposition',
    },
    'period': {
      'week_start': '2026-07-06',
      'week_end': '2026-07-12',
    },
    'workouts': {
      'total_logs': 2,
      'total_sets': 16,
      'total_reps': 80,
      'unique_exercises': 2,
      'workout_days': 2,
    },
    'nutrition': {
      'days_logged': 4,
      'avg_calories': 2100,
      'avg_protein': 140,
      'avg_carbs': 220,
      'avg_fats': 70,
      'total_calories': 8400,
      'total_protein': 560,
      'total_carbs': 880,
      'total_fats': 280,
    },
    'measurements': {
      'measurements_count': 1,
      'start_date': null,
      'end_date': '2026-07-10',
      'start_weight': null,
      'end_weight': 68.5,
      'weight_change': null,
      'start_waist': null,
      'end_waist': null,
      'waist_change': null,
      'start_body_fat_estimate': null,
      'end_body_fat_estimate': null,
      'body_fat_change': null,
    },
    'data_quality': {
      'has_workout_data': true,
      'has_nutrition_data': true,
      'has_measurement_data': true,
      'nutrition_days_logged': 4,
      'measurement_entries': 1,
      'is_ready_for_ai_recommendation': ready,
      'missing_data': missingData,
    },
  };
}

Map<String, dynamic> recommendationJson({
  String id = 'recommendation-id',
  String weekStart = '2026-07-06',
  String weekEnd = '2026-07-12',
}) {
  return {
    'id': id,
    'week_start': weekStart,
    'week_end': weekEnd,
    'summary': 'On track',
    'insights': ['Consistent nutrition'],
    'recommendation': 'Prioritise recovery.',
    'safety_notes': 'This does not replace medical advice.',
  };
}
