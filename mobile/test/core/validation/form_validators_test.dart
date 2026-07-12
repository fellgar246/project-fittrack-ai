import 'package:fittrack_ai/core/validation/form_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FormValidators', () {
    test('email rejects empty value', () {
      expect(FormValidators.email(''), 'Email is required.');
    });

    test('email rejects invalid format', () {
      expect(
          FormValidators.email('not-an-email'), 'Enter a valid email address.');
    });

    test('password requires value', () {
      expect(FormValidators.password(''), 'Password is required.');
    });

    test('confirmPassword detects mismatch', () {
      expect(
        FormValidators.confirmPassword('abc', 'xyz'),
        'Passwords do not match.',
      );
    });
  });
}
