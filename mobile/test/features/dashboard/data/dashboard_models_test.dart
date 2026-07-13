import 'package:fittrack_ai/features/measurements/data/models/measurement_progress.dart';
import 'package:fittrack_ai/features/dashboard/data/models/recommendation_summary.dart';
import 'package:fittrack_ai/features/dashboard/data/models/weekly_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('dashboard DTOs', () {
    test('parses valid weekly summary', () {
      final summary = WeeklySummary.fromJson(_weeklyJson);

      expect(summary.workoutLogs, 2);
      expect(summary.nutritionDaysLogged, 4);
      expect(summary.measurements.endWeight, 68.5);
      expect(summary.isReadyForRecommendation, isTrue);
    });

    test('parses controlled empty measurement progress', () {
      final progress = MeasurementProgress.fromJson({
        'measurements_count': 0,
        'start_date': null,
        'end_date': null,
        'start_weight': null,
        'end_weight': null,
        'weight_change': null,
        'start_waist': null,
        'end_waist': null,
        'waist_change': null,
        'start_body_fat_estimate': null,
        'end_body_fat_estimate': null,
        'body_fat_change': null,
      });

      expect(progress.isEmpty, isTrue);
      expect(progress.endWeight, isNull);
    });

    test('parses recommendation with optional safety notes', () {
      final recommendation = RecommendationSummary.fromJson({
        'id': 'recommendation-id',
        'week_start': '2026-07-06',
        'week_end': '2026-07-12',
        'summary': 'On track',
        'insights': ['Consistent nutrition'],
        'recommendation': 'Prioritise recovery.',
        'safety_notes': null,
      });

      expect(recommendation.recommendation, 'Prioritise recovery.');
      expect(recommendation.safetyNotes, isNull);
    });

    test('rejects invalid weekly payload', () {
      final invalid = Map<String, dynamic>.from(_weeklyJson)
        ..['workouts'] = {'total_logs': 'two', 'workout_days': 2};

      expect(
        () => WeeklySummary.fromJson(invalid),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects invalid optional measurement value', () {
      expect(
        () => MeasurementProgress.fromJson({
          'measurements_count': 1,
          'end_weight': '68.5',
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

final _weeklyJson = <String, dynamic>{
  'period': {
    'week_start': '2026-07-06',
    'week_end': '2026-07-12',
  },
  'workouts': {
    'total_logs': 2,
    'workout_days': 2,
  },
  'nutrition': {
    'days_logged': 4,
  },
  'measurements': {
    'measurements_count': 1,
    'end_date': '2026-07-10',
    'end_weight': 68.5,
  },
  'data_quality': {
    'is_ready_for_ai_recommendation': true,
    'missing_data': <String>[],
  },
};
