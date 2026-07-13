import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/measurements_providers.dart';
import '../data/measurements_repository.dart';
import '../data/models/create_measurement_request.dart';
import '../data/models/measurement.dart';
import 'create_measurement_state.dart';

class CreateMeasurementController
    extends StateNotifier<CreateMeasurementState> {
  CreateMeasurementController(
    this._repository, {
    required Future<void> Function() onUnauthorized,
  })  : _onUnauthorized = onUnauthorized,
        super(const CreateMeasurementState());

  final MeasurementsRepository _repository;
  final Future<void> Function() _onUnauthorized;

  Future<Measurement?> submit(CreateMeasurementRequest request) async {
    if (state.isSubmitting) {
      return null;
    }

    state = state.copyWith(
      status: CreateMeasurementStatus.submitting,
      clearError: true,
    );

    try {
      final measurement = await _repository.createMeasurement(request);
      state = const CreateMeasurementState(
        status: CreateMeasurementStatus.success,
      );
      return measurement;
    } catch (error) {
      if (error is UnauthorizedException) {
        await _onUnauthorized();
        return null;
      }
      state = CreateMeasurementState(
        status: CreateMeasurementStatus.failure,
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
  return 'Measurement could not be saved. Try again.';
}

final createMeasurementControllerProvider = StateNotifierProvider.autoDispose<
    CreateMeasurementController, CreateMeasurementState>((ref) {
  return CreateMeasurementController(
    ref.watch(measurementsRepositoryProvider),
    onUnauthorized: () => ref.read(authControllerProvider.notifier).logout(),
  );
});
