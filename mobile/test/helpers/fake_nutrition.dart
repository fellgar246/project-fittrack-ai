import 'dart:async';

import 'package:fittrack_ai/core/errors/api_exception.dart';
import 'package:fittrack_ai/features/nutrition/data/models/create_nutrition_log_request.dart';
import 'package:fittrack_ai/features/nutrition/data/models/nutrition_data.dart';
import 'package:fittrack_ai/features/nutrition/data/models/nutrition_log.dart';
import 'package:fittrack_ai/features/nutrition/data/models/nutrition_summary.dart';
import 'package:fittrack_ai/features/nutrition/data/nutrition_api.dart';
import 'package:fittrack_ai/features/nutrition/data/nutrition_repository.dart';

final testNutritionLog = NutritionLog(
  id: '11111111-1111-1111-1111-111111111111',
  date: DateTime(2026, 7, 3),
  calories: 1850,
  protein: 105.5,
  carbs: 210,
  fats: 55,
  notes: 'Good protein intake.',
);

const testNutritionSummary = NutritionSummary(
  daysLogged: 2,
  avgCalories: 1850,
  avgProtein: 105,
  avgCarbs: 205,
  avgFats: 55,
  totalCalories: 3700,
  totalProtein: 210,
  totalCarbs: 410,
  totalFats: 110,
);

class FakeNutritionApi implements NutritionApi {
  List<NutritionLog> items = [testNutritionLog];
  NutritionSummary summary = testNutritionSummary;
  NutritionLog? created;
  Object? listError;
  Object? summaryError;
  Object? createError;
  Completer<void>? requestGate;
  var activeRequests = 0;
  var maxActiveRequests = 0;
  var listCalls = 0;
  var summaryCalls = 0;
  var createCalls = 0;
  DateTime? lastListFrom;
  DateTime? lastSummaryFrom;
  DateTime? lastSummaryTo;

  @override
  Future<List<NutritionLog>> getNutritionLogs({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) {
    return _run(() {
      listCalls++;
      lastListFrom = dateFrom;
      if (listError != null) throw listError!;
      return items;
    });
  }

  @override
  Future<NutritionLog> createNutritionLog(CreateNutritionLogRequest request) {
    return _run(() {
      createCalls++;
      if (createError != null) throw createError!;
      created = NutritionLog(
        id: '22222222-2222-2222-2222-222222222222',
        date: request.date,
        calories: request.calories,
        protein: request.protein,
        carbs: request.carbs,
        fats: request.fats,
        notes: request.notes,
      );
      return created!;
    });
  }

  @override
  Future<NutritionSummary> getNutritionSummary({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) {
    return _run(() {
      summaryCalls++;
      lastSummaryFrom = dateFrom;
      lastSummaryTo = dateTo;
      if (summaryError != null) throw summaryError!;
      return summary;
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

class FakeNutritionRepository implements NutritionRepository {
  List<NutritionLog> items = [testNutritionLog];
  NutritionSummary summary = testNutritionSummary;
  NutritionLog? created;
  Object? loadError;
  Object? summaryError;
  Object? createError;
  Completer<void>? loadGate;
  Completer<void>? createGate;
  var loadCalls = 0;
  var createCalls = 0;
  var summaryCalls = 0;

  @override
  Future<NutritionData> loadNutrition() async {
    loadCalls++;
    await loadGate?.future;
    if (loadError != null) throw loadError!;

    Object? localSummaryError;
    NutritionSummary? localSummary;
    try {
      summaryCalls++;
      if (summaryError != null) throw summaryError!;
      localSummary = summary;
    } catch (error) {
      if (error is UnauthorizedException) {
        rethrow;
      }
      localSummaryError = error;
    }

    return NutritionData(
      logs: items,
      summary: localSummary,
      summaryError: localSummaryError == null
          ? null
          : localSummaryError is ApiException
              ? localSummaryError.message
              : 'Nutrition summary could not be loaded. Try again.',
    );
  }

  @override
  Future<NutritionLog> createNutritionLog(
    CreateNutritionLogRequest request,
  ) async {
    createCalls++;
    await createGate?.future;
    if (createError != null) throw createError!;
    created = NutritionLog(
      id: '22222222-2222-2222-2222-222222222222',
      date: request.date,
      calories: request.calories,
      protein: request.protein,
      carbs: request.carbs,
      fats: request.fats,
      notes: request.notes,
    );
    return created!;
  }

  @override
  Future<NutritionSummary> loadSummary() async {
    summaryCalls++;
    if (summaryError != null) throw summaryError!;
    return summary;
  }
}
