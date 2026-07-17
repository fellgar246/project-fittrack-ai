abstract final class AppRoutes {
  static const bootstrap = '/';
  static const login = '/login';
  static const register = '/register';
  static const dashboard = '/dashboard';
  static const measurements = '/measurements';
  static const newMeasurement = '/measurements/new';
  static const nutrition = '/nutrition';
  static const newNutritionLog = '/nutrition/new';
  static const workouts = '/workouts';
  static const newWorkoutLog = '/workouts/logs/new';
  static const weeklySummary = '/weekly-summary';
  static const recommendations = '/recommendations';
  static const progressPhotos = '/progress-photos';
  static const newProgressPhoto = '/progress-photos/new';

  static const bootstrapName = 'bootstrap';
  static const loginName = 'login';
  static const registerName = 'register';
  static const dashboardName = 'dashboard';
  static const measurementsName = 'measurements';
  static const newMeasurementName = 'newMeasurement';
  static const nutritionName = 'nutrition';
  static const newNutritionLogName = 'newNutritionLog';
  static const workoutsName = 'workouts';
  static const workoutPlanDetailName = 'workoutPlanDetail';
  static const newWorkoutLogName = 'newWorkoutLog';
  static const weeklySummaryName = 'weekly-summary';
  static const recommendationsName = 'recommendations';
  static const progressPhotosName = 'progressPhotos';
  static const newProgressPhotoName = 'newProgressPhoto';
  static const progressPhotoDetailName = 'progressPhotoDetail';

  static String workoutPlanDetail(String planId) => '/workouts/plans/$planId';
  static String progressPhotoDetail(String photoId) =>
      '/progress-photos/$photoId';
}
