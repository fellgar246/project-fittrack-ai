import 'dart:async';

import 'package:fittrack_ai/core/errors/api_exception.dart';
import 'package:fittrack_ai/features/workouts/data/models/create_workout_log_request.dart';
import 'package:fittrack_ai/features/workouts/presentation/create_workout_log_controller.dart';
import 'package:fittrack_ai/features/workouts/presentation/create_workout_log_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_workouts.dart';

void main() {
  late FakeWorkoutsRepository repository;
  late CreateWorkoutLogController controller;
  late int unauthorizedCalls;

  setUp(() {
    repository = FakeWorkoutsRepository();
    unauthorizedCalls = 0;
    controller = CreateWorkoutLogController(
      repository,
      onUnauthorized: () async => unauthorizedCalls++,
    );
  });

  tearDown(() => controller.dispose());

  test('submit transitions to success', () async {
    final log = await controller.submit(
      CreateWorkoutLogRequest(
        exerciseId: testExerciseId,
        performedAt: DateTime(2026, 7, 3, 10, 30),
        sets: 3,
        reps: 10,
      ),
    );

    expect(log, isNotNull);
    expect(controller.state.status, CreateWorkoutLogStatus.success);
  });

  test('submit failure preserves error message', () async {
    repository.createError =
        const ValidationException('sets: Input should be greater than 0');

    final log = await controller.submit(
      CreateWorkoutLogRequest(
        exerciseId: testExerciseId,
        performedAt: DateTime(2026, 7, 3, 10, 30),
        sets: 0,
        reps: 10,
      ),
    );

    expect(log, isNull);
    expect(controller.state.status, CreateWorkoutLogStatus.failure);
    expect(controller.state.errorMessage, contains('sets'));
  });

  test('double submit guard prevents duplicate requests', () async {
    repository.createGate = Completer<void>();

    final first = controller.submit(
      CreateWorkoutLogRequest(
        exerciseId: testExerciseId,
        performedAt: DateTime(2026, 7, 3, 10, 30),
        sets: 3,
        reps: 10,
      ),
    );
    final second = controller.submit(
      CreateWorkoutLogRequest(
        exerciseId: testExerciseId,
        performedAt: DateTime(2026, 7, 3, 10, 30),
        sets: 3,
        reps: 10,
      ),
    );

    expect(controller.state.isSubmitting, isTrue);
    repository.createGate!.complete();
    await first;
    await second;

    expect(repository.createCalls, 1);
  });

  test('401 invalidates the existing auth session', () async {
    repository.createError = const UnauthorizedException();

    await controller.submit(
      CreateWorkoutLogRequest(
        exerciseId: testExerciseId,
        performedAt: DateTime(2026, 7, 3, 10, 30),
        sets: 3,
        reps: 10,
      ),
    );

    expect(unauthorizedCalls, 1);
  });
}
