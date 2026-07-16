import 'package:fittrack_ai/features/nutrition/presentation/nutrition_form_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts zero calories and macros', () {
    expect(NutritionFormValidators.requiredCalories('0'), isNull);
    expect(NutritionFormValidators.requiredProtein('0'), isNull);
    expect(NutritionFormValidators.requiredCarbs('0'), isNull);
    expect(NutritionFormValidators.requiredFats('0'), isNull);
  });

  test('rejects negative values', () {
    expect(NutritionFormValidators.requiredCalories('-1'), isNotNull);
    expect(NutritionFormValidators.requiredProtein('-0.5'), isNotNull);
  });

  test('accepts decimal macros with comma', () {
    expect(NutritionFormValidators.parseNonNegativeNumber('105,5'), 105.5);
  });

  test('rejects invalid numeric input', () {
    expect(NutritionFormValidators.requiredCalories('abc'), isNotNull);
    expect(NutritionFormValidators.requiredProtein('abc'), isNotNull);
  });
}
