import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/auth_controller.dart';

/// Notifies go_router when auth state changes.
class AuthRouterRefresh extends ChangeNotifier {
  AuthRouterRefresh(this._ref) {
    _ref.listen(authControllerProvider, (_, __) {
      notifyListeners();
    });
  }

  final Ref _ref;
}
