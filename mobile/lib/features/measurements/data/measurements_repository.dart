import '../../../core/errors/api_exception.dart';
import 'measurements_api.dart';
import 'models/create_measurement_request.dart';
import 'models/measurement.dart';
import 'models/measurement_progress.dart';
import 'models/measurements_data.dart';

abstract interface class MeasurementsRepository {
  Future<MeasurementsData> loadMeasurements();
  Future<Measurement> createMeasurement(CreateMeasurementRequest request);
  Future<MeasurementProgress> loadProgress();
}

class MeasurementsRepositoryImpl implements MeasurementsRepository {
  MeasurementsRepositoryImpl({required MeasurementsApi api}) : _api = api;

  final MeasurementsApi _api;

  @override
  Future<MeasurementsData> loadMeasurements() async {
    final results = await Future.wait<_Outcome<Object?>>([
      _capture<List<Measurement>>(_api.getMeasurements()),
      _capture<MeasurementProgress>(_api.getProgress()),
    ]);

    for (final result in results) {
      if (result.error is UnauthorizedException) {
        throw result.error!;
      }
    }

    final list = results[0];
    if (list.error != null) {
      throw list.error!;
    }

    final progress = results[1];
    return MeasurementsData(
      items: list.value! as List<Measurement>,
      progress: progress.value as MeasurementProgress?,
      progressError:
          progress.error == null ? null : _messageFor(progress.error!),
    );
  }

  @override
  Future<Measurement> createMeasurement(
    CreateMeasurementRequest request,
  ) {
    return _api.createMeasurement(request);
  }

  @override
  Future<MeasurementProgress> loadProgress() {
    return _api.getProgress();
  }
}

Future<_Outcome<T>> _capture<T>(Future<T> request) async {
  try {
    return _Outcome<T>(value: await request);
  } catch (error) {
    return _Outcome<T>(error: error);
  }
}

String _messageFor(Object error) {
  if (error is ApiException) {
    return error.message;
  }
  return 'Progress summary could not be loaded. Try again.';
}

class _Outcome<T> {
  const _Outcome({this.value, this.error});

  final T? value;
  final Object? error;
}
