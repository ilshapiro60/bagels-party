import 'package:flutter/foundation.dart';

/// Notifies [GoRouter] when [authStateProvider] changes so redirects re-run.
final authRouterRefresh = AuthRouterRefresh();

class AuthRouterRefresh extends ChangeNotifier {
  void notifyAuthChanged() => notifyListeners();
}
