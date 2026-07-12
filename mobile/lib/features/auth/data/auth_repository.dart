import '../../../core/errors/api_exception.dart';
import '../../../core/storage/token_storage.dart';
import 'auth_api.dart';
import 'models/authenticated_user.dart';
import 'models/login_request.dart';
import 'models/register_request.dart';

sealed class SessionRestoreOutcome {
  const SessionRestoreOutcome();
}

class SessionAuthenticated extends SessionRestoreOutcome {
  const SessionAuthenticated(this.user);

  final AuthenticatedUser user;
}

class SessionUnauthenticated extends SessionRestoreOutcome {
  const SessionUnauthenticated();
}

class SessionRestoreNetworkError extends SessionRestoreOutcome {
  const SessionRestoreNetworkError(this.message);

  final String message;
}

abstract interface class AuthRepository {
  Future<AuthenticatedUser> register(RegisterRequest request);

  Future<AuthenticatedUser> login(LoginRequest request);

  Future<SessionRestoreOutcome> restoreSession();

  Future<void> logout();
}

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthApi authApi,
    required TokenStorage tokenStorage,
  })  : _authApi = authApi,
        _tokenStorage = tokenStorage;

  final AuthApi _authApi;
  final TokenStorage _tokenStorage;

  @override
  Future<AuthenticatedUser> register(RegisterRequest request) async {
    await _authApi.register(request);
    return login(
      LoginRequest(
        email: request.email,
        password: request.password,
      ),
    );
  }

  @override
  Future<AuthenticatedUser> login(LoginRequest request) async {
    final authResponse = await _authApi.login(request);
    await _tokenStorage.writeAccessToken(authResponse.accessToken);
    return _authApi.getCurrentUser();
  }

  @override
  Future<SessionRestoreOutcome> restoreSession() async {
    final token = await _tokenStorage.readAccessToken();
    if (token == null || token.isEmpty) {
      return const SessionUnauthenticated();
    }

    try {
      final user = await _authApi.getCurrentUser();
      return SessionAuthenticated(user);
    } on UnauthorizedException {
      await _tokenStorage.deleteAccessToken();
      return const SessionUnauthenticated();
    } on NetworkException catch (error) {
      return SessionRestoreNetworkError(error.message);
    } on TimeoutApiException catch (error) {
      return SessionRestoreNetworkError(error.message);
    }
  }

  @override
  Future<void> logout() {
    return _tokenStorage.deleteAccessToken();
  }
}
