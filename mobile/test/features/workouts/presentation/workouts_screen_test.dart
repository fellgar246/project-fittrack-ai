import 'dart:async';

import 'package:fittrack_ai/core/errors/api_exception.dart';
import 'package:fittrack_ai/features/auth/data/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/fake_workouts.dart';
import '../../../helpers/test_app.dart';
import '../../../helpers/workouts_navigation.dart';

void main() {
  testWidgets('shows loading state', (tester) async {
    final repository = FakeWorkoutsRepository()..loadGate = Completer<void>();

    await tester.pumpWidget(_authenticatedApp(repository));
    await openWorkoutsFromDashboard(tester, waitForLoad: false);

    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.byType(CircularProgressIndicator).evaluate().isNotEmpty) {
        break;
      }
    }

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    repository.loadGate!.complete();
    await pumpUntilStable(tester);
  });

  testWidgets('shows loaded plans and recent logs', (tester) async {
    await tester.pumpWidget(_authenticatedApp(FakeWorkoutsRepository()));
    await openWorkoutsFromDashboard(tester);

    expect(find.text('Workout plans'), findsOneWidget);
    expect(find.text('Recent workouts'), findsOneWidget);
    expect(find.text('Strength Builder'), findsOneWidget);
    expect(find.text('Bench press'), findsOneWidget);
  });

  testWidgets('shows empty plans state', (tester) async {
    final repository = FakeWorkoutsRepository()..plans = [];

    await tester.pumpWidget(_authenticatedApp(repository));
    await openWorkoutsFromDashboard(tester);

    expect(find.text('No workout plans available'), findsOneWidget);
  });

  testWidgets('shows empty logs state with CTA when plans exist',
      (tester) async {
    final repository = FakeWorkoutsRepository()..logs = [];

    await tester.pumpWidget(_authenticatedApp(repository));
    await openWorkoutsFromDashboard(tester);

    expect(find.text('No workouts logged yet'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Log exercise'), findsOneWidget);
  });

  testWidgets('shows global error with retry', (tester) async {
    final repository = FakeWorkoutsRepository()
      ..loadError = const NetworkException();

    await tester.pumpWidget(_authenticatedApp(repository));
    await openWorkoutsFromDashboard(tester);

    expect(
      find.text('Connection failed. Check your network and try again.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Try again'), findsOneWidget);
  });

  testWidgets('shows partial logs error', (tester) async {
    final repository = FakeWorkoutsRepository()
      ..logsError = const ServerException();

    await tester.pumpWidget(_authenticatedApp(repository));
    await openWorkoutsFromDashboard(tester);

    expect(find.text('Strength Builder'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Retry logs'), findsOneWidget);
  });

  testWidgets('pull-to-refresh invokes repository reload', (tester) async {
    final repository = FakeWorkoutsRepository();
    await tester.pumpWidget(_authenticatedApp(repository));
    await openWorkoutsFromDashboard(tester);

    await tester.drag(
      find.byKey(const Key('workouts-scroll-view')),
      const Offset(0, 400),
    );
    await pumpUntilStable(tester);

    expect(repository.loadCalls, greaterThan(1));
  });

  testWidgets('add button opens create form', (tester) async {
    await tester.pumpWidget(_authenticatedApp(FakeWorkoutsRepository()));
    await openWorkoutsFromDashboard(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await pumpUntilStable(tester);

    expect(find.text('Log exercise'), findsWidgets);
    expect(find.text('Save workout log'), findsOneWidget);
  });
}

Widget _authenticatedApp(FakeWorkoutsRepository repository) {
  return buildTestApp(
    authRepository: FakeAuthRepository(
      restoreOutcome: const SessionAuthenticated(testUser),
    ),
    workoutsRepository: repository,
  );
}
