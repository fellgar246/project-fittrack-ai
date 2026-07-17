import 'models/progress_photo_access_authorization.dart';
import 'models/progress_photo_constraints.dart';

class CachedPhotoAccess {
  const CachedPhotoAccess({
    required this.accessUrl,
    required this.expiresAt,
  });

  final String accessUrl;
  final DateTime expiresAt;

  bool isExpired({DateTime? now, Duration? safetyWindow}) {
    final effectiveNow = now ?? DateTime.now().toUtc();
    final window = safetyWindow ??
        const Duration(
            seconds: ProgressPhotoConstraints.accessSafetyWindowSeconds);
    return !expiresAt.toUtc().isAfter(effectiveNow.add(window));
  }
}

/// In-memory cache for short-lived read SAS URLs. Never persisted.
class ProgressPhotoAccessCache {
  ProgressPhotoAccessCache();

  final Map<String, CachedPhotoAccess> _entries = {};

  CachedPhotoAccess? get(String photoId) {
    final entry = _entries[photoId];
    if (entry == null) {
      return null;
    }
    if (entry.isExpired()) {
      _entries.remove(photoId);
      return null;
    }
    return entry;
  }

  void put(ProgressPhotoAccessAuthorization authorization) {
    _entries[authorization.photoId] = CachedPhotoAccess(
      accessUrl: authorization.accessUrl,
      expiresAt: authorization.expiresAt,
    );
  }

  void invalidate(String photoId) {
    _entries.remove(photoId);
  }

  void clear() {
    _entries.clear();
  }
}
