import 'json_parsing.dart';

class WorkoutPlan {
  const WorkoutPlan({
    required this.id,
    required this.name,
    required this.goal,
    required this.active,
    required this.daysCount,
    required this.exercisesCount,
  });

  final String id;
  final String name;
  final String goal;
  final bool active;
  final int daysCount;
  final int exercisesCount;

  factory WorkoutPlan.fromJson(Map<String, dynamic> json) {
    return WorkoutPlan(
      id: requiredString(json, 'id'),
      name: requiredString(json, 'name'),
      goal: requiredString(json, 'goal'),
      active: requiredBool(json, 'active'),
      daysCount: requiredInt(json, 'days_count'),
      exercisesCount: requiredInt(json, 'exercises_count'),
    );
  }
}
