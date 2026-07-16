import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

Future<void> openWeeklySummaryFromDashboard(WidgetTester tester) async {
  await pumpUntilStable(tester);
  final quickAction = find.bySemanticsLabel('Open Weekly summary');

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
      warnIfMissed: false,
    );
    await tester.pump();
  }

  await tester.tap(quickAction, warnIfMissed: false);
  await pumpUntilStable(tester);
}

Future<void> openRecommendationFromDashboard(WidgetTester tester) async {
  await pumpUntilStable(tester);
  final quickAction = find.bySemanticsLabel('Open Recommendation');

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
      warnIfMissed: false,
    );
    await tester.pump();
  }

  await tester.tap(quickAction, warnIfMissed: false);
  await pumpUntilStable(tester);
}

Future<void> scrollWeeklySummary(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 15; i++) {
    if (finder.evaluate().isNotEmpty) {
      await tester.ensureVisible(finder);
      await tester.pump();
      return;
    }
    await tester.drag(
      find.byKey(const Key('weekly-summary-scroll-view')),
      const Offset(0, -300),
      warnIfMissed: false,
    );
    await tester.pump();
  }
  if (finder.evaluate().isNotEmpty) {
    await tester.ensureVisible(finder);
    await tester.pump();
  }
}

Future<void> tapWeeklySummaryButton(
  WidgetTester tester,
  String label,
) async {
  final keyFinder =
      find.byKey(const Key('generate-weekly-recommendation-button'));
  await scrollWeeklySummary(tester, keyFinder);
  await tester.tap(keyFinder, warnIfMissed: false);
}
