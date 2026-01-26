import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router.dart';

Color darkGreen1 = const Color(0xFF023020);
Color lightGreen1 = const Color(0xFF90EE90);

class MainScreen extends StatelessWidget {
  final Widget child; // This is the page currently selected

  const MainScreen({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    onItemTapped(int index) {
      switch (index) {
        case 0:
          router.go('/');
          break;
        case 1:
          router.go('/calendar');
          break;
        case 2:
          router.go('/analytics');
          break;
        case 3:
          router.go('/messages');
          break;
        case 4:
          router.go('/search');
          break;
        case 5:
          router.go('/community');
          break;
        case 6:
          router.go('/login');
          break;
      }
    }

    calculateSelectedIndex(BuildContext context) {
      switch (GoRouterState.of(context).uri.toString()) {
        case '/':
          return 0;
        case '/calendar':
          return 1;
        case '/analytics':
          return 2;
        case '/messages':
          return 3;
        case '/search':
          return 4;
        case '/community':
          return 5;
        case '/login':
          return 6;

        default:
          return 0;
      }
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.message_rounded),
            label: 'Messages',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Community'),
          BottomNavigationBarItem(icon: Icon(Icons.login), label: 'Login'),
        ],
        currentIndex: calculateSelectedIndex(context),
        selectedItemColor: darkGreen1,
        onTap: onItemTapped,
      ),
    );
  }
}
