import 'json_parsing.dart';

class WorkoutExercise {
  const WorkoutExercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    required this.targetSets,
    required this.targetReps,
  });

  final String id;
  final String name;
  final String muscleGroup;
  final int targetSets;
  final String targetReps;

  factory WorkoutExercise.fromJson(Map<String, dynamic> json) {
    return WorkoutExercise(
      id: requiredString(json, 'id'),
      name: requiredString(json, 'name'),
      muscleGroup: requiredString(json, 'muscle_group'),
      targetSets: requiredPositiveInt(json, 'target_sets'),
      targetReps: requiredString(json, 'target_reps'),
    );
  }
}

class WorkoutDay {
  const WorkoutDay({
    required this.id,
    required this.dayOfWeek,
    required this.title,
    required this.exercises,
  });

  final String id;
  final int dayOfWeek;
  final String title;
  final List<WorkoutExercise> exercises;

  factory WorkoutDay.fromJson(Map<String, dynamic> json) {
    final exercisesRaw = json['exercises'];
    if (exercisesRaw is! List) {
      throw const FormatException('Invalid exercises in workout response.');
    }
    return WorkoutDay(
      id: requiredString(json, 'id'),
      dayOfWeek: requiredInt(json, 'day_of_week'),
      title: requiredString(json, 'title'),
      exercises: exercisesRaw.map((item) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException(
            'Invalid exercise item in workout response.',
          );
        }
        return WorkoutExercise.fromJson(item);
      }).toList(growable: false),
    );
  }
}

class WorkoutPlanDetail {
  const WorkoutPlanDetail({
    required this.id,
    required this.name,
    required this.goal,
    required this.active,
    required this.days,
  });

  final String id;
  final String name;
  final String goal;
  final bool active;
  final List<WorkoutDay> days;

  int get exercisesCount =>
      days.fold<int>(0, (count, day) => count + day.exercises.length);

  factory WorkoutPlanDetail.fromJson(Map<String, dynamic> json) {
    final daysRaw = json['days'];
    if (daysRaw is! List) {
      throw const FormatException('Invalid days in workout response.');
    }
    return WorkoutPlanDetail(
      id: requiredString(json, 'id'),
      name: requiredString(json, 'name'),
      goal: requiredString(json, 'goal'),
      active: requiredBool(json, 'active'),
      days: daysRaw.map((item) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException(
            'Invalid day item in workout response.',
          );
        }
        return WorkoutDay.fromJson(item);
      }).toList(growable: false),
    );
  }
}
