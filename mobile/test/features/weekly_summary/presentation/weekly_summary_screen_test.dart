import 'dart:async';

import 'package:fittrack_ai/core/errors/api_exception.dart';
import 'package:fittrack_ai/features/auth/data/auth_repository.dart';
import 'package:fittrack_ai/features/weekly_summary/data/models/weekly_summary_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/fake_dashboard.dart';
import '../../../helpers/fake_weekly_summary.dart';
import '../../../helpers/weekly_summary_fixtures.dart';
import '../../../helpers/weekly_summary_navigation.dart';
import '../../../helpers/test_app.dart';

void main() {
  testWidgets('shows loading then loaded ready state', (tester) async {
    final weekly = FakeWeeklySummaryRepository()..loadGate = Completer<void>();

    await tester.pumpWidget(_authenticatedApp(weekly));
    await openWeeklySummaryFromDashboard(tester);

    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.byType(CircularProgressIndicator).evaluate().isNotEmpty) {
        break;
      }
    }

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    weekly.loadGate!.complete();
    await pumpUntilStable(tester);

    expect(find.text('Ready for recommendation'), findsOneWidget);
    expect(find.text('Weekly metrics'), findsOneWidget);
  });

  testWidgets('shows not ready state with missing data', (tester) async {
    final weekly = FakeWeeklySummaryRepository()
      ..data = WeeklySummaryData(
        summary: buildTestWeeklySummary(
          isReadyForRecommendation: false,
          missingData: const [
            'workout_logs',
            'nutrition_logs',
            'body_measurements',
          ],
        ),
      );

    await tester.pumpWidget(_authenticatedApp(weekly));
    await openWeeklySummaryFromDashboard(tester);

    expect(find.text('Weekly metrics'), findsOneWidget);
    expect(find.text('More data needed'), findsOneWidget);
    await scrollWeeklySummary(
        tester, find.byKey(const Key('missing-data-card')));
    expect(find.byKey(const Key('missing-data-card')), findsOneWidget);
    expect(find.text('Open Workouts'), findsOneWidget);
    await scrollWeeklySummary(
      tester,
      find.byKey(const Key('generate-weekly-recommendation-button')),
    );
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('generate-weekly-recommendation-button')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('shows existing recommendation and safety notes', (tester) async {
    await tester.pumpWidget(_authenticatedApp(FakeWeeklySummaryRepository()));
    await openWeeklySummaryFromDashboard(tester);
    await scrollWeeklySummary(tester, find.text('Recovery is on track.'));

    expect(find.text('Recovery is on track.'), findsOneWidget);
    await scrollWeeklySummary(tester, find.text('Safety notes'));
    expect(find.text('Safety notes'), findsOneWidget);
    expect(find.text('This does not replace medical advice.'), findsOneWidget);
  });

  testWidgets('empty recommendation state when latest is absent',
      (tester) async {
    final weekly = FakeWeeklySummaryRepository()
      ..data = WeeklySummaryData(
        summary: buildTestWeeklySummary(isReadyForRecommendation: true),
      )
      ..latestRecommendation = null;
    weekly.data = WeeklySummaryData(
      summary: buildTestWeeklySummary(isReadyForRecommendation: true),
      latestRecommendation: null,
    );

    await tester.pumpWidget(_authenticatedApp(weekly));
    await openWeeklySummaryFromDashboard(tester);
    await scrollWeeklySummary(
        tester, find.text('No weekly recommendation yet'));

    expect(find.text('No weekly recommendation yet'), findsOneWidget);
    expect(
      find.text(
          'Your weekly data is ready. Generate your first recommendation.'),
      findsOneWidget,
    );
  });

  testWidgets('generate button enabled when ready and shows loading',
      (tester) async {
    final weekly = FakeWeeklySummaryRepository()
      ..data = WeeklySummaryData(
        summary: buildTestWeeklySummary(isReadyForRecommendation: true),
        latestRecommendation: null,
      )
      ..generateGate = Completer<void>();

    await tester.pumpWidget(_authenticatedApp(weekly));
    await openWeeklySummaryFromDashboard(tester);

    await tapWeeklySummaryButton(tester, 'Generate weekly recommendation');
    await tester.pump();

    expect(find.text('Generating your recommendation…'), findsWidgets);
    expect(find.text('This may take several seconds.'), findsOneWidget);
    weekly.generateGate!.complete();
    await pumpUntilStable(tester);
    expect(find.text('Weekly recommendation generated.'), findsOneWidget);
  });

  testWidgets('pull-to-refresh reloads weekly summary', (tester) async {
    final weekly = FakeWeeklySummaryRepository();
    await tester.pumpWidget(_authenticatedApp(weekly));
    await openWeeklySummaryFromDashboard(tester);

    await tester.drag(
      find.byKey(const Key('weekly-summary-scroll-view')),
      const Offset(0, 300),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(weekly.loadCalls, greaterThan(1));
  });

  testWidgets('dashboard navigation opens weekly summary', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        authRepository: FakeAuthRepository(
          restoreOutcome: const SessionAuthenticated(testUser),
        ),
        weeklySummaryRepository: FakeWeeklySummaryRepository(),
      ),
    );
    await openWeeklySummaryFromDashboard(tester);

    expect(find.text('Weekly summary'), findsOneWidget);
    expect(find.text('Ready for recommendation'), findsOneWidget);
  });

  testWidgets('generation success refreshes dashboard on back', (tester) async {
    final dashboard = FakeDashboardRepository();
    final weekly = FakeWeeklySummaryRepository()
      ..data = WeeklySummaryData(
        summary: buildTestWeeklySummary(isReadyForRecommendation: true),
        latestRecommendation: null,
      );

    await tester.pumpWidget(
      buildTestApp(
        authRepository: FakeAuthRepository(
          restoreOutcome: const SessionAuthenticated(testUser),
        ),
        dashboardRepository: dashboard,
        weeklySummaryRepository: weekly,
      ),
    );
    await openWeeklySummaryFromDashboard(tester);
    await tapWeeklySummaryButton(tester, 'Generate weekly recommendation');
    await pumpUntilStable(tester);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await pumpUntilStable(tester);

    expect(dashboard.loadCalls, greaterThan(1));
  });

  testWidgets('shows provider failure message', (tester) async {
    final weekly = FakeWeeklySummaryRepository()
      ..generateError = const ServerException('AI provider failed', 502);

    await tester.pumpWidget(_authenticatedApp(weekly));
    await openWeeklySummaryFromDashboard(tester);
    await tapWeeklySummaryButton(tester, 'Generate weekly recommendation');
    await pumpUntilStable(tester);

    expect(
      find.text(
        'The AI recommendation service could not complete the request.',
      ),
      findsOneWidget,
    );
  });
}

Widget _authenticatedApp(FakeWeeklySummaryRepository weekly) {
  return buildTestApp(
    authRepository: FakeAuthRepository(
      restoreOutcome: const SessionAuthenticated(testUser),
    ),
    weeklySummaryRepository: weekly,
  );
}
