import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/progress_photos_providers.dart';
import '../data/progress_photos_repository.dart';
import 'progress_photos_state.dart';

class ProgressPhotosController extends StateNotifier<ProgressPhotosState> {
  ProgressPhotosController(
    this._repository, {
    required Future<void> Function() onUnauthorized,
  })  : _onUnauthorized = onUnauthorized,
        super(const ProgressPhotosState());

  final ProgressPhotosRepository _repository;
  final Future<void> Function() _onUnauthorized;
  bool _requestInProgress = false;
  final Set<String> _accessInFlight = {};

  Future<void> load() async {
    if (_requestInProgress || state.status != ProgressPhotosStatus.initial) {
      return;
    }
    state = const ProgressPhotosState(status: ProgressPhotosStatus.loading);
    await _load(preserveData: false);
  }

  Future<void> refresh() async {
    if (_requestInProgress) {
      return;
    }
    state = state.copyWith(isRefreshing: true, clearError: true);
    await _load(preserveData: true);
  }

  Future<void> retry() async {
    if (_requestInProgress) {
      return;
    }
    state = state.photos.isEmpty
        ? const ProgressPhotosState(status: ProgressPhotosStatus.loading)
        : state.copyWith(isRefreshing: true, clearError: true);
    await _load(preserveData: state.photos.isNotEmpty);
  }

  Future<void> reloadAfterCreate() async {
    if (_requestInProgress) {
      return;
    }
    _repository.clearAccessCache();
    await _load(preserveData: true, clearAccess: true);
  }

  Future<void> ensurePhotoAccess(String photoId) async {
    if (state.accessUrls.containsKey(photoId) ||
        _accessInFlight.contains(photoId)) {
      return;
    }
    _accessInFlight.add(photoId);
    state = state.copyWith(
      loadingAccess: {...state.loadingAccess, photoId},
      accessErrors: Map<String, String>.from(state.accessErrors)
        ..remove(photoId),
    );

    try {
      final url = await _repository.getPhotoAccessUrl(photoId);
      final nextUrls = Map<String, String>.from(state.accessUrls)
        ..[photoId] = url;
      final nextLoading = Set<String>.from(state.loadingAccess)
        ..remove(photoId);
      state = state.copyWith(
        accessUrls: nextUrls,
        loadingAccess: nextLoading,
      );
    } catch (error) {
      if (await _handleUnauthorized(error)) {
        return;
      }
      final nextErrors = Map<String, String>.from(state.accessErrors)
        ..[photoId] = _messageFor(error);
      final nextLoading = Set<String>.from(state.loadingAccess)
        ..remove(photoId);
      state = state.copyWith(
        accessErrors: nextErrors,
        loadingAccess: nextLoading,
      );
    } finally {
      _accessInFlight.remove(photoId);
    }
  }

  Future<void> retryPhotoAccess(String photoId) async {
    _repository.invalidatePhotoAccess(photoId);
    final nextUrls = Map<String, String>.from(state.accessUrls)
      ..remove(photoId);
    state = state.copyWith(accessUrls: nextUrls);
    await ensurePhotoAccess(photoId);
  }

  Future<void> _load({
    required bool preserveData,
    bool clearAccess = false,
  }) async {
    _requestInProgress = true;
    try {
      final photos = await _repository.listPhotos();
      state = ProgressPhotosState(
        status: ProgressPhotosStatus.loaded,
        photos: photos,
        isRefreshing: false,
        accessErrors: clearAccess ? const {} : state.accessErrors,
        accessUrls: clearAccess ? const {} : state.accessUrls,
        loadingAccess: clearAccess ? const {} : state.loadingAccess,
      );
    } catch (error) {
      if (await _handleUnauthorized(error)) {
        return;
      }
      final message = _messageFor(error);
      if (preserveData && state.photos.isNotEmpty) {
        state = state.copyWith(
          status: ProgressPhotosStatus.loaded,
          errorMessage: message,
          isRefreshing: false,
        );
      } else {
        state = ProgressPhotosState(
          status: ProgressPhotosStatus.failure,
          errorMessage: message,
        );
      }
    } finally {
      _requestInProgress = false;
    }
  }

  Future<bool> _handleUnauthorized(Object error) async {
    if (error is UnauthorizedException) {
      await _onUnauthorized();
      return true;
    }
    return false;
  }
}

String _messageFor(Object error) {
  if (error is ApiException) {
    return error.message;
  }
  return 'Progress photos could not be loaded. Try again.';
}

final progressPhotosControllerProvider = StateNotifierProvider.autoDispose<
    ProgressPhotosController, ProgressPhotosState>((ref) {
  final controller = ProgressPhotosController(
    ref.watch(progressPhotosRepositoryProvider),
    onUnauthorized: () => ref.read(authControllerProvider.notifier).logout(),
  );
  controller.load();
  return controller;
});
