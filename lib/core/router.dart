import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import 'package:go_glyder/features/_index.g.dart';

import 'mainscreen.dart';

/// Single shared auth service the whole app (and the router) reads from.
final authService = AuthService();

final router = GoRouter(
  initialLocation: '/',
  // Rebuilds routing decisions whenever the user logs in or out.
  refreshListenable: GoRouterRefreshStream(authService.authStateChanges),
  // Gate: unauthenticated users can only ever see the login screen.
  redirect: (context, state) {
    final loggedIn = authService.currentUser != null;
    final onLoginPage = state.matchedLocation == '/login';

    // Not logged in and trying to reach the app -> send to login.
    if (!loggedIn) return onLoginPage ? null : '/login';

    // Already logged in but sitting on login -> send into the app.
    if (onLoginPage) return '/';

    return null; // No redirect needed.
  },
  routes: [
    // Login lives OUTSIDE MainScreen so it has no bottom nav bar.
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => MainScreen(child: Homepage()),
    ),
    GoRoute(
      path: '/calendar',
      builder: (context, state) => MainScreen(child: CalendarPage()),
    ),
    GoRoute(
      path: '/messages',
      builder: (context, state) => MainScreen(child: MessagesPage()),
    ),
    GoRoute(
      path: '/search',
      builder: (context, state) => MainScreen(child: SearchPage()),
    ),
    GoRoute(
      path: '/analytics',
      builder: (context, state) => MainScreen(child: AnalyticsPage()),
    ),
    GoRoute(
      path: '/community',
      builder: (context, state) => MainScreen(child: CommunityPage()),
    ),
  ],
);

/// Bridges a [Stream] (Firebase's auth state) to a [Listenable] so that
/// GoRouter re-runs its redirect logic every time auth state changes.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (dynamic _) => notifyListeners(),
    );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
