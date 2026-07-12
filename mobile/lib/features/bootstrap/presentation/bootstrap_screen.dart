import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/auth_state.dart';
import '../../../shared/widgets/app_scaffold.dart';

class BootstrapScreen extends ConsumerStatefulWidget {
  const BootstrapScreen({super.key});

  @override
  ConsumerState<BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends ConsumerState<BootstrapScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      ref.read(authControllerProvider.notifier).restoreSession();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final theme = Theme.of(context);

    return AppScaffold(
      title: 'FitTrack AI',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'FitTrack AI',
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _statusMessage(authState),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xl),
          if (_isLoading(authState))
            const Center(child: CircularProgressIndicator())
          else if (authState.status == AuthStatus.failure) ...[
            Text(
              authState.errorMessage ??
                  'Unable to restore your session. Check your connection.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () {
                ref.read(authControllerProvider.notifier).restoreSession();
              },
              child: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }

  bool _isLoading(AuthState authState) {
    return authState.status == AuthStatus.initial ||
        authState.status == AuthStatus.loading;
  }

  String _statusMessage(AuthState authState) {
    switch (authState.status) {
      case AuthStatus.initial:
      case AuthStatus.loading:
        return 'Restoring your session...';
      case AuthStatus.failure:
        return 'Session restore failed';
      case AuthStatus.authenticated:
        return 'Session restored';
      case AuthStatus.unauthenticated:
        return 'Redirecting to sign in...';
    }
  }
}
