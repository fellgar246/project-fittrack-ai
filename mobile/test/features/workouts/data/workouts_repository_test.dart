import 'package:fittrack_ai/core/errors/api_exception.dart';
import 'package:fittrack_ai/features/workouts/data/models/create_workout_log_request.dart';
import 'package:fittrack_ai/features/workouts/data/workouts_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_workouts.dart';

void main() {
  late FakeWorkoutsApi api;
  late WorkoutsRepositoryImpl repository;

  setUp(() {
    api = FakeWorkoutsApi();
    repository = WorkoutsRepositoryImpl(api: api);
  });

  test('loadWorkouts returns plans and logs', () async {
    final data = await repository.loadWorkouts();

    expect(data.plans, hasLength(1));
    expect(data.logs, hasLength(1));
    expect(data.logsError, isNull);
  });

  test('loadWorkouts handles empty plans', () async {
    api.plans = [];

    final data = await repository.loadWorkouts();

    expect(data.plans, isEmpty);
    expect(data.logs, hasLength(1));
  });

  test('loadWorkouts surfaces partial logs error', () async {
    api.logsError = const ServerException();

    final data = await repository.loadWorkouts();

    expect(data.plans, hasLength(1));
    expect(data.logs, isEmpty);
    expect(data.logsError, isNotNull);
  });

  test('loadWorkouts throws on plans failure', () async {
    api.plansError = const NetworkException();

    expect(repository.loadWorkouts(), throwsA(isA<NetworkException>()));
  });

  test('getWorkoutPlan returns detail', () async {
    final detail = await repository.getWorkoutPlan(testPlanId);

    expect(detail.id, testPlanId);
    expect(api.lastPlanId, testPlanId);
  });

  test('createWorkoutLog returns created log', () async {
    final created = await repository.createWorkoutLog(
      CreateWorkoutLogRequest(
        exerciseId: testExerciseId,
        performedAt: DateTime(2026, 7, 3, 10, 30),
        sets: 3,
        reps: 10,
      ),
    );

    expect(created.sets, 3);
    expect(api.createCalls, 1);
  });

  test('createWorkoutLog propagates validation error', () async {
    api.createError =
        const ValidationException('sets: Input should be greater than 0');

    expect(
      repository.createWorkoutLog(
        CreateWorkoutLogRequest(
          exerciseId: testExerciseId,
          performedAt: DateTime(2026, 7, 3, 10, 30),
          sets: 0,
          reps: 10,
        ),
      ),
      throwsA(isA<ValidationException>()),
    );
  });
}
