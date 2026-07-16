import 'package:fittrack_ai/core/errors/api_exception.dart';
import 'package:fittrack_ai/features/auth/data/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/fake_workouts.dart';
import '../../../helpers/test_app.dart';
import '../../../helpers/workouts_navigation.dart';

void main() {
  testWidgets('renders real create form fields', (tester) async {
    await _openCreateForm(tester);

    expect(find.text('Workout plan'), findsOneWidget);
    expect(find.text('Day'), findsOneWidget);
    expect(find.text('Exercise'), findsOneWidget);
    expect(find.text('Sets'), findsOneWidget);
    expect(find.text('Reps'), findsOneWidget);
    expect(find.text('Weight (kg, optional)'), findsOneWidget);
    expect(find.text('Notes (optional)'), findsOneWidget);
  });

  testWidgets('validates required sets and reps', (tester) async {
    await _openCreateForm(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Save workout log'));
    await tester.pump();

    expect(find.text('Sets must be greater than zero.'), findsOneWidget);
    expect(find.text('Reps must be greater than zero.'), findsOneWidget);
  });

  testWidgets('submits valid exercise log', (tester) async {
    final repository = FakeWorkoutsRepository();
    await tester.pumpWidget(
      buildTestApp(
        authRepository: FakeAuthRepository(
          restoreOutcome: const SessionAuthenticated(testUser),
        ),
        workoutsRepository: repository,
      ),
    );
    await openCreateWorkoutFromDashboard(tester);

    await tester.enterText(find.byType(TextFormField).at(0), '3');
    await tester.enterText(find.byType(TextFormField).at(1), '10');
    await tester.tap(find.widgetWithText(FilledButton, 'Save workout log'));
    await pumpUntilStable(tester);

    expect(repository.createCalls, 1);
    expect(find.text('Workout log saved.'), findsOneWidget);
  });

  testWidgets('shows submit error for 404 exercise not found', (tester) async {
    final repository = FakeWorkoutsRepository()
      ..createError = const NotFoundException('Exercise not found');

    await tester.pumpWidget(
      buildTestApp(
        authRepository: FakeAuthRepository(
          restoreOutcome: const SessionAuthenticated(testUser),
        ),
        workoutsRepository: repository,
      ),
    );
    await openCreateWorkoutFromDashboard(tester);

    await tester.enterText(find.byType(TextFormField).at(0), '3');
    await tester.enterText(find.byType(TextFormField).at(1), '10');
    await tester.tap(find.widgetWithText(FilledButton, 'Save workout log'));
    await pumpUntilStable(tester);

    expect(find.text('Exercise not found'), findsOneWidget);
  });

  testWidgets('shows submit error for 422 validation', (tester) async {
    final repository = FakeWorkoutsRepository()
      ..createError = const ValidationException(
        'sets: Input should be greater than 0',
      );

    await tester.pumpWidget(
      buildTestApp(
        authRepository: FakeAuthRepository(
          restoreOutcome: const SessionAuthenticated(testUser),
        ),
        workoutsRepository: repository,
      ),
    );
    await openCreateWorkoutFromDashboard(tester);

    await tester.enterText(find.byType(TextFormField).at(0), '3');
    await tester.enterText(find.byType(TextFormField).at(1), '10');
    await tester.tap(find.widgetWithText(FilledButton, 'Save workout log'));
    await pumpUntilStable(tester);

    expect(find.text('sets: Input should be greater than 0'), findsOneWidget);
  });

  testWidgets('prevents duplicate submit while loading', (tester) async {
    final repository = FakeWorkoutsRepository();
    await tester.pumpWidget(
      buildTestApp(
        authRepository: FakeAuthRepository(
          restoreOutcome: const SessionAuthenticated(testUser),
        ),
        workoutsRepository: repository,
      ),
    );
    await openCreateWorkoutFromDashboard(tester);

    await tester.enterText(find.byType(TextFormField).at(0), '3');
    await tester.enterText(find.byType(TextFormField).at(1), '10');
    final button = find.widgetWithText(FilledButton, 'Save workout log');
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
      workoutsRepository: FakeWorkoutsRepository(),
    ),
  );
  await openCreateWorkoutFromDashboard(tester);
}
