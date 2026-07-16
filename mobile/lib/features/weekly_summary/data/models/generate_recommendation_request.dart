import '../../../measurements/data/models/json_parsing.dart';

class GenerateRecommendationRequest {
  const GenerateRecommendationRequest({required this.weekStart});

  final DateTime weekStart;

  Map<String, dynamic> toJson() {
    return {'week_start': dateOnly(weekStart)};
  }
}
