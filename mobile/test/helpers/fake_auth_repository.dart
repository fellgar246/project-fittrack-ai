import 'package:fittrack_ai/features/auth/data/auth_repository.dart';
import 'package:fittrack_ai/features/auth/data/models/authenticated_user.dart';
import 'package:fittrack_ai/features/auth/data/models/login_request.dart';
import 'package:fittrack_ai/features/auth/data/models/register_request.dart';

const testUser = AuthenticatedUser(
  id: '11111111-1111-1111-1111-111111111111',
  email: 'user@example.com',
  name: 'Demo User',
  goal: 'body recomposition',
);

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    this.restoreOutcome = const SessionUnauthenticated(),
    this.user = testUser,
  });

  SessionRestoreOutcome restoreOutcome;
  AuthenticatedUser user;
  Object? loginError;
  Object? registerError;
  var logoutCalls = 0;

  @override
  Future<AuthenticatedUser> login(LoginRequest request) async {
    if (loginError != null) {
      throw loginError!;
    }
    return user;
  }

  @override
  Future<void> logout() async {
    logoutCalls++;
  }

  @override
  Future<AuthenticatedUser> register(RegisterRequest request) async {
    if (registerError != null) {
      throw registerError!;
    }
    return user;
  }

  @override
  Future<SessionRestoreOutcome> restoreSession() async {
    return restoreOutcome;
  }
}
