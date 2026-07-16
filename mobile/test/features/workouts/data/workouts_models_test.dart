import 'package:fittrack_ai/features/workouts/data/models/create_workout_log_request.dart';
import 'package:fittrack_ai/features/workouts/data/models/workout_log.dart';
import 'package:fittrack_ai/features/workouts/data/models/workout_plan.dart';
import 'package:fittrack_ai/features/workouts/data/models/workout_plan_detail.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses workout plan summary', () {
    final plan = WorkoutPlan.fromJson({
      'id': 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      'name': 'Strength Builder',
      'goal': 'Build muscle',
      'active': true,
      'days_count': 3,
      'exercises_count': 9,
    });

    expect(plan.name, 'Strength Builder');
    expect(plan.daysCount, 3);
    expect(plan.exercisesCount, 9);
  });

  test('parses workout plan detail with exercises', () {
    final detail = WorkoutPlanDetail.fromJson({
      'id': 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      'name': 'Strength Builder',
      'goal': 'Build muscle',
      'active': true,
      'days': [
        {
          'id': 'dddddddd-dddd-dddd-dddd-dddddddddddd',
          'day_of_week': 1,
          'title': 'Push day',
          'exercises': [
            {
              'id': 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
              'name': 'Bench press',
              'muscle_group': 'Chest',
              'target_sets': 3,
              'target_reps': '10',
            },
          ],
        },
      ],
    });

    expect(detail.days, hasLength(1));
    expect(detail.days.first.exercises.first.targetReps, '10');
    expect(detail.exercisesCount, 1);
  });

  test('parses workout log with optional fields', () {
    final log = WorkoutLog.fromJson({
      'id': 'cccccccc-cccc-cccc-cccc-cccccccccccc',
      'exercise_id': 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
      'exercise_name': 'Bench press',
      'performed_at': '2026-07-03T10:30:00.000',
      'sets': 3,
      'reps': 10,
      'weight': 60.5,
      'notes': 'Completed demo workout',
    });

    expect(log.sets, 3);
    expect(log.weight, 60.5);
    expect(log.notes, 'Completed demo workout');
  });

  test('parses workout log with null weight and notes', () {
    final log = WorkoutLog.fromJson({
      'id': 'cccccccc-cccc-cccc-cccc-cccccccccccc',
      'exercise_id': 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
      'exercise_name': 'Bench press',
      'performed_at': '2026-07-03T10:30:00.000',
      'sets': 3,
      'reps': 10,
      'weight': null,
      'notes': null,
    });

    expect(log.weight, isNull);
    expect(log.notes, isNull);
  });

  test('parses int weight as double', () {
    final log = WorkoutLog.fromJson({
      'id': 'cccccccc-cccc-cccc-cccc-cccccccccccc',
      'exercise_id': 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
      'exercise_name': 'Bench press',
      'performed_at': '2026-07-03T10:30:00.000',
      'sets': 3,
      'reps': 10,
      'weight': 60,
      'notes': null,
    });

    expect(log.weight, 60.0);
  });

  test('create request omits null optionals', () {
    final request = CreateWorkoutLogRequest(
      exerciseId: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
      performedAt: DateTime(2026, 7, 3, 10, 30),
      sets: 3,
      reps: 10,
    );

    final json = request.toJson();

    expect(json.containsKey('weight'), isFalse);
    expect(json.containsKey('notes'), isFalse);
    expect(json['sets'], 3);
  });

  test('rejects invalid workout log payload', () {
    expect(
      () => WorkoutLog.fromJson({
        'id': 'cccccccc-cccc-cccc-cccc-cccccccccccc',
        'exercise_id': 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
        'exercise_name': 'Bench press',
        'performed_at': 'not-a-date',
        'sets': 3,
        'reps': 10,
        'weight': null,
        'notes': null,
      }),
      throwsA(isA<FormatException>()),
    );
  });
}
