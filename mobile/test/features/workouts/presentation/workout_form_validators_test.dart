import 'package:fittrack_ai/features/workouts/presentation/workout_form_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('requiredSets rejects zero', () {
    expect(WorkoutFormValidators.requiredSets('0'), isNotNull);
    expect(WorkoutFormValidators.requiredSets('3'), isNull);
  });

  test('requiredReps rejects zero', () {
    expect(WorkoutFormValidators.requiredReps('0'), isNotNull);
    expect(WorkoutFormValidators.requiredReps('10'), isNull);
  });

  test('optionalWeight accepts empty and non-negative values', () {
    expect(WorkoutFormValidators.optionalWeight(''), isNull);
    expect(WorkoutFormValidators.optionalWeight('60'), isNull);
    expect(WorkoutFormValidators.optionalWeight('-1'), isNotNull);
  });

  test('parsePositiveInt accepts comma decimals as invalid', () {
    expect(WorkoutFormValidators.parsePositiveInt('3,5'), isNull);
    expect(WorkoutFormValidators.parsePositiveInt('3'), 3);
  });
}
