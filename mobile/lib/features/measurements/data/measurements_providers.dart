import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client_provider.dart';
import 'measurements_api.dart';
import 'measurements_repository.dart';

final measurementsApiProvider = Provider<MeasurementsApi>(
  (ref) => MeasurementsApi(ref.watch(apiClientProvider)),
);

final measurementsRepositoryProvider = Provider<MeasurementsRepository>(
  (ref) => MeasurementsRepositoryImpl(api: ref.watch(measurementsApiProvider)),
);
