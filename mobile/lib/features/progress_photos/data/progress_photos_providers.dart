import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client_provider.dart';
import 'progress_photo_upload_client.dart';
import 'progress_photos_api.dart';
import 'progress_photos_repository.dart';

final progressPhotoUploadClientProvider = Provider<ProgressPhotoUploadClient>(
  (ref) => createProgressPhotoUploadClient(),
);

final progressPhotosApiProvider = Provider<ProgressPhotosApi>(
  (ref) => ProgressPhotosApi(ref.watch(apiClientProvider)),
);

final progressPhotosRepositoryProvider = Provider<ProgressPhotosRepository>(
  (ref) => ProgressPhotosRepositoryImpl(
    api: ref.watch(progressPhotosApiProvider),
    uploadClient: ref.watch(progressPhotoUploadClientProvider),
  ),
);
