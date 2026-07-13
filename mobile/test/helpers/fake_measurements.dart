import 'dart:async';

import 'package:fittrack_ai/features/measurements/data/measurements_api.dart';
import 'package:fittrack_ai/core/errors/api_exception.dart';
import 'package:fittrack_ai/features/measurements/data/measurements_repository.dart';
import 'package:fittrack_ai/features/measurements/data/models/create_measurement_request.dart';
import 'package:fittrack_ai/features/measurements/data/models/measurement.dart';
import 'package:fittrack_ai/features/measurements/data/models/measurement_progress.dart';
import 'package:fittrack_ai/features/measurements/data/models/measurements_data.dart';

final testMeasurementItem = Measurement(
  id: '11111111-1111-1111-1111-111111111111',
  date: DateTime(2026, 7, 3),
  weight: 70.2,
  waist: 82.5,
  bodyFatEstimate: 24.5,
  notes: 'Morning measurement after cardio day.',
);

final testMeasurementProgress = MeasurementProgress(
  measurementsCount: 2,
  startDate: DateTime(2026, 7, 1),
  endDate: DateTime(2026, 7, 31),
  startWeight: 71,
  endWeight: 70.2,
  weightChange: -0.8,
  startWaist: 83.2,
  endWaist: 82.5,
  waistChange: -0.7,
  startBodyFatEstimate: 25,
  endBodyFatEstimate: 24.5,
  bodyFatChange: -0.5,
);

class FakeMeasurementsApi implements MeasurementsApi {
  List<Measurement> items = [testMeasurementItem];
  MeasurementProgress progress = testMeasurementProgress;
  Measurement? created;
  Object? listError;
  Object? progressError;
  Object? createError;
  Completer<void>? requestGate;
  var activeRequests = 0;
  var maxActiveRequests = 0;
  var listCalls = 0;
  var progressCalls = 0;
  var createCalls = 0;

  @override
  Future<List<Measurement>> getMeasurements({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) {
    return _run(() {
      listCalls++;
      if (listError != null) throw listError!;
      return items;
    });
  }

  @override
  Future<Measurement> createMeasurement(CreateMeasurementRequest request) {
    return _run(() {
      createCalls++;
      if (createError != null) throw createError!;
      created = Measurement(
        id: '22222222-2222-2222-2222-222222222222',
        date: request.date,
        weight: request.weight,
        waist: request.waist,
        bodyFatEstimate: request.bodyFatEstimate,
        notes: request.notes,
      );
      return created!;
    });
  }

  @override
  Future<MeasurementProgress> getProgress({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) {
    return _run(() {
      progressCalls++;
      if (progressError != null) throw progressError!;
      return progress;
    });
  }

  Future<T> _run<T>(T Function() result) async {
    activeRequests++;
    if (activeRequests > maxActiveRequests) {
      maxActiveRequests = activeRequests;
    }
    await requestGate?.future;
    try {
      return result();
    } finally {
      activeRequests--;
    }
  }
}

class FakeMeasurementsRepository implements MeasurementsRepository {
  List<Measurement> items = [testMeasurementItem];
  MeasurementProgress progress = testMeasurementProgress;
  Measurement? created;
  Object? loadError;
  Object? progressError;
  Object? createError;
  Completer<void>? loadGate;
  var loadCalls = 0;
  var createCalls = 0;
  var progressCalls = 0;

  @override
  Future<MeasurementsData> loadMeasurements() async {
    loadCalls++;
    await loadGate?.future;
    if (loadError != null) throw loadError!;

    Object? localProgressError;
    MeasurementProgress? localProgress;
    try {
      progressCalls++;
      if (progressError != null) throw progressError!;
      localProgress = progress;
    } catch (error) {
      if (error is UnauthorizedException) {
        rethrow;
      }
      localProgressError = error;
    }

    return MeasurementsData(
      items: items,
      progress: localProgress,
      progressError: localProgressError == null
          ? null
          : localProgressError is ApiException
              ? localProgressError.message
              : 'Progress summary could not be loaded. Try again.',
    );
  }

  @override
  Future<Measurement> createMeasurement(
      CreateMeasurementRequest request) async {
    createCalls++;
    if (createError != null) throw createError!;
    created = Measurement(
      id: '22222222-2222-2222-2222-222222222222',
      date: request.date,
      weight: request.weight,
      waist: request.waist,
      bodyFatEstimate: request.bodyFatEstimate,
      notes: request.notes,
    );
    return created!;
  }

  @override
  Future<MeasurementProgress> loadProgress() async {
    progressCalls++;
    if (progressError != null) throw progressError!;
    return progress;
  }
}
