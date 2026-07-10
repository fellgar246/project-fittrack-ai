import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/config/app_config.dart';
import 'core/errors/configuration_exception.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final config = AppConfig.fromEnvironment();

    runApp(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(config),
        ],
        child: const FitTrackApp(),
      ),
    );
  } on ConfigurationException catch (error) {
    debugPrint('Configuration error: ${error.message}');
    runApp(ConfigurationErrorApp(message: error.message));
  }
}
