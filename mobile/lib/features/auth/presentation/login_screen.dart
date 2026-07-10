import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/app_scaffold.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppScaffold(
      title: 'Login',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Sign in',
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Auth integration arrives in Block 5.2.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          const TextField(
            enabled: false,
            decoration: InputDecoration(
              labelText: 'Email',
              hintText: 'placeholder@example.com',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const TextField(
            enabled: false,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: '••••••••',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const FilledButton(
            onPressed: null,
            child: Text('Sign in (coming soon)'),
          ),
        ],
      ),
    );
  }
}
