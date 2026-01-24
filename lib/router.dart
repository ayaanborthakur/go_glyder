import 'package:go_router/go_router.dart';

import 'pages/all.dart';

final router = GoRouter(
  routes: [
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
