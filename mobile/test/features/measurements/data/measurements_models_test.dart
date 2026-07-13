import 'package:fittrack_ai/features/measurements/data/models/create_measurement_request.dart';
import 'package:fittrack_ai/features/measurements/data/models/measurement.dart';
import 'package:fittrack_ai/features/measurements/data/models/measurement_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses measurement with nullable fields', () {
    final measurement = Measurement.fromJson({
      'id': '11111111-1111-1111-1111-111111111111',
      'date': '2026-07-03',
      'weight': 70.2,
      'waist': 82.5,
      'body_fat_estimate': 24.5,
      'notes': 'Morning measurement',
    });

    expect(measurement.weight, 70.2);
    expect(measurement.waist, 82.5);
    expect(measurement.bodyFatEstimate, 24.5);
    expect(measurement.notes, 'Morning measurement');
  });

  test('parses measurement with null optional fields', () {
    final measurement = Measurement.fromJson({
      'id': '11111111-1111-1111-1111-111111111111',
      'date': '2026-07-03',
      'weight': 70,
      'waist': null,
      'body_fat_estimate': null,
      'notes': null,
    });

    expect(measurement.waist, isNull);
    expect(measurement.bodyFatEstimate, isNull);
    expect(measurement.notes, isNull);
  });

  test('parses int and double numeric values', () {
    final measurement = Measurement.fromJson({
      'id': '11111111-1111-1111-1111-111111111111',
      'date': '2026-07-03',
      'weight': 70,
      'waist': 82,
      'body_fat_estimate': 24,
      'notes': null,
    });

    expect(measurement.weight, 70.0);
    expect(measurement.waist, 82.0);
    expect(measurement.bodyFatEstimate, 24.0);
  });

  test('rejects invalid measurement payload', () {
    expect(
      () => Measurement.fromJson({
        'id': '11111111-1111-1111-1111-111111111111',
        'date': '2026-07-03',
        'weight': 'heavy',
        'waist': null,
        'body_fat_estimate': null,
        'notes': null,
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('serializes create request omitting empty optional fields', () {
    final request = CreateMeasurementRequest(
      date: DateTime(2026, 7, 3),
      weight: 70.2,
    );

    expect(request.toJson(), {
      'date': '2026-07-03',
      'weight': 70.2,
    });
  });

  test('serializes create request with optional fields', () {
    final request = CreateMeasurementRequest(
      date: DateTime(2026, 7, 3),
      weight: 70.2,
      waist: 82.5,
      bodyFatEstimate: 24.5,
      notes: 'Demo note',
    );

    expect(request.toJson(), {
      'date': '2026-07-03',
      'weight': 70.2,
      'waist': 82.5,
      'body_fat_estimate': 24.5,
      'notes': 'Demo note',
    });
  });

  test('parses progress and empty state', () {
    final progress = MeasurementProgress.fromJson({
      'measurements_count': 2,
      'start_date': '2026-07-01',
      'end_date': '2026-07-31',
      'start_weight': 71,
      'end_weight': 70.2,
      'weight_change': -0.8,
      'start_waist': null,
      'end_waist': null,
      'waist_change': null,
      'start_body_fat_estimate': null,
      'end_body_fat_estimate': null,
      'body_fat_change': null,
    });

    expect(progress.measurementsCount, 2);
    expect(progress.hasTrend, isTrue);
    expect(progress.waistChange, isNull);
  });

  test('parses controlled empty progress response', () {
    final progress = MeasurementProgress.fromJson({
      'measurements_count': 0,
      'start_date': null,
      'end_date': null,
      'start_weight': null,
      'end_weight': null,
      'weight_change': null,
      'start_waist': null,
      'end_waist': null,
      'waist_change': null,
      'start_body_fat_estimate': null,
      'end_body_fat_estimate': null,
      'body_fat_change': null,
    });

    expect(progress.isEmpty, isTrue);
    expect(progress.hasTrend, isFalse);
  });
}
