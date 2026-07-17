import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/auth_state.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/bootstrap/presentation/bootstrap_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/measurements/presentation/create_measurement_screen.dart';
import '../../features/measurements/presentation/measurements_screen.dart';
import '../../features/nutrition/presentation/create_nutrition_log_screen.dart';
import '../../features/nutrition/presentation/nutrition_screen.dart';
import '../../features/workouts/presentation/create_workout_log_screen.dart';
import '../../features/workouts/presentation/workout_plan_detail_screen.dart';
import '../../features/workouts/presentation/workouts_screen.dart';
import '../../features/progress_photos/data/models/progress_photo.dart';
import '../../features/progress_photos/presentation/create_progress_photo_screen.dart';
import '../../features/progress_photos/presentation/progress_photo_detail_screen.dart';
import '../../features/progress_photos/presentation/progress_photos_screen.dart';
import '../../features/weekly_summary/presentation/weekly_summary_screen.dart';
import 'app_routes.dart';
import 'auth_router_refresh.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = AuthRouterRefresh(ref);

  return GoRouter(
    initialLocation: AppRoutes.bootstrap,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final location = state.matchedLocation;

      final isBootstrap = location == AppRoutes.bootstrap;
      final isAuthRoute =
          location == AppRoutes.login || location == AppRoutes.register;
      final isProtected = !isBootstrap && !isAuthRoute;

      switch (authState.status) {
        case AuthStatus.initial:
        case AuthStatus.loading:
          return isBootstrap ? null : AppRoutes.bootstrap;
        case AuthStatus.failure:
          return isBootstrap ? null : AppRoutes.bootstrap;
        case AuthStatus.authenticated:
          if (isBootstrap || isAuthRoute) {
            return AppRoutes.dashboard;
          }
          return null;
        case AuthStatus.unauthenticated:
          if (isProtected || isBootstrap) {
            return AppRoutes.login;
          }
          return null;
      }
    },
    routes: [
      GoRoute(
        path: AppRoutes.bootstrap,
        name: AppRoutes.bootstrapName,
        builder: (context, state) => const BootstrapScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: AppRoutes.loginName,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: AppRoutes.registerName,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.dashboard,
        name: AppRoutes.dashboardName,
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.measurements,
        name: AppRoutes.measurementsName,
        builder: (context, state) => const MeasurementsScreen(),
        routes: [
          GoRoute(
            path: 'new',
            name: AppRoutes.newMeasurementName,
            builder: (context, state) => const CreateMeasurementScreen(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.nutrition,
        name: AppRoutes.nutritionName,
        builder: (context, state) => const NutritionScreen(),
        routes: [
          GoRoute(
            path: 'new',
            name: AppRoutes.newNutritionLogName,
            builder: (context, state) => const CreateNutritionLogScreen(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.workouts,
        name: AppRoutes.workoutsName,
        builder: (context, state) => const WorkoutsScreen(),
        routes: [
          GoRoute(
            path: 'plans/:planId',
            name: AppRoutes.workoutPlanDetailName,
            builder: (context, state) => WorkoutPlanDetailScreen(
              planId: state.pathParameters['planId']!,
            ),
          ),
          GoRoute(
            path: 'logs/new',
            name: AppRoutes.newWorkoutLogName,
            builder: (context, state) => CreateWorkoutLogScreen(
              initialPlanId: state.uri.queryParameters['planId'],
              initialExerciseId: state.uri.queryParameters['exerciseId'],
            ),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.weeklySummary,
        name: AppRoutes.weeklySummaryName,
        builder: (context, state) => const WeeklySummaryScreen(),
      ),
      GoRoute(
        path: AppRoutes.progressPhotos,
        name: AppRoutes.progressPhotosName,
        builder: (context, state) => const ProgressPhotosScreen(),
        routes: [
          GoRoute(
            path: 'new',
            name: AppRoutes.newProgressPhotoName,
            builder: (context, state) => const CreateProgressPhotoScreen(),
          ),
          GoRoute(
            path: ':photoId',
            name: AppRoutes.progressPhotoDetailName,
            builder: (context, state) => ProgressPhotoDetailScreen(
              photoId: state.pathParameters['photoId']!,
              initialPhoto: state.extra as ProgressPhoto?,
            ),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.recommendations,
        name: AppRoutes.recommendationsName,
        builder: (context, state) => const WeeklySummaryScreen(),
      ),
    ],
  );
});
