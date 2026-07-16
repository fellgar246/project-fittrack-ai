import 'dart:async';

import 'package:fittrack_ai/features/auth/data/auth_repository.dart';
import 'package:fittrack_ai/features/dashboard/data/models/dashboard_data.dart';
import 'package:fittrack_ai/features/measurements/data/models/measurement_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/fake_dashboard.dart';
import '../../../helpers/fake_measurements.dart';
import '../../../helpers/fake_nutrition.dart';
import '../../../helpers/fake_workouts.dart';
import '../../../helpers/measurements_navigation.dart';
import '../../../helpers/nutrition_navigation.dart';
import '../../../helpers/weekly_summary_fixtures.dart';
import '../../../helpers/workouts_navigation.dart';
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
        weeklySummary: buildTestWeeklySummary(
          isReadyForRecommendation: false,
          workoutLogs: 0,
          workoutDays: 0,
          nutritionDaysLogged: 0,
          measurements: const MeasurementProgress(measurementsCount: 0),
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

  testWidgets('quick action opens measurements screen', (tester) async {
    await tester.pumpWidget(_authenticatedApp(FakeDashboardRepository()));
    await pumpUntilStable(tester);

    await _scrollTo(tester, find.text('Quick actions'));
    await openMeasurementsFromDashboard(tester);

    expect(find.text('Progress summary'), findsOneWidget);
    expect(find.text('70.2 kg'), findsWidgets);
  });

  testWidgets('dashboard refreshes after measurement created', (tester) async {
    final dashboard = FakeDashboardRepository();
    final measurements = FakeMeasurementsRepository();

    await tester.pumpWidget(
      buildTestApp(
        authRepository: FakeAuthRepository(
          restoreOutcome: const SessionAuthenticated(testUser),
        ),
        dashboardRepository: dashboard,
        measurementsRepository: measurements,
      ),
    );
    await pumpUntilStable(tester);
    await openCreateMeasurementFromDashboard(tester);

    await tester.enterText(find.byType(TextFormField).at(0), '70');
    await tester.tap(find.widgetWithText(FilledButton, 'Save measurement'));
    await pumpUntilStable(tester);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await pumpUntilStable(tester);

    expect(dashboard.loadCalls, 2);
  });

  testWidgets('quick action opens nutrition screen', (tester) async {
    await tester.pumpWidget(_authenticatedApp(FakeDashboardRepository()));
    await pumpUntilStable(tester);

    await _scrollTo(tester, find.text('Quick actions'));
    await openNutritionFromDashboard(tester);

    expect(find.text('Weekly nutrition summary'), findsOneWidget);
    expect(find.text('1850'), findsWidgets);
  });

  testWidgets('dashboard refreshes after nutrition log created',
      (tester) async {
    final dashboard = FakeDashboardRepository();
    final nutrition = FakeNutritionRepository();

    await tester.pumpWidget(
      buildTestApp(
        authRepository: FakeAuthRepository(
          restoreOutcome: const SessionAuthenticated(testUser),
        ),
        dashboardRepository: dashboard,
        nutritionRepository: nutrition,
      ),
    );
    await pumpUntilStable(tester);
    await openCreateNutritionFromDashboard(tester);

    await tester.enterText(find.byType(TextFormField).at(0), '2100');
    await tester.enterText(find.byType(TextFormField).at(1), '130');
    await tester.enterText(find.byType(TextFormField).at(2), '250');
    await tester.enterText(find.byType(TextFormField).at(3), '65');
    await tester.tap(find.widgetWithText(FilledButton, 'Save nutrition log'));
    await pumpUntilStable(tester);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await pumpUntilStable(tester);

    expect(dashboard.loadCalls, 2);
  });

  testWidgets('quick action opens workouts screen', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        authRepository: FakeAuthRepository(
          restoreOutcome: const SessionAuthenticated(testUser),
        ),
        dashboardRepository: FakeDashboardRepository(),
        workoutsRepository: FakeWorkoutsRepository(),
      ),
    );
    await pumpUntilStable(tester);

    await _scrollTo(tester, find.text('Quick actions'));
    await openWorkoutsFromDashboard(tester);

    expect(find.text('Workout plans'), findsOneWidget);
    expect(find.text('Strength Builder'), findsOneWidget);
  });

  testWidgets('dashboard refreshes after workout log created', (tester) async {
    final dashboard = FakeDashboardRepository();
    final workouts = FakeWorkoutsRepository();

    await tester.pumpWidget(
      buildTestApp(
        authRepository: FakeAuthRepository(
          restoreOutcome: const SessionAuthenticated(testUser),
        ),
        dashboardRepository: dashboard,
        workoutsRepository: workouts,
      ),
    );
    await pumpUntilStable(tester);
    await openCreateWorkoutFromDashboard(tester);

    await tester.enterText(find.byType(TextFormField).at(0), '3');
    await tester.enterText(find.byType(TextFormField).at(1), '10');
    await tester.tap(find.widgetWithText(FilledButton, 'Save workout log'));
    await pumpUntilStable(tester);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await pumpUntilStable(tester);

    expect(dashboard.loadCalls, 2);
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
