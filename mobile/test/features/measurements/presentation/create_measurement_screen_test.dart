import 'package:fittrack_ai/core/errors/api_exception.dart';
import 'package:fittrack_ai/features/auth/data/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/fake_measurements.dart';
import '../../../helpers/measurements_navigation.dart';
import '../../../helpers/test_app.dart';

void main() {
  testWidgets('renders real create form fields', (tester) async {
    await _openCreateForm(tester);

    expect(find.text('Weight (kg)'), findsOneWidget);
    expect(find.text('Waist (cm, optional)'), findsOneWidget);
    expect(find.text('Body fat estimate (%, optional)'), findsOneWidget);
    expect(find.text('Notes (optional)'), findsOneWidget);
  });

  testWidgets('validates required weight', (tester) async {
    await _openCreateForm(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Save measurement'));
    await tester.pump();

    expect(find.text('Weight must be greater than 0.'), findsOneWidget);
  });

  testWidgets('rejects invalid numeric values', (tester) async {
    await _openCreateForm(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'abc');
    await tester.tap(find.widgetWithText(FilledButton, 'Save measurement'));
    await tester.pump();

    expect(find.text('Weight must be greater than 0.'), findsOneWidget);
  });

  testWidgets('accepts decimal values and optional fields', (tester) async {
    final repository = FakeMeasurementsRepository();
    await tester.pumpWidget(
      buildTestApp(
        authRepository: FakeAuthRepository(
          restoreOutcome: const SessionAuthenticated(testUser),
        ),
        measurementsRepository: repository,
      ),
    );
    await openCreateMeasurementFromDashboard(tester);

    await tester.enterText(find.byType(TextFormField).at(0), '70.5');
    await tester.enterText(find.byType(TextFormField).at(1), '80.0');
    await tester.tap(find.widgetWithText(FilledButton, 'Save measurement'));
    await pumpUntilStable(tester);

    expect(repository.createCalls, 1);
    expect(find.text('Measurement saved.'), findsOneWidget);
  });

  testWidgets('shows submit error', (tester) async {
    final repository = FakeMeasurementsRepository()
      ..createError = const ConflictException(
        'Body measurement already exists for this date',
      );

    await tester.pumpWidget(
      buildTestApp(
        authRepository: FakeAuthRepository(
          restoreOutcome: const SessionAuthenticated(testUser),
        ),
        measurementsRepository: repository,
      ),
    );
    await openCreateMeasurementFromDashboard(tester);

    await tester.enterText(find.byType(TextFormField).at(0), '70');
    await tester.tap(find.widgetWithText(FilledButton, 'Save measurement'));
    await pumpUntilStable(tester);

    expect(
      find.text('Body measurement already exists for this date'),
      findsOneWidget,
    );
  });

  testWidgets('prevents duplicate submit while loading', (tester) async {
    final repository = FakeMeasurementsRepository();
    await tester.pumpWidget(
      buildTestApp(
        authRepository: FakeAuthRepository(
          restoreOutcome: const SessionAuthenticated(testUser),
        ),
        measurementsRepository: repository,
      ),
    );
    await openCreateMeasurementFromDashboard(tester);

    await tester.enterText(find.byType(TextFormField).at(0), '70');
    final button = find.widgetWithText(FilledButton, 'Save measurement');
    await tester.tap(button);
    await tester.pump();
    await tester.tap(button);
    await pumpUntilStable(tester);

    expect(repository.createCalls, 1);
  });
}

Future<void> _openCreateForm(WidgetTester tester) async {
  await tester.pumpWidget(
    buildTestApp(
      authRepository: FakeAuthRepository(
        restoreOutcome: const SessionAuthenticated(testUser),
      ),
      measurementsRepository: FakeMeasurementsRepository(),
    ),
  );
  await openCreateMeasurementFromDashboard(tester);
}
