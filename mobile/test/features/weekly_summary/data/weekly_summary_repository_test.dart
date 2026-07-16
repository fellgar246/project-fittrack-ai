import 'dart:async';

import 'package:fittrack_ai/core/errors/api_exception.dart';
import 'package:fittrack_ai/features/weekly_summary/data/weekly_summary_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_weekly_summary.dart';
import '../../../helpers/weekly_summary_fixtures.dart';

void main() {
  group('WeeklySummaryRepositoryImpl', () {
    test('loads summary and latest recommendation in parallel', () async {
      final api = FakeWeeklySummaryApi()..requestGate = Completer<void>();
      final repository = WeeklySummaryRepositoryImpl(api: api);

      final future = repository.loadWeek(DateTime(2026, 7, 6));
      await Future<void>.delayed(Duration.zero);
      expect(api.maxActiveRequests, greaterThan(1));
      api.requestGate!.complete();
      final data = await future;

      expect(data.summary.workoutLogs, 2);
      expect(data.latestRecommendation?.summary, 'Recovery is on track.');
    });

    test('latest failure is localized', () async {
      final api = FakeWeeklySummaryApi()
        ..latestError = const ServerException('Unavailable', 503);
      final repository = WeeklySummaryRepositoryImpl(api: api);

      final data = await repository.loadWeek(DateTime(2026, 7, 6));

      expect(data.summary.workoutLogs, 2);
      expect(data.latestRecommendation, isNull);
      expect(data.recommendationError, isNotNull);
    });

    test('summary failure is global', () async {
      final api = FakeWeeklySummaryApi()..weeklyError = const ServerException();
      final repository = WeeklySummaryRepositoryImpl(api: api);

      expect(
        repository.loadWeek(DateTime(2026, 7, 6)),
        throwsA(isA<ServerException>()),
      );
    });

    test('generate returns persisted recommendation', () async {
      final api = FakeWeeklySummaryApi()
        ..generateResult = testWeeklyRecommendation;
      final repository = WeeklySummaryRepositoryImpl(api: api);

      final result =
          await repository.generateRecommendation(DateTime(2026, 7, 6));

      expect(result.id, 'recommendation-id');
      expect(api.generateCalls, 1);
    });
  });
}
