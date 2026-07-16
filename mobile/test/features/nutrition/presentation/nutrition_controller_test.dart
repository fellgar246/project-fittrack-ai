import 'dart:async';

import 'package:fittrack_ai/core/errors/api_exception.dart';
import 'package:fittrack_ai/features/nutrition/presentation/nutrition_controller.dart';
import 'package:fittrack_ai/features/nutrition/presentation/nutrition_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_nutrition.dart';

void main() {
  late FakeNutritionRepository repository;
  late NutritionController controller;
  late int unauthorizedCalls;

  setUp(() {
    repository = FakeNutritionRepository();
    unauthorizedCalls = 0;
    controller = NutritionController(
      repository,
      onUnauthorized: () async => unauthorizedCalls++,
    );
  });

  tearDown(() => controller.dispose());

  test('initial transitions through loading to loaded', () async {
    repository.loadGate = Completer<void>();

    final load = controller.load();
    expect(controller.state.status, NutritionStatus.loading);

    repository.loadGate!.complete();
    await load;

    expect(controller.state.status, NutritionStatus.loaded);
    expect(controller.state.data?.logs, hasLength(1));
  });

  test('refresh preserves loaded data after temporary failure', () async {
    await controller.load();
    final previous = controller.state.data;
    repository.loadError = const ServerException();

    await controller.refresh();

    expect(controller.state.status, NutritionStatus.loaded);
    expect(controller.state.data, same(previous));
    expect(controller.state.errorMessage, isNotNull);
    expect(controller.state.isRefreshing, isFalse);
  });

  test('retry reloads after global failure', () async {
    repository.loadError = const NetworkException();
    await controller.load();

    repository.loadError = null;
    await controller.retry();

    expect(controller.state.status, NutritionStatus.loaded);
    expect(controller.state.data?.logs, hasLength(1));
  });

  test('localized summary retry clears partial error', () async {
    repository.summaryError = const ServerException();
    await controller.load();

    repository.summaryError = null;
    await controller.retrySummary();

    expect(controller.state.data?.summaryError, isNull);
    expect(controller.state.data?.summary, isNotNull);
  });

  test('401 invalidates the existing auth session', () async {
    repository.loadError = const UnauthorizedException();
    await controller.load();

    expect(unauthorizedCalls, 1);
  });

  test('reloadAfterCreate refreshes data', () async {
    await controller.load();
    repository.items = [
      ...repository.items,
      testNutritionLog,
    ];

    await controller.reloadAfterCreate();

    expect(controller.state.data?.logs, hasLength(2));
  });
}
