import 'package:fittrack_ai/app/app.dart';
import 'package:fittrack_ai/core/config/app_config.dart';
import 'package:fittrack_ai/core/config/environment.dart';
import 'package:fittrack_ai/features/auth/data/auth_providers.dart';
import 'package:fittrack_ai/features/auth/data/auth_repository.dart';
import 'package:fittrack_ai/features/auth/presentation/auth_controller.dart';
import 'package:fittrack_ai/features/auth/presentation/auth_state.dart';
import 'package:fittrack_ai/features/dashboard/data/dashboard_providers.dart';
import 'package:fittrack_ai/features/dashboard/data/dashboard_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_auth_repository.dart';
import 'fake_dashboard.dart';

final testConfig = AppConfig(
  environment: AppEnvironment.development,
  apiBaseUrl: Uri.parse('https://api.example.com'),
);

Widget buildTestApp({
  AuthRepository? authRepository,
  DashboardRepository? dashboardRepository,
  AuthState? initialAuthState,
}) {
  final repository = authRepository ?? FakeAuthRepository();
  final dashboard = dashboardRepository ?? FakeDashboardRepository();

  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWithValue(testConfig),
      authRepositoryProvider.overrideWithValue(repository),
      dashboardRepositoryProvider.overrideWithValue(dashboard),
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
