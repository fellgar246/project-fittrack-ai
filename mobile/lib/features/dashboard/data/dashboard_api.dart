import '../../measurements/data/measurements_api.dart';
import '../../weekly_summary/data/models/weekly_recommendation.dart';
import '../../weekly_summary/data/models/weekly_summary.dart';
import '../../weekly_summary/data/weekly_summary_api.dart';

class DashboardApi {
  DashboardApi(this._weeklySummaryApi, this._measurementsApi);

  final WeeklySummaryApi _weeklySummaryApi;
  final MeasurementsApi _measurementsApi;

  Future<WeeklySummary> getWeeklySummary(DateTime weekStart) {
    return _weeklySummaryApi.getWeeklySummary(weekStart);
  }

  Future<RecommendationSummary?> getLatestRecommendation() {
    return _weeklySummaryApi.getLatestRecommendation();
  }

  MeasurementsApi get measurementsApi => _measurementsApi;
}
