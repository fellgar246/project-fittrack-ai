import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

Future<void> openNutritionFromDashboard(
  WidgetTester tester, {
  bool waitForLoad = true,
}) async {
  await pumpUntilStable(tester);
  final quickAction = find.bySemanticsLabel('Open Nutrition');

  for (var attempt = 0; attempt < 15; attempt++) {
    if (quickAction.evaluate().isNotEmpty) {
      final top = tester.getTopLeft(quickAction).dy;
      if (top >= 0 && top < 560) {
        break;
      }
    }
    await tester.drag(
      find.byKey(const Key('dashboard-scroll-view')),
      const Offset(0, -250),
    );
    await tester.pump();
  }

  await tester.tap(quickAction, warnIfMissed: false);
  if (waitForLoad) {
    await pumpUntilStable(tester);
  } else {
    await tester.pump();
  }
}

Future<void> openCreateNutritionFromDashboard(WidgetTester tester) async {
  await openNutritionFromDashboard(tester);
  await tester.tap(find.byType(FloatingActionButton));
  await pumpUntilStable(tester);
}
