import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'dio_provider.dart';

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(dioProvider)),
);
