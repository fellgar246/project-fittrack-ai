import 'package:fittrack_ai/app/app.dart';
import 'package:fittrack_ai/core/config/app_config.dart';
import 'package:fittrack_ai/core/config/environment.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final testConfig = AppConfig(
    environment: AppEnvironment.development,
    apiBaseUrl: Uri.parse('https://api.example.com'),
  );

  Widget buildTestApp() {
    return ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(testConfig),
      ],
      child: const FitTrackApp(),
    );
  }

  testWidgets('navigates from bootstrap to login placeholder', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open login'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsOneWidget);
    expect(
      find.text('Auth integration arrives in Block 5.2.'),
      findsOneWidget,
    );
  });

  testWidgets('navigates from bootstrap to dashboard placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open dashboard'));
    await tester.pumpAndSettle();

    expect(find.text('Fitness overview'), findsOneWidget);
    expect(find.text('Measurements'), findsOneWidget);
    expect(find.text('AI Recommendation'), findsOneWidget);
  });
}
