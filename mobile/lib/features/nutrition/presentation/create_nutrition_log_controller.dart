import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/models/create_nutrition_log_request.dart';
import '../data/models/nutrition_log.dart';
import '../data/nutrition_providers.dart';
import '../data/nutrition_repository.dart';
import 'create_nutrition_log_state.dart';

class CreateNutritionLogController
    extends StateNotifier<CreateNutritionLogState> {
  CreateNutritionLogController(
    this._repository, {
    required Future<void> Function() onUnauthorized,
  })  : _onUnauthorized = onUnauthorized,
        super(const CreateNutritionLogState());

  final NutritionRepository _repository;
  final Future<void> Function() _onUnauthorized;

  Future<NutritionLog?> submit(CreateNutritionLogRequest request) async {
    if (state.isSubmitting) {
      return null;
    }

    state = state.copyWith(
      status: CreateNutritionLogStatus.submitting,
      clearError: true,
    );

    try {
      final log = await _repository.createNutritionLog(request);
      state = const CreateNutritionLogState(
        status: CreateNutritionLogStatus.success,
      );
      return log;
    } catch (error) {
      if (error is UnauthorizedException) {
        await _onUnauthorized();
        return null;
      }
      state = CreateNutritionLogState(
        status: CreateNutritionLogStatus.failure,
        errorMessage: _messageFor(error),
      );
      return null;
    }
  }

  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(clearError: true);
    }
  }
}

String _messageFor(Object error) {
  if (error is ApiException) {
    return error.message;
  }
  return 'Nutrition log could not be saved. Try again.';
}

final createNutritionLogControllerProvider = StateNotifierProvider.autoDispose<
    CreateNutritionLogController, CreateNutritionLogState>((ref) {
  return CreateNutritionLogController(
    ref.watch(nutritionRepositoryProvider),
    onUnauthorized: () => ref.read(authControllerProvider.notifier).logout(),
  );
});
