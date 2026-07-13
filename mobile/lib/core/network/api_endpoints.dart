/// Relative API paths for the FitTrack AI backend.
///
/// Base URL is provided by [AppConfig.apiBaseUrl].
abstract final class ApiEndpoints {
  static const health = '/health';
  static const register = '/auth/register';
  static const login = '/auth/login';
  static const me = '/auth/me';
  static const weeklySummary = '/weekly-summary';
  static const measurements = '/measurements';
  static const measurementProgress = '/measurements/progress';
  static const latestRecommendation = '/recommendations/latest';
}
