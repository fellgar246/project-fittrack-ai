import 'measurement.dart';
import 'measurement_progress.dart';

class MeasurementsData {
  const MeasurementsData({
    required this.items,
    this.progress,
    this.progressError,
  });

  final List<Measurement> items;
  final MeasurementProgress? progress;
  final String? progressError;

  bool get isEmpty => items.isEmpty;

  MeasurementsData copyWith({
    List<Measurement>? items,
    MeasurementProgress? progress,
    String? progressError,
    bool clearProgressError = false,
  }) {
    return MeasurementsData(
      items: items ?? this.items,
      progress: progress ?? this.progress,
      progressError:
          clearProgressError ? null : progressError ?? this.progressError,
    );
  }
}
