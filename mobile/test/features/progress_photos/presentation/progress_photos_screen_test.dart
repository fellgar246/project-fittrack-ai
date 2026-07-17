import 'package:fittrack_ai/core/errors/api_exception.dart';
import 'package:fittrack_ai/features/progress_photos/data/progress_photos_providers.dart';
import 'package:fittrack_ai/features/progress_photos/presentation/progress_photos_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_progress_photos.dart';
import '../../../helpers/test_app.dart';

void main() {
  testWidgets('shows loaded gallery with privacy copy', (tester) async {
    await tester.pumpWidget(
      _progressPhotosApp(FakeProgressPhotosRepository()),
    );
    await pumpUntilStable(tester);

    expect(find.text('Progress photos are private to your account.'),
        findsOneWidget);
    expect(find.text('Optional note'), findsOneWidget);
  });

  testWidgets('shows empty state', (tester) async {
    await tester.pumpWidget(
      _progressPhotosApp(FakeProgressPhotosRepository()..photos = []),
    );
    await pumpUntilStable(tester);

    expect(find.text('No progress photos yet'), findsOneWidget);
    expect(find.text('Add photo'), findsOneWidget);
  });

  testWidgets('shows global error with retry', (tester) async {
    await tester.pumpWidget(
      _progressPhotosApp(
        FakeProgressPhotosRepository()..listError = const NetworkException(),
      ),
    );
    await pumpUntilStable(tester);

    expect(
      find.text('Connection failed. Check your network and try again.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
  });
}

Widget _progressPhotosApp(FakeProgressPhotosRepository repository) {
  return ProviderScope(
    overrides: [
      progressPhotosRepositoryProvider.overrideWithValue(repository),
    ],
    child: const MaterialApp(home: ProgressPhotosScreen()),
  );
}
