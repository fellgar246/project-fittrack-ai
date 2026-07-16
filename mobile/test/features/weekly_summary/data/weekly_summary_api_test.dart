import 'package:dio/dio.dart';
import 'package:fittrack_ai/core/errors/api_exception.dart';
import 'package:fittrack_ai/core/network/api_client.dart';
import 'package:fittrack_ai/core/network/api_endpoints.dart';
import 'package:fittrack_ai/features/weekly_summary/data/models/generate_recommendation_request.dart';
import 'package:fittrack_ai/features/weekly_summary/data/weekly_summary_api.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/weekly_summary_fixtures.dart';

void main() {
  late _FakeApiClient client;
  late WeeklySummaryApi api;

  setUp(() {
    client = _FakeApiClient();
    api = WeeklySummaryApi(client);
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

  test('generate sends only week_start and uses extended receive timeout',
      () async {
    client.responses[ApiEndpoints.weeklyRecommendation] = recommendationJson();

    final result = await api.generateRecommendation(
      GenerateRecommendationRequest(weekStart: DateTime(2026, 7, 6)),
    );

    expect(result.summary, 'On track');
    expect(client.lastBody, {'week_start': '2026-07-06'});
    expect(
      client.lastOptions?.receiveTimeout,
      recommendationGenerationReceiveTimeout,
    );
  });

  test('maps provider failures', () async {
    client.postErrors[ApiEndpoints.weeklyRecommendation] =
        const ServerException('AI provider failed', 502);

    expect(
      api.generateRecommendation(
        GenerateRecommendationRequest(weekStart: DateTime(2026, 7, 6)),
      ),
      throwsA(isA<ServerException>()),
    );
  });
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(Dio());

  final responses = <String, Object?>{};
  final errors = <String, Object>{};
  final postErrors = <String, Object>{};
  Map<String, dynamic>? lastQuery;
  Map<String, dynamic>? lastBody;
  Options? lastOptions;

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

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    lastBody = data as Map<String, dynamic>?;
    lastOptions = options;
    final error = postErrors[path];
    if (error != null) throw error;
    return Response<T>(
      data: responses[path] as T,
      requestOptions: RequestOptions(path: path),
      statusCode: 201,
    );
  }
}
