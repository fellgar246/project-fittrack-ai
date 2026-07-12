import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/auth_state.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/bootstrap/presentation/bootstrap_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../shared/widgets/feature_placeholder_screen.dart';
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
        builder: (context, state) => const FeaturePlaceholderScreen(
          title: 'Measurements',
          nextBlock: 'Block 5.4',
        ),
      ),
      GoRoute(
        path: AppRoutes.nutrition,
        name: AppRoutes.nutritionName,
        builder: (context, state) => const FeaturePlaceholderScreen(
          title: 'Nutrition',
          nextBlock: 'Block 5.5',
        ),
      ),
      GoRoute(
        path: AppRoutes.workouts,
        name: AppRoutes.workoutsName,
        builder: (context, state) => const FeaturePlaceholderScreen(
          title: 'Workouts',
          nextBlock: 'Block 5.6',
        ),
      ),
      GoRoute(
        path: AppRoutes.weeklySummary,
        name: AppRoutes.weeklySummaryName,
        builder: (context, state) => const FeaturePlaceholderScreen(
          title: 'Weekly summary',
          nextBlock: 'Block 5.7',
        ),
      ),
      GoRoute(
        path: AppRoutes.recommendations,
        name: AppRoutes.recommendationsName,
        builder: (context, state) => const FeaturePlaceholderScreen(
          title: 'Recommendation',
          nextBlock: 'Block 5.7',
        ),
      ),
    ],
  );
});
