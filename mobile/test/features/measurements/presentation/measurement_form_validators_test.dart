import 'package:fittrack_ai/features/measurements/presentation/measurement_form_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('required weight rejects empty and zero values', () {
    expect(MeasurementFormValidators.requiredWeight(''), isNotNull);
    expect(MeasurementFormValidators.requiredWeight('0'), isNotNull);
    expect(MeasurementFormValidators.requiredWeight('70'), isNull);
  });

  test('optional waist accepts empty and validates positive numbers', () {
    expect(MeasurementFormValidators.optionalWaist(''), isNull);
    expect(MeasurementFormValidators.optionalWaist('80.5'), isNull);
    expect(MeasurementFormValidators.optionalWaist('0'), isNotNull);
  });

  test('optional body fat accepts empty and validates range', () {
    expect(MeasurementFormValidators.optionalBodyFat(''), isNull);
    expect(MeasurementFormValidators.optionalBodyFat('20'), isNull);
    expect(MeasurementFormValidators.optionalBodyFat('0.5'), isNotNull);
    expect(MeasurementFormValidators.optionalBodyFat('90'), isNotNull);
  });

  test('parses decimal values with comma normalization', () {
    expect(MeasurementFormValidators.parsePositiveNumber('70,5'), 70.5);
    expect(MeasurementFormValidators.parseBodyFat('24,5'), 24.5);
  });
}
