import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import 'models/auth_response.dart';
import 'models/authenticated_user.dart';
import 'models/login_request.dart';
import 'models/register_request.dart';

class AuthApi {
  AuthApi(this._client);

  final ApiClient _client;

  Future<AuthenticatedUser> register(RegisterRequest request) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.register,
      data: request.toJson(),
    );

    final data = response.data;
    if (data == null) {
      throw const FormatException('Empty register response.');
    }

    return AuthenticatedUser.fromJson(data);
  }

  Future<AuthResponse> login(LoginRequest request) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.login,
      data: request.toJson(),
    );

    final data = response.data;
    if (data == null) {
      throw const FormatException('Empty login response.');
    }

    return AuthResponse.fromJson(data);
  }

  Future<AuthenticatedUser> getCurrentUser() async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.me,
    );

    final data = response.data;
    if (data == null) {
      throw const FormatException('Empty current user response.');
    }

    return AuthenticatedUser.fromJson(data);
  }
}
