import 'dart:async';

import 'package:fittrack_ai/core/errors/api_exception.dart';
import 'package:fittrack_ai/features/weekly_summary/data/models/weekly_recommendation.dart';
import 'package:fittrack_ai/features/weekly_summary/presentation/recommendation_generation_controller.dart';
import 'package:fittrack_ai/features/weekly_summary/presentation/weekly_summary_controller.dart';
import 'package:fittrack_ai/features/weekly_summary/presentation/weekly_summary_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_weekly_summary.dart';
import '../../../helpers/weekly_summary_fixtures.dart';

void main() {
  group('WeeklySummaryController', () {
    test('initial load transitions to loaded', () async {
      final repository = FakeWeeklySummaryRepository();
      final controller = WeeklySummaryController(
        repository,
        onUnauthorized: () async {},
      );

      await controller.load();

      expect(controller.state.status, WeeklySummaryStatus.loaded);
      expect(controller.state.data?.summary.workoutLogs, 2);
    });

    test('refresh preserves stale data on failure', () async {
      final repository = FakeWeeklySummaryRepository();
      final controller = WeeklySummaryController(
        repository,
        onUnauthorized: () async {},
      );
      await controller.load();
      repository.loadError = const ServerException();

      await controller.refresh();

      expect(controller.state.status, WeeklySummaryStatus.loaded);
      expect(controller.state.data, isNotNull);
      expect(controller.state.errorMessage, isNotNull);
    });

    test('401 triggers logout callback', () async {
      var loggedOut = false;
      final repository = FakeWeeklySummaryRepository()
        ..loadError = const UnauthorizedException();
      final controller = WeeklySummaryController(
        repository,
        onUnauthorized: () async => loggedOut = true,
      );

      await controller.load();

      expect(loggedOut, isTrue);
    });
  });

  group('RecommendationGenerationController', () {
    late FakeWeeklySummaryRepository repository;
    late WeeklySummaryController weeklyController;
    late RecommendationGenerationController controller;

    setUp(() async {
      repository = FakeWeeklySummaryRepository();
      weeklyController = WeeklySummaryController(
        repository,
        onUnauthorized: () async {},
      );
      await weeklyController.load();
      controller = RecommendationGenerationController(
        repository,
        weeklySummaryController: weeklyController,
        onUnauthorized: () async {},
      );
    });

    test('double submit is ignored', () async {
      repository.generateGate = Completer<void>();
      final first = controller.generate(DateTime(2026, 7, 6));
      final second = controller.generate(DateTime(2026, 7, 6));

      expect(controller.state.isSubmitting, isTrue);
      repository.generateGate!.complete();
      await first;
      await second;

      expect(repository.generateCalls, 1);
    });

    test('success updates weekly recommendation', () async {
      final generated = testWeeklyRecommendation.copyWith(
        summary: 'Fresh guidance',
      );
      repository.generateResult = generated;

      await controller.generate(DateTime(2026, 7, 6));

      expect(controller.state.status, RecommendationGenerationStatus.success);
      expect(
        weeklyController.state.data?.latestRecommendation?.summary,
        'Fresh guidance',
      );
    });

    test('timeout checks persisted recommendation', () async {
      repository.generateError = const TimeoutApiException();
      repository.latestRecommendation = WeeklyRecommendation(
        id: 'recommendation-id',
        weekStart: DateTime(2026, 7, 6),
        weekEnd: DateTime(2026, 7, 12),
        summary: 'Persisted after timeout',
        insights: const [],
        recommendation: 'Keep going.',
      );

      await controller.generate(DateTime(2026, 7, 6));

      expect(controller.state.status, RecommendationGenerationStatus.success);
    });

    test('502 maps to provider failure message', () async {
      repository.generateError =
          const ServerException('AI provider failed', 502);

      await controller.generate(DateTime(2026, 7, 6));

      expect(controller.state.status, RecommendationGenerationStatus.failure);
      expect(
        controller.state.errorMessage,
        'The AI recommendation service could not complete the request.',
      );
    });
  });
}

extension on WeeklyRecommendation {
  WeeklyRecommendation copyWith({String? summary}) {
    return WeeklyRecommendation(
      id: id,
      weekStart: weekStart,
      weekEnd: weekEnd,
      summary: summary ?? this.summary,
      insights: insights,
      recommendation: recommendation,
      safetyNotes: safetyNotes,
    );
  }
}
