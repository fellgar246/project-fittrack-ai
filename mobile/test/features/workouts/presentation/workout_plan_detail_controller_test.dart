import 'package:fittrack_ai/core/errors/api_exception.dart';
import 'package:fittrack_ai/features/workouts/presentation/workout_plan_detail_controller.dart';
import 'package:fittrack_ai/features/workouts/presentation/workout_plan_detail_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_workouts.dart';

void main() {
  late FakeWorkoutsRepository repository;
  late WorkoutPlanDetailController controller;
  late int unauthorizedCalls;

  setUp(() {
    repository = FakeWorkoutsRepository();
    unauthorizedCalls = 0;
    controller = WorkoutPlanDetailController(
      repository,
      testPlanId,
      onUnauthorized: () async => unauthorizedCalls++,
    );
  });

  tearDown(() => controller.dispose());

  test('load transitions through loading to loaded', () async {
    final load = controller.load();
    expect(controller.state.status, WorkoutPlanDetailStatus.loading);

    await load;

    expect(controller.state.status, WorkoutPlanDetailStatus.loaded);
    expect(controller.state.plan?.name, 'Strength Builder');
  });

  test('retry reloads after failure', () async {
    repository.planDetailError = const NetworkException();
    await controller.load();

    repository.planDetailError = null;
    await controller.retry();

    expect(controller.state.status, WorkoutPlanDetailStatus.loaded);
    expect(controller.state.plan?.days, hasLength(1));
  });

  test('401 invalidates the existing auth session', () async {
    repository.planDetailError = const UnauthorizedException();
    await controller.load();

    expect(unauthorizedCalls, 1);
  });
}
