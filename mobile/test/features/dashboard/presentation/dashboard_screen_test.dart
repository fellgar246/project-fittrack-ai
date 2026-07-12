import 'dart:async';

import 'package:fittrack_ai/features/auth/data/auth_repository.dart';
import 'package:fittrack_ai/features/dashboard/data/models/dashboard_data.dart';
import 'package:fittrack_ai/features/dashboard/data/models/measurement_progress.dart';
import 'package:fittrack_ai/features/dashboard/data/models/weekly_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/fake_dashboard.dart';
import '../../../helpers/test_app.dart';

void main() {
  testWidgets('shows loading state', (tester) async {
    final dashboard = FakeDashboardRepository()..loadGate = Completer<void>();

    await tester.pumpWidget(_authenticatedApp(dashboard));
    await pumpUntilStable(tester);

    expect(find.text('Loading your fitness overview…'), findsOneWidget);
    dashboard.loadGate!.complete();
    await tester.pump();
  });

  testWidgets('shows user and loaded dashboard sections', (tester) async {
    await tester.pumpWidget(_authenticatedApp(FakeDashboardRepository()));
    await pumpUntilStable(tester);

    expect(find.text('Hello, Demo'), findsOneWidget);
    expect(find.text('Ready for recommendation'), findsOneWidget);
    expect(find.text('68.5 kg'), findsOneWidget);
    await _scrollTo(tester, find.text('Recovery is on track.'));
    expect(find.text('Recovery is on track.'), findsOneWidget);
    await _scrollTo(tester, find.text('Quick actions'));
    expect(find.text('Quick actions'), findsOneWidget);
  });

  testWidgets('shows empty measurement and recommendation states',
      (tester) async {
    final dashboard = FakeDashboardRepository()
      ..data = DashboardData(
        weeklySummary: WeeklySummary(
          weekStart: DateTime(2026, 7, 6),
          weekEnd: DateTime(2026, 7, 12),
          workoutLogs: 0,
          workoutDays: 0,
          nutritionDaysLogged: 0,
          measurements: const MeasurementProgress(measurementsCount: 0),
          isReadyForRecommendation: false,
          missingData: const [
            'workout_logs',
            'nutrition_logs',
            'body_measurements',
          ],
        ),
        measurement: const MeasurementProgress(measurementsCount: 0),
      );

    await tester.pumpWidget(_authenticatedApp(dashboard));
    await pumpUntilStable(tester);

    expect(find.text('More data needed'), findsOneWidget);
    expect(find.text('No measurements yet'), findsOneWidget);
    await _scrollTo(tester, find.text('No weekly recommendation yet'));
    expect(find.text('No weekly recommendation yet'), findsOneWidget);
  });

  testWidgets('partial error keeps successful content and offers retry',
      (tester) async {
    final dashboard = FakeDashboardRepository()
      ..data = DashboardData(
        weeklySummary: testWeeklySummary,
        measurement: testMeasurement,
        recommendationError: 'Recommendation unavailable.',
      );

    await tester.pumpWidget(_authenticatedApp(dashboard));
    await pumpUntilStable(tester);

    expect(find.text('Ready for recommendation'), findsOneWidget);
    expect(find.text('68.5 kg'), findsOneWidget);
    await _scrollTo(tester, find.text('Recommendation unavailable.'));
    expect(find.text('Recommendation unavailable.'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Retry'), findsOneWidget);
  });

  testWidgets('pull-to-refresh invokes repository reload', (tester) async {
    final dashboard = FakeDashboardRepository();
    await tester.pumpWidget(_authenticatedApp(dashboard));
    await pumpUntilStable(tester);

    await tester.drag(
      find.byKey(const Key('dashboard-scroll-view')),
      const Offset(0, 400),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(dashboard.loadCalls, 2);
  });

  testWidgets('quick action opens an honest placeholder', (tester) async {
    await tester.pumpWidget(_authenticatedApp(FakeDashboardRepository()));
    await pumpUntilStable(tester);

    await _scrollTo(tester, find.text('Quick actions'));
    final measurements = find.text('Measurements').last;
    await _scrollTo(tester, measurements);
    await tester.drag(
      find.byKey(const Key('dashboard-scroll-view')),
      const Offset(0, -150),
    );
    await tester.pump();
    await tester.tap(measurements);
    await pumpUntilStable(tester);

    expect(find.text('Measurements flow'), findsOneWidget);
    expect(find.textContaining('Block 5.4'), findsOneWidget);
  });
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 10 && finder.evaluate().isEmpty; attempt++) {
    await tester.drag(
      find.byKey(const Key('dashboard-scroll-view')),
      const Offset(0, -300),
    );
    await tester.pump();
  }
  await tester.ensureVisible(finder);
}

Widget _authenticatedApp(FakeDashboardRepository dashboard) {
  return buildTestApp(
    authRepository: FakeAuthRepository(
      restoreOutcome: const SessionAuthenticated(testUser),
    ),
    dashboardRepository: dashboard,
  );
}
