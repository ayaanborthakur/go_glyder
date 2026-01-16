import 'package:flutter/material.dart';
import 'calendar.dart';
import 'analytics.dart';
import 'messages.dart';
import 'community.dart'; // New import for community features

Color darkGreen = const Color(0xFF023020);

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    Center(
      child: Text(
        'Home',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
    ),
    CalendarPage(), // Calendar with events and ride scheduling
    AnalyticsPage(), // Page with graphs and user statistics
    MessagesPage(), // Messaging system for users to communicate
    CommunityPage(), // Community page for user interactions
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
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
          BottomNavigationBarItem(
            // New tab for community
            icon: Icon(Icons.group),
            label: 'Community',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: darkGreen,
        onTap: _onItemTapped,
      ),
    );
  }
}
