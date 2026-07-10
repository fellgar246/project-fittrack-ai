import '../errors/configuration_exception.dart';

enum AppEnvironment {
  development,
  staging,
  production;

  String get displayName {
    switch (this) {
      case AppEnvironment.development:
        return 'development';
      case AppEnvironment.staging:
        return 'staging';
      case AppEnvironment.production:
        return 'production';
    }
  }

  static AppEnvironment fromName(String value) {
    switch (value.trim().toLowerCase()) {
      case 'development':
        return AppEnvironment.development;
      case 'staging':
        return AppEnvironment.staging;
      case 'production':
        return AppEnvironment.production;
      default:
        throw ConfigurationException('Invalid APP_ENV value: $value');
    }
  }
}
