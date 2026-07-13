import 'package:fittrack_ai/core/errors/api_exception.dart';
import 'package:fittrack_ai/features/measurements/data/models/create_measurement_request.dart';
import 'package:fittrack_ai/features/measurements/presentation/create_measurement_controller.dart';
import 'package:fittrack_ai/features/measurements/presentation/create_measurement_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_measurements.dart';

void main() {
  late FakeMeasurementsRepository repository;
  late CreateMeasurementController controller;
  late int unauthorizedCalls;

  setUp(() {
    repository = FakeMeasurementsRepository();
    unauthorizedCalls = 0;
    controller = CreateMeasurementController(
      repository,
      onUnauthorized: () async => unauthorizedCalls++,
    );
  });

  tearDown(() => controller.dispose());

  test('submit transitions to success', () async {
    final result = await controller.submit(
      CreateMeasurementRequest(
        date: DateTime(2026, 7, 10),
        weight: 69.5,
      ),
    );

    expect(result, isNotNull);
    expect(controller.state.status, CreateMeasurementStatus.success);
    expect(repository.createCalls, 1);
  });

  test('submit failure exposes error message', () async {
    repository.createError = const ValidationException('weight: invalid');

    final result = await controller.submit(
      CreateMeasurementRequest(
        date: DateTime(2026, 7, 10),
        weight: 69.5,
      ),
    );

    expect(result, isNull);
    expect(controller.state.status, CreateMeasurementStatus.failure);
    expect(controller.state.errorMessage, contains('weight'));
  });

  test('prevents duplicate submit while in flight', () async {
    repository.createError = null;
    final first = controller.submit(
      CreateMeasurementRequest(
        date: DateTime(2026, 7, 10),
        weight: 69.5,
      ),
    );
    final second = controller.submit(
      CreateMeasurementRequest(
        date: DateTime(2026, 7, 11),
        weight: 68.5,
      ),
    );

    await Future.wait([first, second]);

    expect(repository.createCalls, 1);
  });

  test('401 invalidates the existing auth session', () async {
    repository.createError = const UnauthorizedException();

    await controller.submit(
      CreateMeasurementRequest(
        date: DateTime(2026, 7, 10),
        weight: 69.5,
      ),
    );

    expect(unauthorizedCalls, 1);
  });
}
