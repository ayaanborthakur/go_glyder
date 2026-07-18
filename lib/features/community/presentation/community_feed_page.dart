import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import 'package:go_glyder/core/theme.dart';
import 'package:go_glyder/core/widgets.dart';
import 'package:go_glyder/services/firestore_service.dart';

/// The school-scoped community feed: a wall of posts members can write, like,
/// and comment on. Shown as the "Feed" tab of CommunityPage.
class CommunityFeed extends StatelessWidget {
  final String schoolId;
  const CommunityFeed({super.key, required this.schoolId});

  FirestoreService get _fs => FirestoreService.instance;

  Future<void> _compose(BuildContext context) async {
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _ComposerSheet(),
    );
    if (text == null || text.trim().isEmpty) return;
    try {
      await _fs.createCommunityPost(schoolId: schoolId, content: text.trim());
    } on GroupException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _compose(context),
        icon: const Icon(Icons.edit_rounded),
        label: const Text('Post'),
      ),
      body: StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
        stream: _fs.streamSchoolPosts(schoolId),
        builder: (context, snap) {
          if (snap.hasError) {
            return const _CenterNote('Could not load the feed');
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final posts = snap.data!;
          if (posts.isEmpty) return _empty();
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            itemCount: posts.length,
            itemBuilder: (context, i) => _PostCard(post: posts[i])
                .animate(delay: (40 * i).ms)
                .fadeIn(duration: 280.ms)
                .slideY(begin: 0.06, end: 0, curve: Curves.easeOut),
          );
        },
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.forum_outlined,
                size: 64, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            const Text('No posts yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'Start the conversation — share an update, a question, or a '
              'shout-out with your school community.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> post;
  const _PostCard({required this.post});

  FirestoreService get _fs => FirestoreService.instance;

  @override
  Widget build(BuildContext context) {
    final data = post.data();
    final author = (data['author'] ?? 'Member') as String;
    final content = (data['content'] ?? '') as String;
    final photoUrl = data['authorPhotoUrl'] as String?;
    final likes = (data['likes'] ?? 0) as int;
    final comments = (data['comments'] ?? 0) as int;
    final ts = data['createdAt'] as Timestamp?;
    final mine = data['authorUid'] == _fs.currentUid;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgAll,
        boxShadow: kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Avatar(name: author, size: 40, photoUrl: photoUrl),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(author,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      ts != null ? _relativeTime(ts.toDate()) : 'just now',
                      style: const TextStyle(
                          color: AppColors.textTertiary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (mine)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  color: AppColors.textTertiary,
                  onPressed: () => _confirmDelete(context),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(content,
              style: const TextStyle(fontSize: 15, height: 1.4)),
          const SizedBox(height: 14),
          Row(
            children: [
              StreamBuilder<bool>(
                stream: _fs.streamHasLiked(post.id),
                builder: (context, likeSnap) {
                  final liked = likeSnap.data ?? false;
                  return _ActionButton(
                    icon: liked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    label: '$likes',
                    color: liked ? AppColors.danger : AppColors.textSecondary,
                    onTap: () => _fs.toggleLike(post.id, liked),
                  );
                },
              ),
              const SizedBox(width: 8),
              _ActionButton(
                icon: Icons.mode_comment_outlined,
                label: '$comments',
                color: AppColors.textSecondary,
                onTap: () => _openComments(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text('This can\'t be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) await _fs.deleteCommunityPost(post.id);
  }

  void _openComments(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CommentsSheet(postId: post.id),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.smAll,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              Icon(icon, size: 19, color: color),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet for composing a new post.
class _ComposerSheet extends StatefulWidget {
  const _ComposerSheet();

  @override
  State<_ComposerSheet> createState() => _ComposerSheetState();
}

class _ComposerSheetState extends State<_ComposerSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('New post',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 5,
            minLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Share something with your school…',
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(context).pop(_controller.text),
            child: const Text('Post'),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet showing a post's comments with an inline composer.
class _CommentsSheet extends StatefulWidget {
  final String postId;
  const _CommentsSheet({required this.postId});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _controller = TextEditingController();
  final _fs = FirestoreService.instance;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    await _fs.addComment(widget.postId, text);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (context, scrollController) {
          return Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 14, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Comments',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _fs.streamPostComments(widget.postId),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final comments = snap.data!.docs;
                    if (comments.isEmpty) {
                      return const _CenterNote('No comments yet — say something');
                    }
                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: comments.length,
                      itemBuilder: (context, i) {
                        final c = comments[i].data();
                        final name = (c['authorName'] ?? 'Member') as String;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Avatar(
                                name: name,
                                size: 34,
                                photoUrl: c['authorPhotoUrl'] as String?,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13.5)),
                                    const SizedBox(height: 2),
                                    Text((c['text'] ?? '') as String,
                                        style: const TextStyle(
                                            fontSize: 14, height: 1.35)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: const InputDecoration(
                          hintText: 'Add a comment…',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send_rounded,
                          color: AppColors.brandGreen),
                      onPressed: _send,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CenterNote extends StatelessWidget {
  final String text;
  const _CenterNote(this.text);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
        ),
      ),
    );
  }
}

/// Compact relative time for feed timestamps ("2h", "3d", or a date).
String _relativeTime(DateTime t) {
  final diff = DateTime.now().difference(t);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  return DateFormat('MMM d').format(t);
}
