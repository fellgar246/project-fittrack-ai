import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client_provider.dart';
import 'workouts_api.dart';
import 'workouts_repository.dart';

final workoutsApiProvider = Provider<WorkoutsApi>(
  (ref) => WorkoutsApi(ref.watch(apiClientProvider)),
);

final workoutsRepositoryProvider = Provider<WorkoutsRepository>(
  (ref) => WorkoutsRepositoryImpl(api: ref.watch(workoutsApiProvider)),
);
