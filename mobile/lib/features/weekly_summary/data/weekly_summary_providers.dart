import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client_provider.dart';
import 'weekly_summary_api.dart';
import 'weekly_summary_repository.dart';

final weeklySummaryApiProvider = Provider<WeeklySummaryApi>(
  (ref) => WeeklySummaryApi(ref.watch(apiClientProvider)),
);

final weeklySummaryRepositoryProvider = Provider<WeeklySummaryRepository>(
  (ref) => WeeklySummaryRepositoryImpl(
    api: ref.watch(weeklySummaryApiProvider),
  ),
);
