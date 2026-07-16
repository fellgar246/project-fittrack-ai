import 'dart:async';

import 'package:fittrack_ai/core/errors/api_exception.dart';
import 'package:fittrack_ai/features/nutrition/data/models/create_nutrition_log_request.dart';
import 'package:fittrack_ai/features/nutrition/presentation/create_nutrition_log_controller.dart';
import 'package:fittrack_ai/features/nutrition/presentation/create_nutrition_log_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_nutrition.dart';

void main() {
  late FakeNutritionRepository repository;
  late CreateNutritionLogController controller;
  late int unauthorizedCalls;

  setUp(() {
    repository = FakeNutritionRepository();
    unauthorizedCalls = 0;
    controller = CreateNutritionLogController(
      repository,
      onUnauthorized: () async => unauthorizedCalls++,
    );
  });

  tearDown(() => controller.dispose());

  test('submit transitions to success', () async {
    final log = await controller.submit(
      CreateNutritionLogRequest(
        date: DateTime(2026, 7, 3),
        calories: 2100,
        protein: 130,
        carbs: 250,
        fats: 65,
      ),
    );

    expect(log, isNotNull);
    expect(controller.state.status, CreateNutritionLogStatus.success);
    expect(repository.createCalls, 1);
  });

  test('submit failure preserves form state', () async {
    repository.createError = const ConflictException(
      'Nutrition log already exists for this date',
    );

    final log = await controller.submit(
      CreateNutritionLogRequest(
        date: DateTime(2026, 7, 3),
        calories: 2100,
        protein: 130,
        carbs: 250,
        fats: 65,
      ),
    );

    expect(log, isNull);
    expect(controller.state.status, CreateNutritionLogStatus.failure);
    expect(
      controller.state.errorMessage,
      'Nutrition log already exists for this date',
    );
  });

  test('prevents duplicate submit', () async {
    repository.createGate = Completer<void>();

    final first = controller.submit(
      CreateNutritionLogRequest(
        date: DateTime(2026, 7, 3),
        calories: 2100,
        protein: 130,
        carbs: 250,
        fats: 65,
      ),
    );
    final second = controller.submit(
      CreateNutritionLogRequest(
        date: DateTime(2026, 7, 3),
        calories: 2100,
        protein: 130,
        carbs: 250,
        fats: 65,
      ),
    );

    repository.createGate!.complete();
    await first;
    await second;

    expect(repository.createCalls, 1);
  });

  test('401 invalidates the existing auth session', () async {
    repository.createError = const UnauthorizedException();

    await controller.submit(
      CreateNutritionLogRequest(
        date: DateTime(2026, 7, 3),
        calories: 2100,
        protein: 130,
        carbs: 250,
        fats: 65,
      ),
    );

    expect(unauthorizedCalls, 1);
  });
}
