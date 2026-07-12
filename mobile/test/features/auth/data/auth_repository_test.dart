import 'package:fittrack_ai/core/errors/api_exception.dart';
import 'package:fittrack_ai/features/auth/data/auth_repository.dart';
import 'package:fittrack_ai/features/auth/data/models/login_request.dart';
import 'package:fittrack_ai/features/auth/data/models/register_request.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_auth_api.dart';
import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/in_memory_token_storage.dart';

void main() {
  group('AuthRepositoryImpl', () {
    late InMemoryTokenStorage storage;
    late FakeAuthApi api;
    late AuthRepositoryImpl repository;

    setUp(() {
      storage = InMemoryTokenStorage();
      api = FakeAuthApi();
      repository = AuthRepositoryImpl(authApi: api, tokenStorage: storage);
    });

    test('login success stores token', () async {
      final user = await repository.login(
        const LoginRequest(email: 'user@example.com', password: 'secret'),
      );

      expect(user.email, 'user@example.com');
      expect(await storage.readAccessToken(), 'demo-token');
    });

    test('login failure does not store token', () async {
      api.loginError =
          const UnauthorizedException('Invalid email or password.');

      await expectLater(
        repository.login(
          const LoginRequest(email: 'user@example.com', password: 'bad'),
        ),
        throwsA(isA<UnauthorizedException>()),
      );
      expect(await storage.readAccessToken(), isNull);
    });

    test('restore without token returns unauthenticated', () async {
      final outcome = await repository.restoreSession();
      expect(outcome, isA<SessionUnauthenticated>());
    });

    test('restore with valid token returns authenticated user', () async {
      await storage.writeAccessToken('demo-token');

      final outcome = await repository.restoreSession();

      expect(outcome, isA<SessionAuthenticated>());
      expect((outcome as SessionAuthenticated).user.email, 'user@example.com');
    });

    test('restore 401 deletes token', () async {
      await storage.writeAccessToken('demo-token');
      api.meError = const UnauthorizedException();

      final outcome = await repository.restoreSession();

      expect(outcome, isA<SessionUnauthenticated>());
      expect(await storage.readAccessToken(), isNull);
    });

    test('restore network error keeps token', () async {
      await storage.writeAccessToken('demo-token');
      api.meError = const NetworkException();

      final outcome = await repository.restoreSession();

      expect(outcome, isA<SessionRestoreNetworkError>());
      expect(await storage.readAccessToken(), 'demo-token');
    });

    test('logout deletes token', () async {
      await storage.writeAccessToken('demo-token');

      await repository.logout();

      expect(await storage.readAccessToken(), isNull);
    });

    test('register performs auto login', () async {
      final user = await repository.register(
        const RegisterRequest(
          email: 'new@example.com',
          name: 'New User',
          password: 'secret',
        ),
      );

      expect(api.registerCalls, 1);
      expect(api.loginCalls, 1);
      expect(user.email, 'user@example.com');
      expect(await storage.readAccessToken(), 'demo-token');
    });
  });

  group('FakeAuthRepository', () {
    test('supports preset restore outcomes in widget tests', () async {
      final fake = FakeAuthRepository(
        restoreOutcome: const SessionAuthenticated(testUser),
      );

      final outcome = await fake.restoreSession();
      expect(outcome, isA<SessionAuthenticated>());
    });
  });
}
