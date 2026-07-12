import 'package:fittrack_ai/core/storage/token_storage.dart';

class InMemoryTokenStorage implements TokenStorage {
  String? _token;

  @override
  Future<String?> readAccessToken() async => _token;

  @override
  Future<void> writeAccessToken(String token) async {
    _token = token;
  }

  @override
  Future<void> deleteAccessToken() async {
    _token = null;
  }
}
