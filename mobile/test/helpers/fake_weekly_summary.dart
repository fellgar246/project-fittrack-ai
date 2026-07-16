import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fittrack_ai/core/network/api_client.dart';
import 'package:fittrack_ai/features/weekly_summary/data/models/generate_recommendation_request.dart';
import 'package:fittrack_ai/features/weekly_summary/data/models/weekly_recommendation.dart';
import 'package:fittrack_ai/features/weekly_summary/data/models/weekly_summary.dart';
import 'package:fittrack_ai/features/weekly_summary/data/models/weekly_summary_data.dart';
import 'package:fittrack_ai/features/weekly_summary/data/weekly_summary_api.dart';
import 'package:fittrack_ai/features/weekly_summary/data/weekly_summary_repository.dart';

import 'weekly_summary_fixtures.dart';

class FakeWeeklySummaryApi extends WeeklySummaryApi {
  FakeWeeklySummaryApi._(this._coordinator) : super(_UnusedApiClient());

  factory FakeWeeklySummaryApi() {
    return FakeWeeklySummaryApi._(RequestCoordinator());
  }

  final RequestCoordinator _coordinator;

  WeeklySummary weeklySummary = testWeeklySummary;
  WeeklyRecommendation? latestRecommendation = testWeeklyRecommendation;
  WeeklyRecommendation? generateResult;
  Object? weeklyError;
  Object? latestError;
  Object? generateError;
  var generateCalls = 0;
  var latestCalls = 0;
  var weeklyCalls = 0;
  DateTime? lastGenerateWeekStart;

  Completer<void>? get requestGate => _coordinator.gate;
  set requestGate(Completer<void>? value) => _coordinator.gate = value;

  int get maxActiveRequests => _coordinator.maxActive;

  @override
  Future<WeeklySummary> getWeeklySummary(DateTime weekStart) {
    weeklyCalls++;
    return _coordinator.run(() {
      if (weeklyError != null) throw weeklyError!;
      return weeklySummary;
    });
  }

  @override
  Future<WeeklyRecommendation?> getLatestRecommendation() {
    latestCalls++;
    return _coordinator.run(() {
      if (latestError != null) throw latestError!;
      return latestRecommendation;
    });
  }

  @override
  Future<WeeklyRecommendation> generateRecommendation(
    GenerateRecommendationRequest request,
  ) {
    generateCalls++;
    lastGenerateWeekStart = request.weekStart;
    return _coordinator.run(() {
      if (generateError != null) throw generateError!;
      return generateResult ?? testWeeklyRecommendation;
    });
  }
}

class FakeWeeklySummaryRepository implements WeeklySummaryRepository {
  WeeklySummaryData data = testWeeklySummaryData;
  WeeklyRecommendation? latestRecommendation = testWeeklyRecommendation;
  WeeklyRecommendation? generateResult;
  Object? loadError;
  Object? latestError;
  Object? generateError;
  Completer<void>? loadGate;
  Completer<void>? generateGate;
  var loadCalls = 0;
  var latestCalls = 0;
  var generateCalls = 0;
  DateTime currentWeekStartValue = DateTime(2026, 7, 6);

  @override
  DateTime get currentWeekStart => currentWeekStartValue;

  @override
  Future<WeeklySummaryData> loadWeek(DateTime weekStart) async {
    loadCalls++;
    await loadGate?.future;
    if (loadError != null) throw loadError!;
    return data;
  }

  @override
  Future<WeeklyRecommendation> generateRecommendation(
    DateTime weekStart,
  ) async {
    generateCalls++;
    await generateGate?.future;
    if (generateError != null) throw generateError!;
    return generateResult ?? testWeeklyRecommendation;
  }

  @override
  Future<WeeklyRecommendation?> loadLatestRecommendation() async {
    latestCalls++;
    if (latestError != null) throw latestError!;
    return latestRecommendation;
  }
}

class RequestCoordinator {
  Completer<void>? gate;
  var active = 0;
  var maxActive = 0;

  Future<T> run<T>(FutureOr<T> Function() action) async {
    active++;
    if (active > maxActive) {
      maxActive = active;
    }
    await gate?.future;
    try {
      return await action();
    } finally {
      active--;
    }
  }
}

class _UnusedApiClient extends ApiClient {
  _UnusedApiClient() : super(Dio());
}
