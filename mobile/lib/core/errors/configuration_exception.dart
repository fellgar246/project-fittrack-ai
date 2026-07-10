import 'app_exception.dart';

/// Raised when required startup configuration is missing or invalid.
class ConfigurationException extends AppException {
  const ConfigurationException(super.message);
}
