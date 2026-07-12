import 'package:fittrack_ai/features/auth/data/auth_api.dart';
import 'package:fittrack_ai/features/auth/data/models/auth_response.dart';
import 'package:fittrack_ai/features/auth/data/models/authenticated_user.dart';
import 'package:fittrack_ai/features/auth/data/models/login_request.dart';
import 'package:fittrack_ai/features/auth/data/models/register_request.dart';

class FakeAuthApi implements AuthApi {
  FakeAuthApi({
    this.user = const AuthenticatedUser(
      id: '11111111-1111-1111-1111-111111111111',
      email: 'user@example.com',
      name: 'Demo User',
      goal: 'body recomposition',
    ),
    this.token = 'demo-token',
  });

  AuthenticatedUser user;
  String token;
  var registerCalls = 0;
  var loginCalls = 0;
  var meCalls = 0;

  Object? registerError;
  Object? loginError;
  Object? meError;

  @override
  Future<AuthenticatedUser> register(RegisterRequest request) async {
    registerCalls++;
    if (registerError != null) {
      throw registerError!;
    }
    return user;
  }

  @override
  Future<AuthResponse> login(LoginRequest request) async {
    loginCalls++;
    if (loginError != null) {
      throw loginError!;
    }
    return AuthResponse(accessToken: token, tokenType: 'bearer');
  }

  @override
  Future<AuthenticatedUser> getCurrentUser() async {
    meCalls++;
    if (meError != null) {
      throw meError!;
    }
    return user;
  }
}
