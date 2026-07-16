import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../measurements/data/measurements_providers.dart';
import '../../weekly_summary/data/weekly_summary_providers.dart';
import 'dashboard_api.dart';
import 'dashboard_repository.dart';

final dashboardApiProvider = Provider<DashboardApi>(
  (ref) => DashboardApi(
    ref.watch(weeklySummaryApiProvider),
    ref.watch(measurementsApiProvider),
  ),
);

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DashboardRepositoryImpl(api: ref.watch(dashboardApiProvider)),
);
