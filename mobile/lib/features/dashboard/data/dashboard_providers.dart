import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client_provider.dart';
import '../../measurements/data/measurements_providers.dart';
import 'dashboard_api.dart';
import 'dashboard_repository.dart';

final dashboardApiProvider = Provider<DashboardApi>(
  (ref) => DashboardApi(
    ref.watch(apiClientProvider),
    ref.watch(measurementsApiProvider),
  ),
);

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DashboardRepositoryImpl(api: ref.watch(dashboardApiProvider)),
);
