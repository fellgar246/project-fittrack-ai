import 'dart:async';

import 'package:fittrack_ai/features/dashboard/data/dashboard_api.dart';
import 'package:fittrack_ai/features/dashboard/data/dashboard_repository.dart';
import 'package:fittrack_ai/features/dashboard/data/models/dashboard_data.dart';
import 'package:fittrack_ai/features/dashboard/data/models/measurement_progress.dart';
import 'package:fittrack_ai/features/dashboard/data/models/recommendation_summary.dart';
import 'package:fittrack_ai/features/dashboard/data/models/weekly_summary.dart';

final testWeeklySummary = WeeklySummary(
  weekStart: DateTime(2026, 7, 6),
  weekEnd: DateTime(2026, 7, 12),
  workoutLogs: 2,
  workoutDays: 2,
  nutritionDaysLogged: 4,
  measurements: testMeasurement,
  isReadyForRecommendation: true,
  missingData: const [],
);

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

final testRecommendation = RecommendationSummary(
  id: 'recommendation-id',
  weekStart: DateTime(2026, 6, 29),
  weekEnd: DateTime(2026, 7, 5),
  summary: 'Recovery is on track.',
  insights: const ['Training consistency improved.'],
  recommendation: 'Maintain calories and prioritise recovery.',
  safetyNotes: 'This does not replace medical advice.',
);

final testDashboardData = DashboardData(
  weeklySummary: testWeeklySummary,
  measurement: testMeasurement,
  recommendation: testRecommendation,
);

class FakeDashboardApi implements DashboardApi {
  WeeklySummary weeklySummary = testWeeklySummary;
  MeasurementProgress measurement = testMeasurement;
  RecommendationSummary? recommendation = testRecommendation;
  Object? weeklyError;
  Object? measurementError;
  Object? recommendationError;
  Completer<void>? requestGate;
  var activeRequests = 0;
  var maxActiveRequests = 0;

  @override
  Future<WeeklySummary> getWeeklySummary(DateTime weekStart) async {
    return _run(() {
      if (weeklyError != null) throw weeklyError!;
      return weeklySummary;
    });
  }

  @override
  Future<MeasurementProgress> getMeasurementProgress() async {
    return _run(() {
      if (measurementError != null) throw measurementError!;
      return measurement;
    });
  }

  @override
  Future<RecommendationSummary?> getLatestRecommendation() async {
    return _run(() {
      if (recommendationError != null) throw recommendationError!;
      return recommendation;
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
