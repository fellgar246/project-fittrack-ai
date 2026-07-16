import '../data/models/workout_plan_detail.dart';

enum WorkoutPlanDetailStatus {
  initial,
  loading,
  loaded,
  failure,
}

class WorkoutPlanDetailState {
  const WorkoutPlanDetailState({
    this.status = WorkoutPlanDetailStatus.initial,
    this.plan,
    this.errorMessage,
  });

  final WorkoutPlanDetailStatus status;
  final WorkoutPlanDetail? plan;
  final String? errorMessage;

  WorkoutPlanDetailState copyWith({
    WorkoutPlanDetailStatus? status,
    WorkoutPlanDetail? plan,
    String? errorMessage,
    bool clearError = false,
  }) {
    return WorkoutPlanDetailState(
      status: status ?? this.status,
      plan: plan ?? this.plan,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
