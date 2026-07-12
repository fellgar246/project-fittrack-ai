import 'package:dio/dio.dart';
import 'package:fittrack_ai/core/errors/api_exception.dart';
import 'package:fittrack_ai/core/network/api_client.dart';
import 'package:fittrack_ai/core/network/api_endpoints.dart';
import 'package:fittrack_ai/features/dashboard/data/dashboard_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _FakeApiClient client;
  late DashboardApi api;

  setUp(() {
    client = _FakeApiClient();
    api = DashboardApi(client);
  });

  test('parses weekly summary and sends week_start', () async {
    client.responses[ApiEndpoints.weeklySummary] = _weeklyJson;

    final summary = await api.getWeeklySummary(DateTime(2026, 7, 6));

    expect(summary.workoutLogs, 1);
    expect(client.lastQuery?['week_start'], '2026-07-06');
  });

  test('latest recommendation 404 is valid absence', () async {
    client.errors[ApiEndpoints.latestRecommendation] =
        const NotFoundException();

    expect(await api.getLatestRecommendation(), isNull);
  });

  test('401 is propagated', () async {
    client.errors[ApiEndpoints.measurementProgress] =
        const UnauthorizedException();

    expect(
      api.getMeasurementProgress(),
      throwsA(isA<UnauthorizedException>()),
    );
  });

  test('500 is propagated', () async {
    client.errors[ApiEndpoints.weeklySummary] = const ServerException();

    expect(
      api.getWeeklySummary(DateTime(2026, 7, 6)),
      throwsA(isA<ServerException>()),
    );
  });

  test('invalid payload throws format exception', () async {
    client.responses[ApiEndpoints.measurementProgress] = {
      'measurements_count': 'none',
    };

    expect(
      api.getMeasurementProgress(),
      throwsA(isA<FormatException>()),
    );
  });
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(Dio());

  final responses = <String, Object?>{};
  final errors = <String, Object>{};
  Map<String, dynamic>? lastQuery;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    lastQuery = queryParameters;
    final error = errors[path];
    if (error != null) throw error;
    return Response<T>(
      data: responses[path] as T,
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
    );
  }
}

final _weeklyJson = <String, dynamic>{
  'period': {
    'week_start': '2026-07-06',
    'week_end': '2026-07-12',
  },
  'workouts': {
    'total_logs': 1,
    'workout_days': 1,
  },
  'nutrition': {
    'days_logged': 3,
  },
  'measurements': {
    'measurements_count': 1,
    'end_weight': 68.5,
  },
  'data_quality': {
    'is_ready_for_ai_recommendation': true,
    'missing_data': <String>[],
  },
};
