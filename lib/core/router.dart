import 'package:go_router/go_router.dart';

import 'package:go_glyder/features/_index.g.dart';
import 'package:go_glyder/features/account/presentation/onboarding_page.dart';

import 'mainscreen.dart';
import 'session.dart';

final router = GoRouter(
  initialLocation: '/',
  // Re-runs routing whenever auth or the loaded profile/role changes.
  refreshListenable: session,
  redirect: (context, state) {
    final loc = state.matchedLocation;

    // Not signed in -> login only.
    if (!session.isLoggedIn) return loc == '/login' ? null : '/login';

    // Signed in but profile/role not read yet -> brief splash (avoids a
    // flash of onboarding for returning users).
    if (session.profileLoading) return loc == '/loading' ? null : '/loading';

    // Signed in, no role picked yet -> first-time onboarding.
    if (session.needsOnboarding) {
      return loc == '/onboarding' ? null : '/onboarding';
    }

    // Fully set up -> keep them out of the auth/onboarding screens.
    if (loc == '/login' || loc == '/onboarding' || loc == '/loading') {
      return '/';
    }
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/loading', builder: (context, state) => const SplashScreen()),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingPage(),
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
