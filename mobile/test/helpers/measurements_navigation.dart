import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

Future<void> openMeasurementsFromDashboard(
  WidgetTester tester, {
  bool waitForLoad = true,
}) async {
  await pumpUntilStable(tester);
  final quickAction = find.bySemanticsLabel('Open Measurements');

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

Future<void> openCreateMeasurementFromDashboard(WidgetTester tester) async {
  await openMeasurementsFromDashboard(tester);
  await tester.tap(find.byType(FloatingActionButton));
  await pumpUntilStable(tester);
}
