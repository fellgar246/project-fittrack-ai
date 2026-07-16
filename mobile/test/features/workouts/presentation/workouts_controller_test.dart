import 'dart:async';

import 'package:fittrack_ai/core/errors/api_exception.dart';
import 'package:fittrack_ai/features/workouts/presentation/workouts_controller.dart';
import 'package:fittrack_ai/features/workouts/presentation/workouts_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_workouts.dart';

void main() {
  late FakeWorkoutsRepository repository;
  late WorkoutsController controller;
  late int unauthorizedCalls;

  setUp(() {
    repository = FakeWorkoutsRepository();
    unauthorizedCalls = 0;
    controller = WorkoutsController(
      repository,
      onUnauthorized: () async => unauthorizedCalls++,
    );
  });

  tearDown(() => controller.dispose());

  test('initial transitions through loading to loaded', () async {
    repository.loadGate = Completer<void>();

    final load = controller.load();
    expect(controller.state.status, WorkoutsStatus.loading);

    repository.loadGate!.complete();
    await load;

    expect(controller.state.status, WorkoutsStatus.loaded);
    expect(controller.state.data?.plans, hasLength(1));
  });

  test('refresh preserves loaded data after temporary failure', () async {
    await controller.load();
    final previous = controller.state.data;
    repository.loadError = const ServerException();

    await controller.refresh();

    expect(controller.state.status, WorkoutsStatus.loaded);
    expect(controller.state.data, same(previous));
    expect(controller.state.errorMessage, isNotNull);
    expect(controller.state.isRefreshing, isFalse);
  });

  test('retry reloads after global failure', () async {
    repository.loadError = const NetworkException();
    await controller.load();

    repository.loadError = null;
    await controller.retry();

    expect(controller.state.status, WorkoutsStatus.loaded);
    expect(controller.state.data?.plans, hasLength(1));
  });

  test('localized logs retry clears partial error', () async {
    repository.logsError = const ServerException();
    await controller.load();

    repository.logsError = null;
    await controller.retryLogs();

    expect(controller.state.data?.logsError, isNull);
    expect(controller.state.data?.logs, hasLength(1));
  });

  test('401 invalidates the existing auth session', () async {
    repository.loadError = const UnauthorizedException();
    await controller.load();

    expect(unauthorizedCalls, 1);
  });

  test('reloadAfterCreate refreshes data', () async {
    await controller.load();
    repository.logs = [
      ...repository.logs,
      testWorkoutLog,
    ];

    await controller.reloadAfterCreate();

    expect(controller.state.data?.logs, hasLength(2));
  });
}
