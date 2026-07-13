import 'dart:async';

import 'package:fittrack_ai/core/errors/api_exception.dart';
import 'package:fittrack_ai/features/auth/data/auth_repository.dart';
import 'package:fittrack_ai/features/measurements/data/models/measurement_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/fake_measurements.dart';
import '../../../helpers/measurements_navigation.dart';
import '../../../helpers/test_app.dart';

void main() {
  testWidgets('shows loading state', (tester) async {
    final repository = FakeMeasurementsRepository()
      ..loadGate = Completer<void>();

    await tester.pumpWidget(_authenticatedApp(repository));
    await openMeasurementsFromDashboard(tester, waitForLoad: false);

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

  testWidgets('shows loaded list and progress summary', (tester) async {
    await tester.pumpWidget(_authenticatedApp(FakeMeasurementsRepository()));
    await openMeasurementsFromDashboard(tester);

    expect(find.text('Progress summary'), findsOneWidget);
    expect(find.text('70.2 kg'), findsWidgets);
    expect(find.text('Weight change: -0.8 kg'), findsOneWidget);
  });

  testWidgets('shows empty state', (tester) async {
    final repository = FakeMeasurementsRepository()
      ..items = []
      ..progress = const MeasurementProgress(measurementsCount: 0);

    await tester.pumpWidget(_authenticatedApp(repository));
    await openMeasurementsFromDashboard(tester);

    expect(find.text('No measurements yet'), findsOneWidget);
    expect(
        find.widgetWithText(FilledButton, 'Add measurement'), findsOneWidget);
  });

  testWidgets('shows global error with retry', (tester) async {
    final repository = FakeMeasurementsRepository()
      ..loadError = const NetworkException();

    await tester.pumpWidget(_authenticatedApp(repository));
    await openMeasurementsFromDashboard(tester);

    expect(
      find.text('Connection failed. Check your network and try again.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Try again'), findsOneWidget);
  });

  testWidgets('shows partial progress error', (tester) async {
    final repository = FakeMeasurementsRepository()
      ..progressError = const ServerException();

    await tester.pumpWidget(_authenticatedApp(repository));
    await openMeasurementsFromDashboard(tester);

    expect(find.text('Progress summary'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Retry'), findsWidgets);
  });

  testWidgets('pull-to-refresh invokes repository reload', (tester) async {
    final repository = FakeMeasurementsRepository();
    await tester.pumpWidget(_authenticatedApp(repository));
    await openMeasurementsFromDashboard(tester);

    await tester.drag(
      find.byKey(const Key('measurements-scroll-view')),
      const Offset(0, 400),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(repository.loadCalls, 2);
  });

  testWidgets('add button opens create form', (tester) async {
    await tester.pumpWidget(_authenticatedApp(FakeMeasurementsRepository()));
    await openCreateMeasurementFromDashboard(tester);

    expect(find.text('Add measurement'), findsOneWidget);
    expect(find.text('Weight (kg)'), findsOneWidget);
  });
}

Widget _authenticatedApp(FakeMeasurementsRepository repository) {
  return buildTestApp(
    authRepository: FakeAuthRepository(
      restoreOutcome: const SessionAuthenticated(testUser),
    ),
    measurementsRepository: repository,
  );
}
