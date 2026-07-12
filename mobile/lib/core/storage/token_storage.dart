/// Persists the access token outside the app process memory.
abstract interface class TokenStorage {
  Future<String?> readAccessToken();

  Future<void> writeAccessToken(String token);

  Future<void> deleteAccessToken();
}
