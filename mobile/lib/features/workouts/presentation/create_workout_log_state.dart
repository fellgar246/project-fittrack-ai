enum CreateWorkoutLogStatus {
  idle,
  submitting,
  success,
  failure,
}

class CreateWorkoutLogState {
  const CreateWorkoutLogState({
    this.status = CreateWorkoutLogStatus.idle,
    this.errorMessage,
  });

  final CreateWorkoutLogStatus status;
  final String? errorMessage;

  bool get isSubmitting => status == CreateWorkoutLogStatus.submitting;

  CreateWorkoutLogState copyWith({
    CreateWorkoutLogStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CreateWorkoutLogState(
      status: status ?? this.status,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
