import 'dart:async';

import 'package:fittrack_ai/app/app.dart';
import 'package:fittrack_ai/features/auth/data/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_auth_repository.dart';
import '../helpers/test_app.dart';

void main() {
  testWidgets('renders bootstrap restore screen initially', (tester) async {
    final repository = _PendingRestoreRepository();
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      buildTestApp(authRepository: repository),
    );
    await tester.pump();

    expect(find.text('Restoring your session...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    repository.completeRestore();
    await tester.pumpAndSettle();
  });

  testWidgets('shows configuration error app for invalid startup state', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ConfigurationErrorApp(
        message: 'API_BASE_URL is required.',
      ),
    );

    expect(find.text('Configuration error'), findsOneWidget);
    expect(find.text('API_BASE_URL is required.'), findsOneWidget);
  });
}

class _PendingRestoreRepository extends FakeAuthRepository {
  final _completer = Completer<SessionRestoreOutcome>();

  @override
  Future<SessionRestoreOutcome> restoreSession() {
    return _completer.future;
  }

  void completeRestore() {
    if (!_completer.isCompleted) {
      _completer.complete(const SessionUnauthenticated());
    }
  }

  void dispose() {
    if (!_completer.isCompleted) {
      _completer.complete(const SessionUnauthenticated());
    }
  }
}
