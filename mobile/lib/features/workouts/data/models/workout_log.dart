import 'json_parsing.dart';

class WorkoutLog {
  const WorkoutLog({
    required this.id,
    required this.exerciseId,
    required this.exerciseName,
    required this.performedAt,
    required this.sets,
    required this.reps,
    this.weight,
    this.notes,
  });

  final String id;
  final String exerciseId;
  final String exerciseName;
  final DateTime performedAt;
  final int sets;
  final int reps;
  final double? weight;
  final String? notes;

  factory WorkoutLog.fromJson(Map<String, dynamic> json) {
    return WorkoutLog(
      id: requiredString(json, 'id'),
      exerciseId: requiredString(json, 'exercise_id'),
      exerciseName: requiredString(json, 'exercise_name'),
      performedAt: requiredDateTime(json, 'performed_at'),
      sets: requiredPositiveInt(json, 'sets'),
      reps: requiredPositiveInt(json, 'reps'),
      weight: optionalDouble(json, 'weight'),
      notes: optionalString(json, 'notes'),
    );
  }
}
