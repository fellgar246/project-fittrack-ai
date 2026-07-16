import 'package:fittrack_ai/features/auth/data/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_auth_repository.dart';
import '../helpers/fake_nutrition.dart';
import '../helpers/fake_workouts.dart';
import '../helpers/nutrition_navigation.dart';
import '../helpers/workouts_navigation.dart';
import '../helpers/test_app.dart';

void main() {
  testWidgets('unauthenticated user is redirected to login', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        authRepository: FakeAuthRepository(),
      ),
    );
    await pumpUntilStable(tester);

    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
    expect(find.text('Hello, Demo'), findsNothing);
  });

  testWidgets('authenticated user is redirected to dashboard', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        authRepository: FakeAuthRepository(
          restoreOutcome: const SessionAuthenticated(testUser),
        ),
      ),
    );
    await pumpUntilStable(tester);

    expect(find.text('Hello, Demo'), findsOneWidget);
    expect(find.text('Goal: body recomposition'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsNothing);
  });

  testWidgets('authenticated user cannot access login route', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        authRepository: FakeAuthRepository(
          restoreOutcome: const SessionAuthenticated(testUser),
        ),
      ),
    );
    await pumpUntilStable(tester);

    expect(find.widgetWithText(FilledButton, 'Sign in'), findsNothing);
    expect(find.text('Hello, Demo'), findsOneWidget);
  });

  testWidgets('logout redirects to login', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        authRepository: FakeAuthRepository(
          restoreOutcome: const SessionAuthenticated(testUser),
        ),
      ),
    );
    await pumpUntilStable(tester);

    await tester.tap(find.text('Log out'));
    await pumpUntilStable(tester);

    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
    expect(find.text('Hello, Demo'), findsNothing);
  });

  testWidgets('dashboard does not show token', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        authRepository: FakeAuthRepository(
          restoreOutcome: const SessionAuthenticated(testUser),
        ),
      ),
    );
    await pumpUntilStable(tester);

    expect(find.textContaining('demo-token'), findsNothing);
    expect(find.textContaining('Bearer'), findsNothing);
  });

  testWidgets('authenticated user can open nutrition route', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        authRepository: FakeAuthRepository(
          restoreOutcome: const SessionAuthenticated(testUser),
        ),
        nutritionRepository: FakeNutritionRepository(),
      ),
    );
    await pumpUntilStable(tester);
    await openNutritionFromDashboard(tester);

    expect(find.text('Nutrition'), findsOneWidget);
    expect(find.text('Weekly nutrition summary'), findsOneWidget);
  });

  testWidgets('authenticated user can open workouts route', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        authRepository: FakeAuthRepository(
          restoreOutcome: const SessionAuthenticated(testUser),
        ),
        workoutsRepository: FakeWorkoutsRepository(),
      ),
    );
    await pumpUntilStable(tester);
    await openWorkoutsFromDashboard(tester);

    expect(find.text('Workouts'), findsOneWidget);
    expect(find.text('Workout plans'), findsOneWidget);
  });
}
