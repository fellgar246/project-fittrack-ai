import 'package:dio/dio.dart';
import 'package:fittrack_ai/core/errors/api_exception.dart';
import 'package:fittrack_ai/core/network/api_client.dart';
import 'package:fittrack_ai/core/network/api_endpoints.dart';
import 'package:fittrack_ai/features/workouts/data/models/create_workout_log_request.dart';
import 'package:fittrack_ai/features/workouts/data/workouts_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _FakeApiClient client;
  late WorkoutsApi api;

  setUp(() {
    client = _FakeApiClient();
    api = WorkoutsApi(client);
  });

  test('plans success parses summaries', () async {
    client.responses[ApiEndpoints.workoutPlans] = [_planJson];

    final items = await api.getWorkoutPlans();

    expect(items, hasLength(1));
    expect(items.first.name, 'Strength Builder');
  });

  test('plans empty is valid', () async {
    client.responses[ApiEndpoints.workoutPlans] = <dynamic>[];

    expect(await api.getWorkoutPlans(), isEmpty);
  });

  test('plan detail success parses nested days', () async {
    client.responses[ApiEndpoints.workoutPlanById(testPlanId)] =
        _planDetailJson;

    final detail = await api.getWorkoutPlan(testPlanId);

    expect(detail.days, hasLength(1));
    expect(detail.days.first.exercises.first.name, 'Bench press');
  });

  test('logs success parses workout logs', () async {
    client.responses[ApiEndpoints.workoutLogs] = [_logJson];

    final items = await api.getWorkoutLogs();

    expect(items, hasLength(1));
    expect(items.first.exerciseName, 'Bench press');
  });

  test('logs empty is valid', () async {
    client.responses[ApiEndpoints.workoutLogs] = <dynamic>[];

    expect(await api.getWorkoutLogs(), isEmpty);
  });

  test('create returns 201 payload', () async {
    client.postResponses[ApiEndpoints.workoutLogs] = _logJson;

    final created = await api.createWorkoutLog(
      CreateWorkoutLogRequest(
        exerciseId: testExerciseId,
        performedAt: DateTime(2026, 7, 3, 10, 30),
        sets: 3,
        reps: 10,
        weight: 60,
      ),
    );

    expect(created.id, isNotEmpty);
    expect(client.lastPostBody?['sets'], 3);
    expect(client.lastPostBody?['exercise_id'], testExerciseId);
  });

  test('passes date filters to logs', () async {
    client.responses[ApiEndpoints.workoutLogs] = [];

    await api.getWorkoutLogs(
      dateFrom: DateTime(2026, 6, 15),
      dateTo: DateTime(2026, 7, 15),
    );

    expect(client.lastQuery?['date_from'], '2026-06-15');
    expect(client.lastQuery?['date_to'], '2026-07-15');
  });

  test('401 is propagated', () async {
    client.errors[ApiEndpoints.workoutPlans] = const UnauthorizedException();

    expect(api.getWorkoutPlans(), throwsA(isA<UnauthorizedException>()));
  });

  test('404 is propagated from create', () async {
    client.postErrors[ApiEndpoints.workoutLogs] = const NotFoundException(
      'Exercise not found',
    );

    expect(
      api.createWorkoutLog(
        CreateWorkoutLogRequest(
          exerciseId: testExerciseId,
          performedAt: DateTime(2026, 7, 3, 10, 30),
          sets: 3,
          reps: 10,
        ),
      ),
      throwsA(isA<NotFoundException>()),
    );
  });

  test('422 is propagated', () async {
    client.postErrors[ApiEndpoints.workoutLogs] = const ValidationException(
      'sets: Input should be greater than 0',
    );

    expect(
      api.createWorkoutLog(
        CreateWorkoutLogRequest(
          exerciseId: testExerciseId,
          performedAt: DateTime(2026, 7, 3, 10, 30),
          sets: 0,
          reps: 10,
        ),
      ),
      throwsA(isA<ValidationException>()),
    );
  });

  test('500 is propagated', () async {
    client.errors[ApiEndpoints.workoutLogs] = const ServerException();

    expect(api.getWorkoutLogs(), throwsA(isA<ServerException>()));
  });

  test('malformed list payload throws format exception', () async {
    client.responses[ApiEndpoints.workoutLogs] = [
      {'id': 1},
    ];

    expect(api.getWorkoutLogs(), throwsA(isA<FormatException>()));
  });
}

const testPlanId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
const testExerciseId = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

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

final _planJson = <String, dynamic>{
  'id': testPlanId,
  'name': 'Strength Builder',
  'goal': 'Build muscle',
  'active': true,
  'days_count': 1,
  'exercises_count': 1,
};

final _planDetailJson = <String, dynamic>{
  'id': testPlanId,
  'name': 'Strength Builder',
  'goal': 'Build muscle',
  'active': true,
  'days': [
    {
      'id': 'dddddddd-dddd-dddd-dddd-dddddddddddd',
      'day_of_week': 1,
      'title': 'Push day',
      'exercises': [
        {
          'id': testExerciseId,
          'name': 'Bench press',
          'muscle_group': 'Chest',
          'target_sets': 3,
          'target_reps': '10',
        },
      ],
    },
  ],
};

final _logJson = <String, dynamic>{
  'id': 'cccccccc-cccc-cccc-cccc-cccccccccccc',
  'exercise_id': testExerciseId,
  'exercise_name': 'Bench press',
  'performed_at': '2026-07-03T10:30:00.000',
  'sets': 3,
  'reps': 10,
  'weight': 60,
  'notes': 'Completed demo workout',
};
