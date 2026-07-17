import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fittrack_ai/features/auth/data/auth_repository.dart';

import 'fake_auth_repository.dart';
import 'fake_progress_photos.dart';
import 'test_app.dart';

Future<void> openProgressPhotosFromDashboard(
  WidgetTester tester, {
  bool waitForLoad = true,
}) async {
  await pumpUntilStable(tester);
  final quickAction = find.bySemanticsLabel('Open Progress photos');

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

Widget authenticatedProgressPhotosApp(FakeProgressPhotosRepository repository) {
  return buildTestApp(
    progressPhotosRepository: repository,
    authRepository: FakeAuthRepository(
      restoreOutcome: const SessionAuthenticated(testUser),
    ),
  );
}
