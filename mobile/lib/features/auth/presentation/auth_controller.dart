import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../data/auth_providers.dart';
import '../data/auth_repository.dart';
import '../data/models/login_request.dart';
import '../data/models/register_request.dart';
import 'auth_state.dart';

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repository) : super(const AuthState());

  final AuthRepository _repository;

  Future<void> restoreSession() async {
    if (state.status == AuthStatus.loading) {
      return;
    }

    state = state.copyWith(
      status: AuthStatus.loading,
      clearError: true,
      isSubmitting: false,
    );

    try {
      final outcome = await _repository.restoreSession();
      switch (outcome) {
        case SessionAuthenticated(:final user):
          state = AuthState(
            status: AuthStatus.authenticated,
            user: user,
          );
        case SessionUnauthenticated():
          state = const AuthState(status: AuthStatus.unauthenticated);
        case SessionRestoreNetworkError(:final message):
          state = AuthState(
            status: AuthStatus.failure,
            errorMessage: message,
          );
      }
    } catch (error) {
      state = AuthState(
        status: AuthStatus.failure,
        errorMessage: _messageFor(error),
      );
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    if (state.isSubmitting) {
      return;
    }

    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
    );

    try {
      final user = await _repository.login(
        LoginRequest(email: email.trim(), password: password),
      );
      state = AuthState(
        status: AuthStatus.authenticated,
        user: user,
      );
    } catch (error) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        isSubmitting: false,
        errorMessage: _messageFor(error),
      );
    }
  }

  Future<void> register({
    required String email,
    required String name,
    required String password,
    String goal = 'body recomposition',
  }) async {
    if (state.isSubmitting) {
      return;
    }

    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
    );

    try {
      final user = await _repository.register(
        RegisterRequest(
          email: email.trim(),
          name: name.trim(),
          password: password,
          goal: goal.trim().isEmpty ? 'body recomposition' : goal.trim(),
        ),
      );
      state = AuthState(
        status: AuthStatus.authenticated,
        user: user,
      );
    } catch (error) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        isSubmitting: false,
        errorMessage: _messageFor(error),
      );
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  String _messageFor(Object error) {
    if (error is ApiException) {
      return error.message;
    }
    return 'Something went wrong. Try again.';
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});
