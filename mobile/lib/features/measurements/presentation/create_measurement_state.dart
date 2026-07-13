enum CreateMeasurementStatus {
  initial,
  submitting,
  success,
  failure,
}

class CreateMeasurementState {
  const CreateMeasurementState({
    this.status = CreateMeasurementStatus.initial,
    this.errorMessage,
  });

  final CreateMeasurementStatus status;
  final String? errorMessage;

  bool get isSubmitting => status == CreateMeasurementStatus.submitting;

  CreateMeasurementState copyWith({
    CreateMeasurementStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CreateMeasurementState(
      status: status ?? this.status,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
