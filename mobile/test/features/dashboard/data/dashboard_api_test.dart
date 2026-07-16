import 'package:dio/dio.dart';
import 'package:fittrack_ai/core/errors/api_exception.dart';
import 'package:fittrack_ai/core/network/api_client.dart';
import 'package:fittrack_ai/core/network/api_endpoints.dart';
import 'package:fittrack_ai/features/dashboard/data/dashboard_api.dart';
import 'package:fittrack_ai/features/measurements/data/measurements_api.dart';
import 'package:fittrack_ai/features/weekly_summary/data/weekly_summary_api.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/weekly_summary_fixtures.dart';

void main() {
  late _FakeApiClient client;
  late DashboardApi api;

  setUp(() {
    client = _FakeApiClient();
    api = DashboardApi(WeeklySummaryApi(client), MeasurementsApi(client));
  });

  test('parses weekly summary and sends week_start', () async {
    client.responses[ApiEndpoints.weeklySummary] = fullWeeklySummaryJson();

    final summary = await api.getWeeklySummary(DateTime(2026, 7, 6));

    expect(summary.workoutLogs, 2);
    expect(client.lastQuery?['week_start'], '2026-07-06');
  });

  test('latest recommendation 404 is valid absence', () async {
    client.errors[ApiEndpoints.latestRecommendation] =
        const NotFoundException();

    expect(await api.getLatestRecommendation(), isNull);
  });

  test('500 is propagated', () async {
    client.errors[ApiEndpoints.weeklySummary] = const ServerException();

    expect(
      api.getWeeklySummary(DateTime(2026, 7, 6)),
      throwsA(isA<ServerException>()),
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
