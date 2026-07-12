import 'package:fittrack_ai/core/errors/api_exception.dart';
import 'package:fittrack_ai/features/auth/data/auth_providers.dart';
import 'package:fittrack_ai/features/auth/data/auth_repository.dart';
import 'package:fittrack_ai/features/auth/presentation/auth_controller.dart';
import 'package:fittrack_ai/features/auth/presentation/auth_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_auth_repository.dart';

void main() {
  group('AuthController', () {
    late FakeAuthRepository repository;
    late ProviderContainer container;

    setUp(() {
      repository = FakeAuthRepository();
      container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(repository),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('restoreSession transitions to authenticated', () async {
      repository.restoreOutcome = const SessionAuthenticated(testUser);
      final controller = container.read(authControllerProvider.notifier);

      await controller.restoreSession();

      final state = container.read(authControllerProvider);
      expect(state.status, AuthStatus.authenticated);
      expect(state.user?.email, 'user@example.com');
    });

    test('restoreSession transitions to unauthenticated', () async {
      final controller = container.read(authControllerProvider.notifier);

      await controller.restoreSession();

      expect(
        container.read(authControllerProvider).status,
        AuthStatus.unauthenticated,
      );
    });

    test('login failure exposes error message', () async {
      repository.loginError = const UnauthorizedException();
      final controller = container.read(authControllerProvider.notifier);

      await controller.login(email: 'user@example.com', password: 'bad');

      final state = container.read(authControllerProvider);
      expect(state.status, AuthStatus.unauthenticated);
      expect(state.errorMessage, isNotNull);
    });

    test('logout clears authenticated state', () async {
      repository.restoreOutcome = const SessionAuthenticated(testUser);
      final controller = container.read(authControllerProvider.notifier);
      await controller.restoreSession();

      await controller.logout();

      expect(
        container.read(authControllerProvider).status,
        AuthStatus.unauthenticated,
      );
      expect(repository.logoutCalls, 1);
    });
  });
}
