import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fittrack_ai/core/network/api_client.dart';
import 'package:fittrack_ai/features/dashboard/data/dashboard_api.dart';
import 'package:fittrack_ai/features/dashboard/data/dashboard_repository.dart';
import 'package:fittrack_ai/features/dashboard/data/models/dashboard_data.dart';
import 'package:fittrack_ai/features/measurements/data/measurements_api.dart';
import 'package:fittrack_ai/features/measurements/data/models/measurement_progress.dart';
import 'package:fittrack_ai/features/weekly_summary/data/models/weekly_recommendation.dart';
import 'package:fittrack_ai/features/weekly_summary/data/models/weekly_summary.dart';
import 'package:fittrack_ai/features/weekly_summary/data/weekly_summary_api.dart';

import 'weekly_summary_fixtures.dart';

final testMeasurement = MeasurementProgress(
  measurementsCount: 2,
  startDate: DateTime(2026, 6, 1),
  endDate: DateTime(2026, 7, 10),
  startWeight: 70,
  endWeight: 68.5,
  weightChange: -1.5,
  endWaist: 81,
  endBodyFatEstimate: 23.5,
);

final testRecommendation = testWeeklyRecommendation;

final testDashboardData = DashboardData(
  weeklySummary: testWeeklySummary,
  measurement: testMeasurement,
  recommendation: testRecommendation,
);

class FakeDashboardApi extends DashboardApi {
  FakeDashboardApi._(
      this.fakeWeeklyApi, this.fakeMeasurements, this._coordinator)
      : super(fakeWeeklyApi, fakeMeasurements);

  factory FakeDashboardApi() {
    final coordinator = RequestCoordinator();
    final measurements = FakeMeasurementsApiForDashboard(coordinator);
    final weeklyApi = FakeWeeklySummaryApiForDashboard(coordinator);
    return FakeDashboardApi._(weeklyApi, measurements, coordinator);
  }

  final FakeWeeklySummaryApiForDashboard fakeWeeklyApi;
  final FakeMeasurementsApiForDashboard fakeMeasurements;
  final RequestCoordinator _coordinator;

  WeeklySummary get weeklySummary => fakeWeeklyApi.weeklySummary;
  set weeklySummary(WeeklySummary value) => fakeWeeklyApi.weeklySummary = value;

  RecommendationSummary? get recommendation =>
      fakeWeeklyApi.latestRecommendation;
  set recommendation(RecommendationSummary? value) =>
      fakeWeeklyApi.latestRecommendation = value;

  Object? get weeklyError => fakeWeeklyApi.weeklyError;
  set weeklyError(Object? value) => fakeWeeklyApi.weeklyError = value;

  Object? get recommendationError => fakeWeeklyApi.latestError;
  set recommendationError(Object? value) => fakeWeeklyApi.latestError = value;

  Completer<void>? get requestGate => _coordinator.gate;
  set requestGate(Completer<void>? value) => _coordinator.gate = value;

  int get maxActiveRequests => _coordinator.maxActive;

  Object? get measurementError => fakeMeasurements.progressError;
  set measurementError(Object? value) => fakeMeasurements.progressError = value;

  MeasurementProgress get measurement => fakeMeasurements.progress;
  set measurement(MeasurementProgress value) =>
      fakeMeasurements.progress = value;
}

class FakeWeeklySummaryApiForDashboard extends WeeklySummaryApi {
  FakeWeeklySummaryApiForDashboard(this._coordinator)
      : super(_UnusedApiClient());

  final RequestCoordinator _coordinator;

  WeeklySummary weeklySummary = testWeeklySummary;
  RecommendationSummary? latestRecommendation = testWeeklyRecommendation;
  Object? weeklyError;
  Object? latestError;

  @override
  Future<WeeklySummary> getWeeklySummary(DateTime weekStart) {
    return _coordinator.run(() {
      if (weeklyError != null) throw weeklyError!;
      return weeklySummary;
    });
  }

  @override
  Future<RecommendationSummary?> getLatestRecommendation() {
    return _coordinator.run(() {
      if (latestError != null) throw latestError!;
      return latestRecommendation;
    });
  }
}

class FakeMeasurementsApiForDashboard extends MeasurementsApi {
  FakeMeasurementsApiForDashboard(this._coordinator)
      : super(_UnusedApiClient());

  final RequestCoordinator _coordinator;

  MeasurementProgress progress = testMeasurement;
  Object? progressError;

  @override
  Future<MeasurementProgress> getProgress({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) {
    return _coordinator.run(() {
      if (progressError != null) throw progressError!;
      return progress;
    });
  }
}

class RequestCoordinator {
  Completer<void>? gate;
  var active = 0;
  var maxActive = 0;

  Future<T> run<T>(T Function() action) async {
    active++;
    if (active > maxActive) {
      maxActive = active;
    }
    await gate?.future;
    try {
      return action();
    } finally {
      active--;
    }
  }
}

class _UnusedApiClient extends ApiClient {
  _UnusedApiClient() : super(Dio());
}

class FakeDashboardRepository implements DashboardRepository {
  DashboardData data = testDashboardData;
  MeasurementProgress measurement = testMeasurement;
  RecommendationSummary? recommendation = testRecommendation;
  Object? loadError;
  Object? measurementError;
  Object? recommendationError;
  Completer<void>? loadGate;
  var loadCalls = 0;
  var measurementCalls = 0;
  var recommendationCalls = 0;

  @override
  Future<DashboardData> loadDashboard() async {
    loadCalls++;
    await loadGate?.future;
    if (loadError != null) throw loadError!;
    return data;
  }

  @override
  Future<MeasurementProgress> loadMeasurement() async {
    measurementCalls++;
    if (measurementError != null) throw measurementError!;
    return measurement;
  }

  @override
  Future<RecommendationSummary?> loadRecommendation() async {
    recommendationCalls++;
    if (recommendationError != null) throw recommendationError!;
    return recommendation;
  }
}
