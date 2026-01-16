import 'package:flutter/material.dart';

class CommunityPage extends StatefulWidget {
  const CommunityPage({Key? key}) : super(key: key);

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  final Color darkGreen = const Color(0xFF023020);
  final Color lightGreen = const Color(0xFF90EE90);

  final List<CarpoolGroup> _groups = [
    CarpoolGroup(
      name: 'Morning Commuters',
      members: 8,
      description: 'Parents carpooling for 8 AM drop-off',
      icon: Icons.wb_sunny,
    ),
    CarpoolGroup(
      name: 'After School Sports',
      members: 12,
      description: 'Carpool for sports practice pickup',
      icon: Icons.sports_soccer,
    ),
    CarpoolGroup(
      name: 'Friday Flexible',
      members: 5,
      description: 'Flexible Friday afternoon rides',
      icon: Icons.schedule,
    ),
    CarpoolGroup(
      name: 'Music & Arts Club',
      members: 6,
      description: 'Rides to music and art classes',
      icon: Icons.music_note,
    ),
  ];

  final List<CommunityPost> _posts = [
    CommunityPost(
      author: 'Sarah M.',
      content:
          'Looking for carpool partners for Tuesday and Thursday mornings. Drop-off at 7:45 AM. Anyone interested?',
      timeAgo: '2h ago',
      likes: 5,
      comments: 3,
    ),
    CommunityPost(
      author: 'Mike R.',
      content:
          'Great news! Our carpool group saved a total of 150 miles this month. Keep up the great work everyone! 🚗💚',
      timeAgo: '5h ago',
      likes: 12,
      comments: 7,
    ),
    CommunityPost(
      author: 'Lisa K.',
      content:
          'Reminder: Basketball practice is moved to 4:30 PM this Thursday. Adjusting pickup times accordingly.',
      timeAgo: '1d ago',
      likes: 8,
      comments: 2,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: darkGreen,
        foregroundColor: Colors.white,
        title: const Text(
          'Community',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildCarpoolGroups(),
            _buildCommunityFeed(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Create post coming soon!'),
              duration: Duration(seconds: 2),
            ),
          );
        },
        backgroundColor: darkGreen,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Post', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: darkGreen,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.people, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Connect with Parents',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Join carpool groups and share rides',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.search, color: Colors.white.withOpacity(0.7)),
                const SizedBox(width: 12),
                Text(
                  'Search groups or posts...',
                  style: TextStyle(color: Colors.white.withOpacity(0.7)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarpoolGroups() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Carpool Groups',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: darkGreen,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: Text('See All', style: TextStyle(color: darkGreen)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _groups.length,
              itemBuilder: (context, index) {
                final group = _groups[index];
                return Container(
                  width: 160,
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: lightGreen.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(group.icon, color: darkGreen, size: 24),
                      ),
                      const Spacer(),
                      Text(
                        group.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: darkGreen,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${group.members} members',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityFeed() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Community Feed',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: darkGreen,
            ),
          ),
          const SizedBox(height: 16),
          ..._posts.map((post) => _buildPostCard(post)),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildPostCard(CommunityPost post) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: lightGreen.withOpacity(0.3),
                child: Text(
                  post.author[0],
                  style: TextStyle(
                    color: darkGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.author,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: darkGreen,
                      ),
                    ),
                    Text(
                      post.timeAgo,
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.more_horiz, color: Colors.grey[400]),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            post.content,
            style: TextStyle(
              color: Colors.grey[800],
              fontSize: 15,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.favorite_border, color: Colors.grey[500], size: 20),
              const SizedBox(width: 4),
              Text(
                '${post.likes}',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const SizedBox(width: 20),
              Icon(
                Icons.chat_bubble_outline,
                color: Colors.grey[500],
                size: 20,
              ),
              const SizedBox(width: 4),
              Text(
                '${post.comments}',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const Spacer(),
              Icon(Icons.share_outlined, color: Colors.grey[500], size: 20),
            ],
          ),
        ],
      ),
    );
  }
}

class CarpoolGroup {
  final String name;
  final int members;
  final String description;
  final IconData icon;

  CarpoolGroup({
    required this.name,
    required this.members,
    required this.description,
    required this.icon,
  });
}

class CommunityPost {
  final String author;
  final String content;
  final String timeAgo;
  final int likes;
  final int comments;

  CommunityPost({
    required this.author,
    required this.content,
    required this.timeAgo,
    required this.likes,
    required this.comments,
  });
}
