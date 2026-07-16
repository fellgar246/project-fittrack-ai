import 'nutrition_log.dart';
import 'nutrition_summary.dart';

class NutritionData {
  const NutritionData({
    required this.logs,
    this.summary,
    this.summaryError,
  });

  final List<NutritionLog> logs;
  final NutritionSummary? summary;
  final String? summaryError;

  bool get isEmpty => logs.isEmpty;

  NutritionData copyWith({
    List<NutritionLog>? logs,
    NutritionSummary? summary,
    String? summaryError,
    bool clearSummaryError = false,
  }) {
    return NutritionData(
      logs: logs ?? this.logs,
      summary: summary ?? this.summary,
      summaryError:
          clearSummaryError ? null : summaryError ?? this.summaryError,
    );
  }
}
