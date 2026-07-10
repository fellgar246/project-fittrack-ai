import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/bootstrap/presentation/bootstrap_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import 'app_routes.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.bootstrap,
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
        path: AppRoutes.dashboard,
        name: AppRoutes.dashboardName,
        builder: (context, state) => const DashboardScreen(),
      ),
    ],
  );
});
