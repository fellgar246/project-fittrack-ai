import 'dart:async';

import 'package:fittrack_ai/core/errors/api_exception.dart';
import 'package:fittrack_ai/features/measurements/presentation/measurements_controller.dart';
import 'package:fittrack_ai/features/measurements/presentation/measurements_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_measurements.dart';

void main() {
  late FakeMeasurementsRepository repository;
  late MeasurementsController controller;
  late int unauthorizedCalls;

  setUp(() {
    repository = FakeMeasurementsRepository();
    unauthorizedCalls = 0;
    controller = MeasurementsController(
      repository,
      onUnauthorized: () async => unauthorizedCalls++,
    );
  });

  tearDown(() => controller.dispose());

  test('initial transitions through loading to loaded', () async {
    repository.loadGate = Completer<void>();

    final load = controller.load();
    expect(controller.state.status, MeasurementsStatus.loading);

    repository.loadGate!.complete();
    await load;

    expect(controller.state.status, MeasurementsStatus.loaded);
    expect(controller.state.data?.items, hasLength(1));
  });

  test('refresh preserves loaded data after temporary failure', () async {
    await controller.load();
    final previous = controller.state.data;
    repository.loadError = const ServerException();

    await controller.refresh();

    expect(controller.state.status, MeasurementsStatus.loaded);
    expect(controller.state.data, same(previous));
    expect(controller.state.errorMessage, isNotNull);
    expect(controller.state.isRefreshing, isFalse);
  });

  test('retry reloads after global failure', () async {
    repository.loadError = const NetworkException();
    await controller.load();

    repository.loadError = null;
    await controller.retry();

    expect(controller.state.status, MeasurementsStatus.loaded);
    expect(controller.state.data?.items, hasLength(1));
  });

  test('localized progress retry clears partial error', () async {
    repository.progressError = const ServerException();
    await controller.load();

    repository.progressError = null;
    await controller.retryProgress();

    expect(controller.state.data?.progressError, isNull);
    expect(controller.state.data?.progress, isNotNull);
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
      testMeasurementItem,
    ];

    await controller.reloadAfterCreate();

    expect(controller.state.data?.items, hasLength(2));
  });
}
