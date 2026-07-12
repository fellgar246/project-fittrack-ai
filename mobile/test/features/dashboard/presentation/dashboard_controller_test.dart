import 'dart:async';

import 'package:fittrack_ai/core/errors/api_exception.dart';
import 'package:fittrack_ai/features/dashboard/data/models/dashboard_data.dart';
import 'package:fittrack_ai/features/dashboard/presentation/dashboard_controller.dart';
import 'package:fittrack_ai/features/dashboard/presentation/dashboard_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_dashboard.dart';

void main() {
  late FakeDashboardRepository repository;
  late DashboardController controller;
  late int unauthorizedCalls;

  setUp(() {
    repository = FakeDashboardRepository();
    unauthorizedCalls = 0;
    controller = DashboardController(
      repository,
      onUnauthorized: () async => unauthorizedCalls++,
    );
  });

  tearDown(() => controller.dispose());

  test('initial transitions through loading to loaded', () async {
    repository.loadGate = Completer<void>();

    final load = controller.load();
    expect(controller.state.status, DashboardStatus.loading);

    repository.loadGate!.complete();
    await load;

    expect(controller.state.status, DashboardStatus.loaded);
    expect(controller.state.data?.weeklySummary.workoutLogs, 2);
  });

  test('initial failure exposes global retry state', () async {
    repository.loadError = const NetworkException();

    await controller.load();

    expect(controller.state.status, DashboardStatus.failure);
    expect(controller.state.errorMessage, contains('Connection failed'));
  });

  test('refresh preserves loaded data after temporary failure', () async {
    await controller.load();
    final previous = controller.state.data;
    repository.loadError = const ServerException();

    await controller.refresh();

    expect(controller.state.status, DashboardStatus.loaded);
    expect(controller.state.data, same(previous));
    expect(controller.state.errorMessage, isNotNull);
    expect(controller.state.isRefreshing, isFalse);
  });

  test('refresh replaces data after success', () async {
    await controller.load();
    repository.data = DashboardData(
      weeklySummary: testWeeklySummary,
      measurement: testMeasurement,
      recommendation: null,
    );

    await controller.refresh();

    expect(controller.state.data?.recommendation, isNull);
    expect(repository.loadCalls, 2);
  });

  test('localized recommendation retry clears partial error', () async {
    repository.data = DashboardData(
      weeklySummary: testWeeklySummary,
      measurement: testMeasurement,
      recommendationError: 'Unavailable',
    );
    await controller.load();

    await controller.retryRecommendation();

    expect(controller.state.data?.recommendation, testRecommendation);
    expect(controller.state.data?.recommendationError, isNull);
  });

  test('401 invalidates the existing auth session', () async {
    repository.loadError = const UnauthorizedException();

    await controller.load();

    expect(unauthorizedCalls, 1);
  });
}
