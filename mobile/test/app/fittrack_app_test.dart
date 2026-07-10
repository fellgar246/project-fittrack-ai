import 'package:fittrack_ai/app/app.dart';
import 'package:fittrack_ai/core/config/app_config.dart';
import 'package:fittrack_ai/core/config/environment.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final testConfig = AppConfig(
    environment: AppEnvironment.development,
    apiBaseUrl: Uri.parse(
      'https://ca-fittrack-ai-api-dev.example.com',
    ),
  );

  Widget buildTestApp() {
    return ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(testConfig),
      ],
      child: const FitTrackApp(),
    );
  }

  testWidgets('renders bootstrap screen with configured environment', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    expect(find.text('FitTrack AI'), findsOneWidget);
    expect(find.text('Backend & cloud ready'), findsOneWidget);
    expect(find.text('development'), findsOneWidget);
    expect(find.text('configured'), findsOneWidget);
  });

  testWidgets('shows configuration error app for invalid startup state', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ConfigurationErrorApp(
        message: 'API_BASE_URL is required.',
      ),
    );

    expect(find.text('Configuration error'), findsOneWidget);
    expect(find.text('API_BASE_URL is required.'), findsOneWidget);
  });
}
