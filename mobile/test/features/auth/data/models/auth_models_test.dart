import 'package:fittrack_ai/features/auth/data/models/auth_response.dart';
import 'package:fittrack_ai/features/auth/data/models/authenticated_user.dart';
import 'package:fittrack_ai/features/auth/data/models/login_request.dart';
import 'package:fittrack_ai/features/auth/data/models/register_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RegisterRequest', () {
    test('serializes expected backend fields', () {
      const request = RegisterRequest(
        email: 'user@example.com',
        name: 'Demo User',
        password: 'secret',
        goal: 'body recomposition',
      );

      expect(
        request.toJson(),
        {
          'email': 'user@example.com',
          'name': 'Demo User',
          'password': 'secret',
          'goal': 'body recomposition',
        },
      );
    });
  });

  group('LoginRequest', () {
    test('serializes email and password', () {
      const request = LoginRequest(
        email: 'user@example.com',
        password: 'secret',
      );

      expect(
        request.toJson(),
        {
          'email': 'user@example.com',
          'password': 'secret',
        },
      );
    });
  });

  group('AuthResponse', () {
    test('deserializes token payload', () {
      final response = AuthResponse.fromJson(const {
        'access_token': 'token-value',
        'token_type': 'bearer',
      });

      expect(response.accessToken, 'token-value');
      expect(response.tokenType, 'bearer');
    });

    test('throws when access token is missing', () {
      expect(
        () => AuthResponse.fromJson(const {'token_type': 'bearer'}),
        throwsFormatException,
      );
    });
  });

  group('AuthenticatedUser', () {
    test('deserializes user payload', () {
      final user = AuthenticatedUser.fromJson(const {
        'id': '11111111-1111-1111-1111-111111111111',
        'email': 'user@example.com',
        'name': 'Demo User',
        'goal': 'body recomposition',
      });

      expect(user.email, 'user@example.com');
      expect(user.name, 'Demo User');
      expect(user.goal, 'body recomposition');
    });

    test('throws when email is missing', () {
      expect(
        () => AuthenticatedUser.fromJson(const {
          'id': '11111111-1111-1111-1111-111111111111',
          'name': 'Demo User',
          'goal': 'body recomposition',
        }),
        throwsFormatException,
      );
    });
  });
}
