import 'dart:async';

import 'package:fittrack_ai/core/errors/api_exception.dart';
import 'package:fittrack_ai/features/nutrition/data/models/create_nutrition_log_request.dart';
import 'package:fittrack_ai/features/nutrition/data/nutrition_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_nutrition.dart';

void main() {
  late FakeNutritionApi api;
  late NutritionRepositoryImpl repository;

  setUp(() {
    api = FakeNutritionApi();
    repository = NutritionRepositoryImpl(
      api: api,
      now: () => DateTime(2026, 7, 15),
    );
  });

  test('loads list and summary together', () async {
    final data = await repository.loadNutrition();

    expect(data.logs, hasLength(1));
    expect(data.summary?.daysLogged, 2);
    expect(data.summaryError, isNull);
  });

  test('empty list is valid with summary', () async {
    api.items = [];

    final data = await repository.loadNutrition();

    expect(data.isEmpty, isTrue);
    expect(data.summary, isNotNull);
  });

  test('summary failure is localized', () async {
    api.summaryError = const ServerException();

    final data = await repository.loadNutrition();

    expect(data.logs, hasLength(1));
    expect(data.summary, isNull);
    expect(data.summaryError, isNotNull);
  });

  test('list failure is global', () async {
    api.listError = const NetworkException();

    expect(repository.loadNutrition(), throwsA(isA<NetworkException>()));
  });

  test('create success returns nutrition log', () async {
    final created = await repository.createNutritionLog(
      CreateNutritionLogRequest(
        date: DateTime(2026, 7, 10),
        calories: 2100,
        protein: 130,
        carbs: 250,
        fats: 65,
      ),
    );

    expect(created.calories, 2100);
    expect(api.createCalls, 1);
  });

  test('create conflict propagates', () async {
    api.createError = const ConflictException(
      'Nutrition log already exists for this date',
    );

    expect(
      repository.createNutritionLog(
        CreateNutritionLogRequest(
          date: DateTime(2026, 7, 10),
          calories: 2100,
          protein: 130,
          carbs: 250,
          fats: 65,
        ),
      ),
      throwsA(isA<ConflictException>()),
    );
  });

  test('starts list and summary in parallel', () async {
    api.requestGate = Completer<void>();

    final load = repository.loadNutrition();
    await Future<void>.delayed(Duration.zero);

    expect(api.maxActiveRequests, 2);
    api.requestGate!.complete();
    await load;
  });

  test('uses rolling 30-day list filter and current week summary', () async {
    await repository.loadNutrition();

    expect(api.lastListFrom, DateTime(2026, 6, 16));
    expect(api.lastSummaryFrom, DateTime(2026, 7, 13));
    expect(api.lastSummaryTo, DateTime(2026, 7, 19));
  });

  test('unauthorized list request is global', () async {
    api.listError = const UnauthorizedException();

    expect(
      repository.loadNutrition(),
      throwsA(isA<UnauthorizedException>()),
    );
  });

  test('unauthorized summary request is global', () async {
    api.summaryError = const UnauthorizedException();

    expect(
      repository.loadNutrition(),
      throwsA(isA<UnauthorizedException>()),
    );
  });

  test('loadSummary delegates to api with current week', () async {
    final summary = await repository.loadSummary();

    expect(summary.daysLogged, 2);
    expect(api.summaryCalls, 1);
    expect(api.lastSummaryFrom, DateTime(2026, 7, 13));
    expect(api.lastSummaryTo, DateTime(2026, 7, 19));
  });
}
