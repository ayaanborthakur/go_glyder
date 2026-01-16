import 'package:flutter/material.dart';
import 'searchpage.dart';
import 'calendar.dart';
import 'analytics.dart';
import 'messages.dart';
import 'community.dart';

Color darkGreen = const Color(0xFF023020);
Color lightGreen = const Color(0xFF90EE90);

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomePage(),
          const CalendarPage(),
          const AnalyticsPage(),
          const MessagesPage(),
          const SearchPage(),
          const CommunityPage(),
        ],
      ),
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
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: darkGreen,
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _buildHomePage() {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              _buildQuickActions(),
              _buildUpcomingSection(),
              _buildFeaturesGrid(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [darkGreen, darkGreen.withOpacity(0.8)],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back!',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'GoGlyder',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.directions_car,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.local_offer, color: lightGreen, size: 24),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Your school carpooling solution',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: darkGreen,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  icon: Icons.add_circle_outline,
                  title: 'New Ride',
                  subtitle: 'Create carpool',
                  onTap: () => _onItemTapped(4),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildActionCard(
                  icon: Icons.calendar_month,
                  title: 'Events',
                  subtitle: 'View calendar',
                  onTap: () => _onItemTapped(1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: lightGreen.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: darkGreen, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: darkGreen,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [lightGreen.withOpacity(0.3), lightGreen.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: darkGreen.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: darkGreen,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.event_available,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Next School Event',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
                const SizedBox(height: 4),
                Text(
                  'School Assembly',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: darkGreen,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Jan 20, 2026 • 9:00 AM',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, color: darkGreen, size: 20),
        ],
      ),
    );
  }

  Widget _buildFeaturesGrid() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Features',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: darkGreen,
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.1,
            children: [
              _buildFeatureCard(
                icon: Icons.map,
                title: 'Route Finder',
                description: 'Find the best routes',
                onTap: () => _onItemTapped(4),
              ),
              _buildFeatureCard(
                icon: Icons.analytics_outlined,
                title: 'Analytics',
                description: 'Track your rides',
                onTap: () => _onItemTapped(2),
              ),
              _buildFeatureCard(
                icon: Icons.message_outlined,
                title: 'Messages',
                description: 'Chat with riders',
                onTap: () => _onItemTapped(3),
              ),
              _buildFeatureCard(
                icon: Icons.people_outline,
                title: 'Community',
                description: 'Join carpool groups',
                onTap: () => _onItemTapped(5),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: darkGreen, size: 32),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: darkGreen,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
