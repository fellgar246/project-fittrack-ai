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
  static const nutritionLogs = '/nutrition-logs';
  static const nutritionSummary = '/nutrition-logs/summary';
  static const workoutPlans = '/workout-plans';
  static const workoutLogs = '/workout-logs';
  static const weeklyRecommendation = '/recommendations/weekly';
  static const latestRecommendation = '/recommendations/latest';
  static const progressPhotos = '/progress-photos';
  static const progressPhotoUploadRequests = '/progress-photos/upload-requests';

  static String workoutPlanById(String id) => '/workout-plans/$id';
  static String progressPhotoConfirm(String photoId) =>
      '/progress-photos/$photoId/confirm';
  static String progressPhotoAccess(String photoId) =>
      '/progress-photos/$photoId/access';
}
