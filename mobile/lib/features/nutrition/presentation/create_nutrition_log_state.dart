enum CreateNutritionLogStatus {
  initial,
  submitting,
  success,
  failure,
}

class CreateNutritionLogState {
  const CreateNutritionLogState({
    this.status = CreateNutritionLogStatus.initial,
    this.errorMessage,
  });

  final CreateNutritionLogStatus status;
  final String? errorMessage;

  bool get isSubmitting => status == CreateNutritionLogStatus.submitting;

  CreateNutritionLogState copyWith({
    CreateNutritionLogStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CreateNutritionLogState(
      status: status ?? this.status,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
