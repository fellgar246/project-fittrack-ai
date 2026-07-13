import 'dart:async';

import 'package:fittrack_ai/core/errors/api_exception.dart';
import 'package:fittrack_ai/features/measurements/data/measurements_repository.dart';
import 'package:fittrack_ai/features/measurements/data/models/create_measurement_request.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_measurements.dart';

void main() {
  late FakeMeasurementsApi api;
  late MeasurementsRepositoryImpl repository;

  setUp(() {
    api = FakeMeasurementsApi();
    repository = MeasurementsRepositoryImpl(api: api);
  });

  test('loads list and progress together', () async {
    final data = await repository.loadMeasurements();

    expect(data.items, hasLength(1));
    expect(data.progress?.endWeight, 70.2);
    expect(data.progressError, isNull);
  });

  test('empty list is valid with progress', () async {
    api.items = [];

    final data = await repository.loadMeasurements();

    expect(data.isEmpty, isTrue);
    expect(data.progress, isNotNull);
  });

  test('progress failure is localized', () async {
    api.progressError = const ServerException();

    final data = await repository.loadMeasurements();

    expect(data.items, hasLength(1));
    expect(data.progress, isNull);
    expect(data.progressError, isNotNull);
  });

  test('list failure is global', () async {
    api.listError = const NetworkException();

    expect(repository.loadMeasurements(), throwsA(isA<NetworkException>()));
  });

  test('create success returns measurement', () async {
    final created = await repository.createMeasurement(
      CreateMeasurementRequest(
        date: DateTime(2026, 7, 10),
        weight: 69.5,
      ),
    );

    expect(created.weight, 69.5);
    expect(api.createCalls, 1);
  });

  test('create failure propagates', () async {
    api.createError = const ValidationException('weight: invalid');

    expect(
      repository.createMeasurement(
        CreateMeasurementRequest(
          date: DateTime(2026, 7, 10),
          weight: 69.5,
        ),
      ),
      throwsA(isA<ValidationException>()),
    );
  });

  test('starts list and progress in parallel', () async {
    api.requestGate = Completer<void>();

    final load = repository.loadMeasurements();
    await Future<void>.delayed(Duration.zero);

    expect(api.maxActiveRequests, 2);
    api.requestGate!.complete();
    await load;
  });

  test('unauthorized list request is global', () async {
    api.listError = const UnauthorizedException();

    expect(
      repository.loadMeasurements(),
      throwsA(isA<UnauthorizedException>()),
    );
  });

  test('unauthorized progress request is global', () async {
    api.progressError = const UnauthorizedException();

    expect(
      repository.loadMeasurements(),
      throwsA(isA<UnauthorizedException>()),
    );
  });

  test('loadProgress delegates to api', () async {
    final progress = await repository.loadProgress();

    expect(progress.measurementsCount, 2);
    expect(api.progressCalls, 1);
  });
}
