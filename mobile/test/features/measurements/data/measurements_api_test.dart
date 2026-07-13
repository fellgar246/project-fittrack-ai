import 'package:dio/dio.dart';
import 'package:fittrack_ai/core/errors/api_exception.dart';
import 'package:fittrack_ai/core/network/api_client.dart';
import 'package:fittrack_ai/core/network/api_endpoints.dart';
import 'package:fittrack_ai/features/measurements/data/measurements_api.dart';
import 'package:fittrack_ai/features/measurements/data/models/create_measurement_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _FakeApiClient client;
  late MeasurementsApi api;

  setUp(() {
    client = _FakeApiClient();
    api = MeasurementsApi(client);
  });

  test('list success parses measurements', () async {
    client.responses[ApiEndpoints.measurements] = [_measurementJson];

    final items = await api.getMeasurements();

    expect(items, hasLength(1));
    expect(items.first.weight, 70.2);
  });

  test('empty list is valid', () async {
    client.responses[ApiEndpoints.measurements] = <dynamic>[];

    expect(await api.getMeasurements(), isEmpty);
  });

  test('create returns 201 payload', () async {
    client.postResponses[ApiEndpoints.measurements] = _measurementJson;

    final created = await api.createMeasurement(
      CreateMeasurementRequest(
        date: DateTime(2026, 7, 3),
        weight: 70.2,
        waist: 82.5,
      ),
    );

    expect(created.id, isNotEmpty);
    expect(client.lastPostBody?['weight'], 70.2);
  });

  test('progress success parses summary', () async {
    client.responses[ApiEndpoints.measurementProgress] = _progressJson;

    final progress = await api.getProgress();

    expect(progress.measurementsCount, 2);
    expect(progress.weightChange, -0.8);
  });

  test('401 is propagated', () async {
    client.errors[ApiEndpoints.measurements] = const UnauthorizedException();

    expect(api.getMeasurements(), throwsA(isA<UnauthorizedException>()));
  });

  test('422 is propagated', () async {
    client.postErrors[ApiEndpoints.measurements] = const ValidationException(
      'weight: Input should be greater than 0',
    );

    expect(
      api.createMeasurement(
        CreateMeasurementRequest(
          date: DateTime(2026, 7, 3),
          weight: 0,
        ),
      ),
      throwsA(isA<ValidationException>()),
    );
  });

  test('409 is propagated', () async {
    client.postErrors[ApiEndpoints.measurements] = const ConflictException(
      'Body measurement already exists for this date',
    );

    expect(
      api.createMeasurement(
        CreateMeasurementRequest(
          date: DateTime(2026, 7, 3),
          weight: 70.2,
        ),
      ),
      throwsA(isA<ConflictException>()),
    );
  });

  test('500 is propagated', () async {
    client.errors[ApiEndpoints.measurementProgress] = const ServerException();

    expect(api.getProgress(), throwsA(isA<ServerException>()));
  });

  test('malformed list payload throws format exception', () async {
    client.responses[ApiEndpoints.measurements] = [
      {'id': 1},
    ];

    expect(api.getMeasurements(), throwsA(isA<FormatException>()));
  });
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(Dio());

  final responses = <String, Object?>{};
  final errors = <String, Object>{};
  final postResponses = <String, Object?>{};
  final postErrors = <String, Object>{};
  Map<String, dynamic>? lastPostBody;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    final error = errors[path];
    if (error != null) throw error;
    return Response<T>(
      data: responses[path] as T,
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
    );
  }

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    lastPostBody = data as Map<String, dynamic>?;
    final error = postErrors[path];
    if (error != null) throw error;
    return Response<T>(
      data: postResponses[path] as T,
      requestOptions: RequestOptions(path: path),
      statusCode: 201,
    );
  }
}

final _measurementJson = <String, dynamic>{
  'id': '11111111-1111-1111-1111-111111111111',
  'date': '2026-07-03',
  'weight': 70.2,
  'waist': 82.5,
  'body_fat_estimate': 24.5,
  'notes': 'Morning measurement',
};

final _progressJson = <String, dynamic>{
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
};
