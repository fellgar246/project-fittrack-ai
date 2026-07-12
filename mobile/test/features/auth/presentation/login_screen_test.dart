import 'dart:async';

import 'package:fittrack_ai/core/errors/api_exception.dart';
import 'package:fittrack_ai/features/auth/data/models/authenticated_user.dart';
import 'package:fittrack_ai/features/auth/data/models/login_request.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/test_app.dart';

void main() {
  testWidgets('login screen renders fields', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        authRepository: FakeAuthRepository(),
      ),
    );
    await pumpUntilStable(tester);

    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Create an account'), findsOneWidget);
  });

  testWidgets('login validates empty fields', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        authRepository: FakeAuthRepository(),
      ),
    );
    await pumpUntilStable(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Email is required.'), findsOneWidget);
    expect(find.text('Password is required.'), findsOneWidget);
  });

  testWidgets('login shows loading while submitting', (tester) async {
    final repository = _PendingLoginRepository();
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      buildTestApp(authRepository: repository),
    );
    await pumpUntilStable(tester);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'user@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'secret');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    repository.completeLogin();
    await tester.pumpAndSettle();
  });

  testWidgets('login shows credential error', (tester) async {
    final repository = FakeAuthRepository()
      ..loginError = const UnauthorizedException('Invalid email or password.');

    await tester.pumpWidget(
      buildTestApp(authRepository: repository),
    );
    await pumpUntilStable(tester);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'user@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'bad');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid email or password.'), findsOneWidget);
  });

  testWidgets('login navigates to register', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        authRepository: FakeAuthRepository(),
      ),
    );
    await pumpUntilStable(tester);

    await tester.tap(find.text('Create an account'));
    await pumpUntilStable(tester);

    expect(find.widgetWithText(FilledButton, 'Create account'), findsOneWidget);
  });
}

class _PendingLoginRepository extends FakeAuthRepository {
  final _completer = Completer<AuthenticatedUser>();

  @override
  Future<AuthenticatedUser> login(LoginRequest request) {
    return _completer.future;
  }

  void completeLogin() {
    if (!_completer.isCompleted) {
      _completer.complete(testUser);
    }
  }

  void dispose() {
    if (!_completer.isCompleted) {
      _completer
          .completeError(StateError('Test ended before login completed.'));
    }
  }
}
