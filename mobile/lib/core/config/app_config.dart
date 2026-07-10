import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/configuration_exception.dart';
import 'environment.dart';

class AppConfig {
  const AppConfig({
    required this.environment,
    required this.apiBaseUrl,
  });

  final AppEnvironment environment;
  final Uri apiBaseUrl;

  static AppConfig fromEnvironment() {
    const environmentName = String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'development',
    );
    const apiBaseUrlRaw = String.fromEnvironment('API_BASE_URL');

    if (apiBaseUrlRaw.isEmpty) {
      throw const ConfigurationException(
        'API_BASE_URL is required. Provide it via '
        '--dart-define=API_BASE_URL=<url>.',
      );
    }

    return AppConfig(
      environment: AppEnvironment.fromName(environmentName),
      apiBaseUrl: normalizeApiBaseUrl(apiBaseUrlRaw),
    );
  }

  static Uri normalizeApiBaseUrl(String raw) {
    final trimmed = raw.trim();

    Uri uri;
    try {
      uri = Uri.parse(trimmed);
    } on FormatException {
      throw ConfigurationException('Invalid API_BASE_URL: $trimmed');
    }

    if (!uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw ConfigurationException(
        'API_BASE_URL must use http or https scheme: $trimmed',
      );
    }

    if (uri.host.isEmpty) {
      throw ConfigurationException(
        'API_BASE_URL must include a valid host: $trimmed',
      );
    }

    if (uri.path == '/') {
      return uri.replace(path: '');
    }

    if (uri.path.endsWith('/') && uri.path.length > 1) {
      return uri.replace(path: uri.path.substring(0, uri.path.length - 1));
    }

    return uri;
  }
}

final appConfigProvider = Provider<AppConfig>(
  (ref) => throw UnimplementedError(
    'AppConfig must be overridden at startup.',
  ),
);
