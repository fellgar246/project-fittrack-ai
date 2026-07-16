import 'package:fittrack_ai/app/app.dart';
import 'package:fittrack_ai/core/config/app_config.dart';
import 'package:fittrack_ai/core/config/environment.dart';
import 'package:fittrack_ai/features/auth/data/auth_providers.dart';
import 'package:fittrack_ai/features/auth/data/auth_repository.dart';
import 'package:fittrack_ai/features/auth/presentation/auth_controller.dart';
import 'package:fittrack_ai/features/auth/presentation/auth_state.dart';
import 'package:fittrack_ai/features/dashboard/data/dashboard_providers.dart';
import 'package:fittrack_ai/features/dashboard/data/dashboard_repository.dart';
import 'package:fittrack_ai/features/measurements/data/measurements_providers.dart';
import 'package:fittrack_ai/features/nutrition/data/nutrition_providers.dart';
import 'package:fittrack_ai/features/measurements/data/measurements_repository.dart';
import 'package:fittrack_ai/features/nutrition/data/nutrition_repository.dart';
import 'package:fittrack_ai/features/workouts/data/workouts_providers.dart';
import 'package:fittrack_ai/features/weekly_summary/data/weekly_summary_providers.dart';
import 'package:fittrack_ai/features/weekly_summary/data/weekly_summary_repository.dart';
import 'package:fittrack_ai/features/workouts/data/workouts_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_auth_repository.dart';
import 'fake_dashboard.dart';
import 'fake_measurements.dart';
import 'fake_nutrition.dart';
import 'fake_weekly_summary.dart';
import 'fake_workouts.dart';

final testConfig = AppConfig(
  environment: AppEnvironment.development,
  apiBaseUrl: Uri.parse('https://api.example.com'),
);

Widget buildTestApp({
  AuthRepository? authRepository,
  DashboardRepository? dashboardRepository,
  MeasurementsRepository? measurementsRepository,
  NutritionRepository? nutritionRepository,
  WorkoutsRepository? workoutsRepository,
  WeeklySummaryRepository? weeklySummaryRepository,
  AuthState? initialAuthState,
}) {
  final repository = authRepository ?? FakeAuthRepository();
  final dashboard = dashboardRepository ?? FakeDashboardRepository();
  final measurements = measurementsRepository ?? FakeMeasurementsRepository();
  final nutrition = nutritionRepository ?? FakeNutritionRepository();
  final workouts = workoutsRepository ?? FakeWorkoutsRepository();
  final weeklySummary =
      weeklySummaryRepository ?? FakeWeeklySummaryRepository();

  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWithValue(testConfig),
      authRepositoryProvider.overrideWithValue(repository),
      dashboardRepositoryProvider.overrideWithValue(dashboard),
      measurementsRepositoryProvider.overrideWithValue(measurements),
      nutritionRepositoryProvider.overrideWithValue(nutrition),
      workoutsRepositoryProvider.overrideWithValue(workouts),
      weeklySummaryRepositoryProvider.overrideWithValue(weeklySummary),
      if (initialAuthState != null)
        authControllerProvider.overrideWith(
          (ref) => PresetAuthController(repository, initialAuthState),
        ),
    ],
    child: const FitTrackApp(),
  );
}

class PresetAuthController extends AuthController {
  PresetAuthController(AuthRepository repository, AuthState initialState)
      : super(repository) {
    state = initialState;
  }
}

Future<void> pumpUntilStable(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (!tester.binding.hasScheduledFrame) {
      break;
    }
  }
}
