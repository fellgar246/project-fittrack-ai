import 'package:fittrack_ai/core/errors/api_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/test_app.dart';

void main() {
  Future<void> openRegister(WidgetTester tester) async {
    await tester.pumpWidget(
      buildTestApp(
        authRepository: FakeAuthRepository(),
      ),
    );
    await pumpUntilStable(tester);
    await tester.tap(find.text('Create an account'));
    await pumpUntilStable(tester);
  }

  testWidgets('register screen renders fields', (tester) async {
    await openRegister(tester);

    expect(find.widgetWithText(FilledButton, 'Create account'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(5));
    expect(find.text('Back to sign in'), findsOneWidget);
  });

  testWidgets('register validates required fields', (tester) async {
    await openRegister(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Name is required.'), findsOneWidget);
    expect(find.text('Email is required.'), findsOneWidget);
    expect(find.text('Password is required.'), findsOneWidget);
  });

  testWidgets('register validates password mismatch', (tester) async {
    await openRegister(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'Demo User');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'user@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(2), 'secret-one');
    await tester.enterText(find.byType(TextFormField).at(3), 'secret-two');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Passwords do not match.'), findsOneWidget);
  });

  testWidgets('register shows conflict error', (tester) async {
    final repository = FakeAuthRepository()
      ..registerError = const ConflictException('Email already registered.');

    await tester.pumpWidget(buildTestApp(authRepository: repository));
    await pumpUntilStable(tester);
    await tester.tap(find.text('Create an account'));
    await pumpUntilStable(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'Demo User');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'user@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(2), 'secret');
    await tester.enterText(find.byType(TextFormField).at(3), 'secret');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await pumpUntilStable(tester);

    expect(find.text('Email already registered.'), findsOneWidget);
  });
}
