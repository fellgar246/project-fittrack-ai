class CreateWorkoutLogRequest {
  const CreateWorkoutLogRequest({
    required this.exerciseId,
    required this.performedAt,
    required this.sets,
    required this.reps,
    this.weight,
    this.notes,
  });

  final String exerciseId;
  final DateTime performedAt;
  final int sets;
  final int reps;
  final double? weight;
  final String? notes;

  Map<String, dynamic> toJson() {
    return {
      'exercise_id': exerciseId,
      'performed_at': performedAt.toIso8601String(),
      'sets': sets,
      'reps': reps,
      if (weight != null) 'weight': weight,
      if (notes != null) 'notes': notes,
    };
  }
}
