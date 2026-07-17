import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_glyder/services/firestore_service.dart';
import 'package:go_glyder/features/community/presentation/create_group_page.dart';
import 'package:go_glyder/features/community/presentation/group_detail_page.dart';
import 'package:go_glyder/features/community/presentation/qr_scan_page.dart';

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  final Color darkGreen = const Color(0xFF023020);
  final Color lightGreen = const Color(0xFF90EE90);

  final FirestoreService _firestore = FirestoreService.instance;
  final TextEditingController _newPostController = TextEditingController();

  @override
  void dispose() {
    _newPostController.dispose();
    super.dispose();
  }

  String _timeAgo(DateTime? time) {
    if (time == null) return 'just now';
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Future<void> _createPost() async {
    final content = _newPostController.text.trim();
    if (content.isEmpty) return;
    final author = FirebaseAuth.instance.currentUser?.email ?? 'Anonymous';
    await _firestore.createCommunityPost(author: author, content: content);
    _newPostController.clear();
    if (mounted) Navigator.of(context).pop();
  }

  void _showNewPostDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Post'),
        content: TextField(
          controller: _newPostController,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: "What's on your mind?",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _createPost,
            style: ElevatedButton.styleFrom(backgroundColor: darkGreen),
            child: const Text('Post', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

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
            _buildMyGroups(),
            _buildCommunityFeed(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showNewPostDialog,
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

  Widget _buildMyGroups() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'My Groups',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: darkGreen,
                ),
              ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _showJoinGroupDialog,
                    icon: Icon(Icons.vpn_key_outlined, size: 18, color: darkGreen),
                    label: Text('Join', style: TextStyle(color: darkGreen)),
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton.icon(
                    onPressed: _showCreateGroupDialog,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Create'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: darkGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      // Override the theme's full-width (infinite) minimumSize;
                      // this button lives in a Row, which gives unbounded width.
                      minimumSize: const Size(0, 44),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _firestore.streamMyGroups(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _groupsNotice('Could not load your groups');
              }
              if (!snapshot.hasData) {
                return const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) return _emptyGroups();
              return SizedBox(
                height: 140,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final id = docs[index].id;
                    final name = (data['name'] ?? '') as String;
                    return GestureDetector(
                      onTap: () => _openGroup(id, name),
                      child: Container(
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
                              child: Icon(
                                _iconFor(data['icon'] as String?),
                                color: darkGreen,
                                size: 24,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: darkGreen,
                                fontSize: 14,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap to view · invite',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _groupsNotice(String text) {
    return SizedBox(
      height: 120,
      child: Center(
        child: Text(text, style: TextStyle(color: Colors.grey[600])),
      ),
    );
  }

  Widget _emptyGroups() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.groups_outlined, size: 40, color: darkGreen),
          const SizedBox(height: 12),
          Text(
            'You haven\'t joined any groups yet',
            style: TextStyle(fontWeight: FontWeight.bold, color: darkGreen),
          ),
          const SizedBox(height: 4),
          Text(
            'Create a carpool group or join one with a code',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: _showJoinGroupDialog,
                child: Text('Join with code', style: TextStyle(color: darkGreen)),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _showCreateGroupDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: darkGreen,
                  foregroundColor: Colors.white,
                  // Bound the width — this button is inside a Row (the theme's
                  // default minimumSize forces infinite width otherwise).
                  minimumSize: const Size(0, 44),
                ),
                child: const Text('Create group'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String? key) {
    switch (key) {
      case 'sports':
        return Icons.sports_soccer;
      case 'schedule':
        return Icons.schedule;
      case 'music':
        return Icons.music_note;
      case 'event':
        return Icons.event;
      case 'group':
        return Icons.groups_rounded;
      default:
        return Icons.wb_sunny;
    }
  }

  void _openGroup(String id, String name) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GroupDetailPage(groupId: id, groupName: name),
      ),
    );
  }

  Future<void> _showCreateGroupDialog() async {
    // Full-screen form (school name, category, area, etc.). Returns
    // (groupId, name) on success, or null if the user backs out.
    final result = await Navigator.of(context).push<(String, String)>(
      MaterialPageRoute(builder: (_) => const CreateGroupPage()),
    );
    if (result != null && mounted) {
      _openGroup(result.$1, result.$2);
    }
  }

  Future<void> _showJoinGroupDialog() async {
    final codeC = TextEditingController();
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join a Group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeC,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Join code',
                hintText: 'e.g. K7P2QX',
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop('scan'),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan QR code instead'),
              style: OutlinedButton.styleFrom(
                foregroundColor: darkGreen,
                minimumSize: const Size.fromHeight(44),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: darkGreen,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop('code'),
            child: const Text('Join'),
          ),
        ],
      ),
    );

    if (action == 'scan') {
      await _scanToJoin();
    } else if (action == 'code') {
      try {
        final name = await _firestore.joinGroupByCode(codeC.text);
        _notify('Joined $name!');
      } on GroupException catch (e) {
        _notify(e.message);
      } catch (_) {
        _notify('Could not join the group.');
      }
    }
    codeC.dispose();
  }

  Future<void> _scanToJoin() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScanPage()),
    );
    if (result != null) _notify(result);
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _firestore.streamCommunityPosts(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Could not load posts'),
                );
              }
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No posts yet. Be the first to share!',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                );
              }
              return Column(
                children: docs.map((doc) {
                  final data = doc.data();
                  final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                  final post = CommunityPost(
                    author: data['author'] ?? 'Anonymous',
                    content: data['content'] ?? '',
                    timeAgo: _timeAgo(createdAt),
                    likes: data['likes'] ?? 0,
                    comments: data['comments'] ?? 0,
                  );
                  return _buildPostCard(post, doc.id);
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildPostCard(CommunityPost post, String postId) {
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
              GestureDetector(
                onTap: () => _firestore.likePost(postId),
                child: Icon(
                  Icons.favorite_border,
                  color: Colors.grey[500],
                  size: 20,
                ),
              ),
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
