import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import 'models/create_progress_photo_upload_request.dart';
import 'models/progress_photo.dart';
import 'models/progress_photo_access_authorization.dart';
import 'models/progress_photo_upload_authorization.dart';

class ProgressPhotosApi {
  ProgressPhotosApi(this._client);

  final ApiClient _client;

  Future<ProgressPhotoUploadAuthorization> createUploadRequest(
    CreateProgressPhotoUploadRequest request,
  ) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.progressPhotoUploadRequests,
      data: request.toJson(),
    );
    final data = response.data;
    if (data == null) {
      throw const FormatException('Empty upload authorization response.');
    }
    return ProgressPhotoUploadAuthorization.fromJson(data);
  }

  Future<ProgressPhoto> confirmUpload(String photoId) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.progressPhotoConfirm(photoId),
    );
    final data = response.data;
    if (data == null) {
      throw const FormatException('Empty confirm upload response.');
    }
    return ProgressPhoto.fromJson(data);
  }

  Future<List<ProgressPhoto>> listPhotos() async {
    final response = await _client.get<List<dynamic>>(
      ApiEndpoints.progressPhotos,
    );
    final data = response.data;
    if (data == null) {
      throw const FormatException('Empty progress photos list response.');
    }
    return data.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Invalid progress photo item in list.');
      }
      return ProgressPhoto.fromJson(item);
    }).toList(growable: false);
  }

  Future<ProgressPhotoAccessAuthorization> requestAccess(String photoId) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.progressPhotoAccess(photoId),
    );
    final data = response.data;
    if (data == null) {
      throw const FormatException('Empty photo access response.');
    }
    return ProgressPhotoAccessAuthorization.fromJson(data);
  }
}
