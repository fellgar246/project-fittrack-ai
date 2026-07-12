import 'dart:async';

import 'package:fittrack_ai/core/errors/api_exception.dart';
import 'package:fittrack_ai/features/dashboard/data/dashboard_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_dashboard.dart';

void main() {
  late FakeDashboardApi api;
  late DashboardRepositoryImpl repository;

  setUp(() {
    api = FakeDashboardApi();
    repository = DashboardRepositoryImpl(
      api: api,
      now: () => DateTime(2026, 7, 12),
    );
  });

  test('loads all dashboard sections', () async {
    final data = await repository.loadDashboard();

    expect(data.weeklySummary.workoutLogs, 2);
    expect(data.measurement?.endWeight, 68.5);
    expect(data.recommendation?.summary, 'Recovery is on track.');
    expect(data.isPartial, isFalse);
  });

  test('starts independent requests in parallel', () async {
    api.requestGate = Completer<void>();

    final load = repository.loadDashboard();
    await Future<void>.delayed(Duration.zero);

    expect(api.maxActiveRequests, 3);
    api.requestGate!.complete();
    await load;
  });

  test('keeps successful data when optional section fails', () async {
    api.recommendationError = const ServerException();

    final data = await repository.loadDashboard();

    expect(data.weeklySummary.workoutLogs, 2);
    expect(data.measurement, isNotNull);
    expect(data.recommendation, isNull);
    expect(data.recommendationError, isNotNull);
    expect(data.isPartial, isTrue);
  });

  test('represents absent recommendation without an error', () async {
    api.recommendation = null;

    final data = await repository.loadDashboard();

    expect(data.recommendation, isNull);
    expect(data.recommendationError, isNull);
  });

  test('weekly summary failure is global', () async {
    api.weeklyError = const ServerException();

    expect(repository.loadDashboard(), throwsA(isA<ServerException>()));
  });

  test('unauthorized optional request is global', () async {
    api.measurementError = const UnauthorizedException();

    expect(repository.loadDashboard(), throwsA(isA<UnauthorizedException>()));
  });
}
