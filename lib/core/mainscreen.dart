import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainScreen extends StatelessWidget {
  final Widget child; // This is the page currently selected

  const MainScreen({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    onItemTapped(int index) {
      switch (index) {
        case 0:
          context.go('/');
          break;
        case 1:
          context.go('/calendar');
          break;
        case 2:
          context.go('/analytics');
          break;
        case 3:
          context.go('/messages');
          break;
        case 4:
          context.go('/search');
          break;
        case 5:
          context.go('/community');
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

        default:
          return 0;
      }
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE6EAE8))),
        ),
        child: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_outlined),
              activeIcon: Icon(Icons.calendar_month_rounded),
              label: 'Calendar',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.insights_outlined),
              activeIcon: Icon(Icons.insights_rounded),
              label: 'Analytics',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline_rounded),
              activeIcon: Icon(Icons.chat_bubble_rounded),
              label: 'Messages',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search_rounded),
              activeIcon: Icon(Icons.search_rounded),
              label: 'Search',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.group_outlined),
              activeIcon: Icon(Icons.group_rounded),
              label: 'Community',
            ),
          ],
          currentIndex: calculateSelectedIndex(context),
          onTap: onItemTapped,
        ),
      ),
    );
  }
}
