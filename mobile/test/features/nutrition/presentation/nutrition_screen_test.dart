import 'dart:async';

import 'package:fittrack_ai/core/errors/api_exception.dart';
import 'package:fittrack_ai/features/auth/data/auth_repository.dart';
import 'package:fittrack_ai/features/nutrition/data/models/nutrition_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/fake_nutrition.dart';
import '../../../helpers/nutrition_navigation.dart';
import '../../../helpers/test_app.dart';

void main() {
  testWidgets('shows loading state', (tester) async {
    final repository = FakeNutritionRepository()..loadGate = Completer<void>();

    await tester.pumpWidget(_authenticatedApp(repository));
    await openNutritionFromDashboard(tester, waitForLoad: false);

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

  testWidgets('shows loaded list and weekly summary', (tester) async {
    await tester.pumpWidget(_authenticatedApp(FakeNutritionRepository()));
    await openNutritionFromDashboard(tester);

    expect(find.text('Weekly nutrition summary'), findsOneWidget);
    expect(find.text('2 days logged'), findsOneWidget);
    expect(find.text('1850'), findsWidgets);
  });

  testWidgets('shows empty state', (tester) async {
    final repository = FakeNutritionRepository()
      ..items = []
      ..summary = const NutritionSummary(
        daysLogged: 0,
        avgCalories: 0,
        avgProtein: 0,
        avgCarbs: 0,
        avgFats: 0,
        totalCalories: 0,
        totalProtein: 0,
        totalCarbs: 0,
        totalFats: 0,
      );

    await tester.pumpWidget(_authenticatedApp(repository));
    await openNutritionFromDashboard(tester);

    expect(find.text('No nutrition logs yet'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Add nutrition log'),
      findsOneWidget,
    );
  });

  testWidgets('shows global error with retry', (tester) async {
    final repository = FakeNutritionRepository()
      ..loadError = const NetworkException();

    await tester.pumpWidget(_authenticatedApp(repository));
    await openNutritionFromDashboard(tester);

    expect(
      find.text('Connection failed. Check your network and try again.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Try again'), findsOneWidget);
  });

  testWidgets('shows partial summary error', (tester) async {
    final repository = FakeNutritionRepository()
      ..summaryError = const ServerException();

    await tester.pumpWidget(_authenticatedApp(repository));
    await openNutritionFromDashboard(tester);

    expect(find.text('Weekly nutrition summary'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Retry'), findsWidgets);
  });

  testWidgets('pull-to-refresh invokes repository reload', (tester) async {
    final repository = FakeNutritionRepository();
    await tester.pumpWidget(_authenticatedApp(repository));
    await openNutritionFromDashboard(tester);

    await tester.drag(
      find.byKey(const Key('nutrition-scroll-view')),
      const Offset(0, 400),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(repository.loadCalls, 2);
  });

  testWidgets('add button opens create form', (tester) async {
    await tester.pumpWidget(_authenticatedApp(FakeNutritionRepository()));
    await openCreateNutritionFromDashboard(tester);

    expect(find.text('Add nutrition log'), findsOneWidget);
    expect(find.text('Calories'), findsOneWidget);
    expect(find.text('Protein (g)'), findsOneWidget);
  });
}

Widget _authenticatedApp(FakeNutritionRepository repository) {
  return buildTestApp(
    authRepository: FakeAuthRepository(
      restoreOutcome: const SessionAuthenticated(testUser),
    ),
    nutritionRepository: repository,
  );
}
