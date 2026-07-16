import 'package:fittrack_ai/core/errors/api_exception.dart';
import 'package:fittrack_ai/features/auth/data/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/fake_nutrition.dart';
import '../../../helpers/nutrition_navigation.dart';
import '../../../helpers/test_app.dart';

void main() {
  testWidgets('renders real create form fields', (tester) async {
    await _openCreateForm(tester);

    expect(find.text('Calories'), findsOneWidget);
    expect(find.text('Protein (g)'), findsOneWidget);
    expect(find.text('Carbs (g)'), findsOneWidget);
    expect(find.text('Fats (g)'), findsOneWidget);
    expect(find.text('Notes (optional)'), findsOneWidget);
  });

  testWidgets('validates required calories', (tester) async {
    await _openCreateForm(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Save nutrition log'));
    await tester.pump();

    expect(find.text('Calories must be zero or greater.'), findsOneWidget);
  });

  testWidgets('rejects invalid numeric values', (tester) async {
    await _openCreateForm(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'abc');
    await tester.tap(find.widgetWithText(FilledButton, 'Save nutrition log'));
    await tester.pump();

    expect(find.text('Calories must be zero or greater.'), findsOneWidget);
  });

  testWidgets('accepts decimal values and optional notes', (tester) async {
    final repository = FakeNutritionRepository();
    await tester.pumpWidget(
      buildTestApp(
        authRepository: FakeAuthRepository(
          restoreOutcome: const SessionAuthenticated(testUser),
        ),
        nutritionRepository: repository,
      ),
    );
    await openCreateNutritionFromDashboard(tester);

    await tester.enterText(find.byType(TextFormField).at(0), '2100');
    await tester.enterText(find.byType(TextFormField).at(1), '130.5');
    await tester.enterText(find.byType(TextFormField).at(2), '250');
    await tester.enterText(find.byType(TextFormField).at(3), '65');
    await tester.tap(find.widgetWithText(FilledButton, 'Save nutrition log'));
    await pumpUntilStable(tester);

    expect(repository.createCalls, 1);
    expect(find.text('Nutrition log saved.'), findsOneWidget);
  });

  testWidgets('shows submit error for 409 conflict', (tester) async {
    final repository = FakeNutritionRepository()
      ..createError = const ConflictException(
        'Nutrition log already exists for this date',
      );

    await tester.pumpWidget(
      buildTestApp(
        authRepository: FakeAuthRepository(
          restoreOutcome: const SessionAuthenticated(testUser),
        ),
        nutritionRepository: repository,
      ),
    );
    await openCreateNutritionFromDashboard(tester);

    await tester.enterText(find.byType(TextFormField).at(0), '2100');
    await tester.enterText(find.byType(TextFormField).at(1), '130');
    await tester.enterText(find.byType(TextFormField).at(2), '250');
    await tester.enterText(find.byType(TextFormField).at(3), '65');
    await tester.tap(find.widgetWithText(FilledButton, 'Save nutrition log'));
    await pumpUntilStable(tester);

    expect(
      find.text('Nutrition log already exists for this date'),
      findsOneWidget,
    );
  });

  testWidgets('shows submit error for 422 validation', (tester) async {
    final repository = FakeNutritionRepository()
      ..createError = const ValidationException(
        'calories: Input should be greater than or equal to 0',
      );

    await tester.pumpWidget(
      buildTestApp(
        authRepository: FakeAuthRepository(
          restoreOutcome: const SessionAuthenticated(testUser),
        ),
        nutritionRepository: repository,
      ),
    );
    await openCreateNutritionFromDashboard(tester);

    await tester.enterText(find.byType(TextFormField).at(0), '2100');
    await tester.enterText(find.byType(TextFormField).at(1), '130');
    await tester.enterText(find.byType(TextFormField).at(2), '250');
    await tester.enterText(find.byType(TextFormField).at(3), '65');
    await tester.tap(find.widgetWithText(FilledButton, 'Save nutrition log'));
    await pumpUntilStable(tester);

    expect(
      find.text('calories: Input should be greater than or equal to 0'),
      findsOneWidget,
    );
  });

  testWidgets('prevents duplicate submit while loading', (tester) async {
    final repository = FakeNutritionRepository();
    await tester.pumpWidget(
      buildTestApp(
        authRepository: FakeAuthRepository(
          restoreOutcome: const SessionAuthenticated(testUser),
        ),
        nutritionRepository: repository,
      ),
    );
    await openCreateNutritionFromDashboard(tester);

    await tester.enterText(find.byType(TextFormField).at(0), '2100');
    await tester.enterText(find.byType(TextFormField).at(1), '130');
    await tester.enterText(find.byType(TextFormField).at(2), '250');
    await tester.enterText(find.byType(TextFormField).at(3), '65');
    final button = find.widgetWithText(FilledButton, 'Save nutrition log');
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
      nutritionRepository: FakeNutritionRepository(),
    ),
  );
  await openCreateNutritionFromDashboard(tester);
}
