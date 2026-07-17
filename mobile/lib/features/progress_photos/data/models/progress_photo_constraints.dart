/// Backend-aligned constraints for progress photo uploads.
///
/// Keep in sync with `backend/app/core/config.py` and
/// `backend/app/services/progress_photo_storage.py`.
abstract final class ProgressPhotoConstraints {
  static const allowedContentTypes = {
    'image/jpeg',
    'image/png',
    'image/webp',
  };

  /// 5 MiB — matches `PROGRESS_PHOTO_MAX_BYTES` default.
  static const maxBytes = 5 * 1024 * 1024;

  static const maxNotesLength = 2000;

  /// Matches backend upload/read SAS TTL defaults (seconds).
  static const sasTtlSeconds = 300;

  /// Renew read URLs when within this window of expiry.
  static const accessSafetyWindowSeconds = 30;
}
