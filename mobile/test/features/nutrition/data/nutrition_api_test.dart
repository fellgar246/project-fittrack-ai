import 'package:dio/dio.dart';
import 'package:fittrack_ai/core/errors/api_exception.dart';
import 'package:fittrack_ai/core/network/api_client.dart';
import 'package:fittrack_ai/core/network/api_endpoints.dart';
import 'package:fittrack_ai/features/nutrition/data/models/create_nutrition_log_request.dart';
import 'package:fittrack_ai/features/nutrition/data/nutrition_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _FakeApiClient client;
  late NutritionApi api;

  setUp(() {
    client = _FakeApiClient();
    api = NutritionApi(client);
  });

  test('list success parses nutrition logs', () async {
    client.responses[ApiEndpoints.nutritionLogs] = [_logJson];

    final items = await api.getNutritionLogs();

    expect(items, hasLength(1));
    expect(items.first.calories, 1850);
  });

  test('empty list is valid', () async {
    client.responses[ApiEndpoints.nutritionLogs] = <dynamic>[];

    expect(await api.getNutritionLogs(), isEmpty);
  });

  test('create returns 201 payload', () async {
    client.postResponses[ApiEndpoints.nutritionLogs] = _logJson;

    final created = await api.createNutritionLog(
      CreateNutritionLogRequest(
        date: DateTime(2026, 7, 3),
        calories: 1850,
        protein: 105.5,
        carbs: 210,
        fats: 55,
      ),
    );

    expect(created.id, isNotEmpty);
    expect(client.lastPostBody?['calories'], 1850);
    expect(client.lastPostBody?['fats'], 55);
  });

  test('summary success parses aggregates', () async {
    client.responses[ApiEndpoints.nutritionSummary] = _summaryJson;

    final summary = await api.getNutritionSummary();

    expect(summary.daysLogged, 2);
    expect(summary.totalCalories, 3700);
  });

  test('passes date filters to list', () async {
    client.responses[ApiEndpoints.nutritionLogs] = [];

    await api.getNutritionLogs(
      dateFrom: DateTime(2026, 6, 15),
      dateTo: DateTime(2026, 7, 15),
    );

    expect(client.lastQuery?['date_from'], '2026-06-15');
    expect(client.lastQuery?['date_to'], '2026-07-15');
  });

  test('401 is propagated', () async {
    client.errors[ApiEndpoints.nutritionLogs] = const UnauthorizedException();

    expect(api.getNutritionLogs(), throwsA(isA<UnauthorizedException>()));
  });

  test('422 is propagated', () async {
    client.postErrors[ApiEndpoints.nutritionLogs] = const ValidationException(
      'calories: Input should be greater than or equal to 0',
    );

    expect(
      api.createNutritionLog(
        CreateNutritionLogRequest(
          date: DateTime(2026, 7, 3),
          calories: -1,
          protein: 100,
          carbs: 200,
          fats: 50,
        ),
      ),
      throwsA(isA<ValidationException>()),
    );
  });

  test('409 is propagated', () async {
    client.postErrors[ApiEndpoints.nutritionLogs] = const ConflictException(
      'Nutrition log already exists for this date',
    );

    expect(
      api.createNutritionLog(
        CreateNutritionLogRequest(
          date: DateTime(2026, 7, 3),
          calories: 1850,
          protein: 100,
          carbs: 200,
          fats: 50,
        ),
      ),
      throwsA(isA<ConflictException>()),
    );
  });

  test('500 is propagated', () async {
    client.errors[ApiEndpoints.nutritionSummary] = const ServerException();

    expect(api.getNutritionSummary(), throwsA(isA<ServerException>()));
  });

  test('malformed list payload throws format exception', () async {
    client.responses[ApiEndpoints.nutritionLogs] = [
      {'id': 1},
    ];

    expect(api.getNutritionLogs(), throwsA(isA<FormatException>()));
  });
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(Dio());

  final responses = <String, Object?>{};
  final errors = <String, Object>{};
  final postResponses = <String, Object?>{};
  final postErrors = <String, Object>{};
  Map<String, dynamic>? lastPostBody;
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

final _logJson = <String, dynamic>{
  'id': '11111111-1111-1111-1111-111111111111',
  'date': '2026-07-03',
  'calories': 1850,
  'protein': 105.5,
  'carbs': 210,
  'fats': 55,
  'notes': 'Good protein intake.',
};

final _summaryJson = <String, dynamic>{
  'days_logged': 2,
  'avg_calories': 1850,
  'avg_protein': 105,
  'avg_carbs': 205,
  'avg_fats': 55,
  'total_calories': 3700,
  'total_protein': 210,
  'total_carbs': 410,
  'total_fats': 110,
};
