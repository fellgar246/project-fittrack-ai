import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client_provider.dart';
import 'nutrition_api.dart';
import 'nutrition_repository.dart';

final nutritionApiProvider = Provider<NutritionApi>(
  (ref) => NutritionApi(ref.watch(apiClientProvider)),
);

final nutritionRepositoryProvider = Provider<NutritionRepository>(
  (ref) => NutritionRepositoryImpl(api: ref.watch(nutritionApiProvider)),
);
