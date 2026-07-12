import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/auth_state.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/bootstrap/presentation/bootstrap_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
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
      final isProtected = location == AppRoutes.dashboard;

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
    ],
  );
});
