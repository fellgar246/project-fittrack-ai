import 'package:fittrack_ai/core/config/environment.dart';
import 'package:fittrack_ai/core/errors/configuration_exception.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppEnvironment.fromName', () {
    test('parses development', () {
      expect(
        AppEnvironment.fromName('development'),
        AppEnvironment.development,
      );
    });

    test('parses staging case-insensitively', () {
      expect(
        AppEnvironment.fromName(' STAGING '),
        AppEnvironment.staging,
      );
    });

    test('parses production', () {
      expect(
        AppEnvironment.fromName('production'),
        AppEnvironment.production,
      );
    });

    test('throws for invalid environment', () {
      expect(
        () => AppEnvironment.fromName('invalid'),
        throwsA(isA<ConfigurationException>()),
      );
    });
  });
}
