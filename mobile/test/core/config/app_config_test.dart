import 'package:fittrack_ai/core/config/app_config.dart';
import 'package:fittrack_ai/core/errors/configuration_exception.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppConfig.normalizeApiBaseUrl', () {
    test('accepts valid https URL', () {
      final uri = AppConfig.normalizeApiBaseUrl(
        'https://ca-fittrack-ai-api-dev.example.com',
      );

      expect(uri.toString(), 'https://ca-fittrack-ai-api-dev.example.com');
    });

    test('accepts valid http URL for local development', () {
      final uri = AppConfig.normalizeApiBaseUrl('http://127.0.0.1:8000');

      expect(uri.toString(), 'http://127.0.0.1:8000');
    });

    test('removes trailing slash from root path', () {
      final uri = AppConfig.normalizeApiBaseUrl(
        'https://api.example.com/',
      );

      expect(uri.toString(), 'https://api.example.com');
    });

    test('removes trailing slash from nested path', () {
      final uri = AppConfig.normalizeApiBaseUrl(
        'https://api.example.com/v1/',
      );

      expect(uri.toString(), 'https://api.example.com/v1');
    });

    test('throws when scheme is missing', () {
      expect(
        () => AppConfig.normalizeApiBaseUrl('api.example.com'),
        throwsA(isA<ConfigurationException>()),
      );
    });

    test('throws when host is missing', () {
      expect(
        () => AppConfig.normalizeApiBaseUrl('https://'),
        throwsA(isA<ConfigurationException>()),
      );
    });
  });
}
