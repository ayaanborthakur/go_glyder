import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import 'package:go_glyder/core/theme.dart';
import 'package:go_glyder/services/firestore_service.dart';
import 'package:go_glyder/features/messages/logic/messages_logic.dart';

/// Deterministic on-brand avatar gradient so each person keeps a stable color.
LinearGradient avatarGradient(String name) {
  const palettes = [
    [Color(0xFF0A5C36), Color(0xFF2FBF71)],
    [Color(0xFF0E7490), Color(0xFF22D3EE)],
    [Color(0xFF4338CA), Color(0xFF818CF8)],
    [Color(0xFFB45309), Color(0xFFFBBF24)],
    [Color(0xFF9D174D), Color(0xFFF472B6)],
    [Color(0xFF115E59), Color(0xFF2DD4BF)],
  ];
  final colors = palettes[name.hashCode.abs() % palettes.length];
  return LinearGradient(
    colors: colors,
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class Avatar extends StatelessWidget {
  final String name;
  final double size;

  const Avatar({super.key, required this.name, this.size = 52});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: avatarGradient(name),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.4,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final MessagesController _controller = MessagesController.instance;

  @override
  void initState() {
    super.initState();
    // Idempotent — the controller ignores a second subscribe if one is active.
    _controller.subscribeToConversations();
  }

  Future<void> _startNewMessage() async {
    final picked = await Navigator.of(context).push<_Member>(
      MaterialPageRoute(builder: (_) => const NewMessagePage()),
    );
    if (picked != null && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              ChatDetailPage(otherUid: picked.uid, otherName: picked.name),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = _controller.currentUid ?? '';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_square, size: 22),
            onPressed: _startNewMessage,
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (_controller.conversationsError != null) {
            return _CenterNote(_controller.conversationsError!);
          }
          if (_controller.conversationsLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final convs = _controller.conversations;
          if (convs.isEmpty) return _emptyState();

          return ListView.builder(
            padding: const EdgeInsets.only(top: 12, bottom: 24),
            itemCount: convs.length,
            itemBuilder: (context, i) {
              final conv = convs[i];
              final otherUid = conv.otherUid(myUid);
              final otherName = conv.otherName(myUid);
              final lastMessage = conv.lastMessage;

              return _ConversationTile(
                name: otherName,
                lastMessage: lastMessage.isEmpty
                    ? 'Say hi to start the conversation'
                    : lastMessage,
                time: conv.lastMessageAt != null
                    ? DateFormat.jm().format(conv.lastMessageAt!)
                    : '',
                unread: conv.unreadFor(myUid),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        ChatDetailPage(otherUid: otherUid, otherName: otherName),
                  ),
                ),
              ).animate(delay: (50 * i).ms).fadeIn(duration: 300.ms).slideX(
                begin: 0.08,
                end: 0,
                curve: Curves.easeOut,
              );
            },
          );
        },
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 64,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 16),
            const Text(
              'No conversations yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Message a parent from one of your carpool groups to get started.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _startNewMessage,
              icon: const Icon(Icons.edit_square, size: 18),
              label: const Text('New message'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final String name;
  final String lastMessage;
  final String time;
  final int unread;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.unread,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasUnread = unread > 0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              Avatar(name: name, size: 54),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: hasUnread
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontWeight:
                            hasUnread ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (time.isNotEmpty)
                    Text(
                      time,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  if (hasUnread) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: const BoxDecoration(
                        color: AppColors.brandGreen,
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      child: Text(
                        unread > 99 ? '99+' : '$unread',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A person the user can start a conversation with (a fellow group member).
class _Member {
  final String uid;
  final String name;
  const _Member(this.uid, this.name);
}

/// Pick someone to message — drawn from the members of the user's groups.
class NewMessagePage extends StatelessWidget {
  const NewMessagePage({super.key});

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService.instance;
    final myUid = firestore.currentUid;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('New Message')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: firestore.streamMyGroups(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final groups = snapshot.data!.docs;
          if (groups.isEmpty) {
            return const _CenterNote(
              'Join or create a carpool group first — you can message its '
              'members here.',
            );
          }
          // Groups without a schoolId are pre-school-scoping leftovers; skip.
          final scoped = groups
              .where((g) => (g.data()['schoolId'] as String?) != null)
              .toList();
          if (scoped.isEmpty) {
            return const _CenterNote(
              'Join or create a carpool group first — you can message its '
              'members here.',
            );
          }
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: scoped.map((g) {
              final groupName = (g.data()['name'] ?? 'Group') as String;
              return _GroupMembersSection(
                schoolId: g.data()['schoolId'] as String,
                groupId: g.id,
                groupName: groupName,
                myUid: myUid,
                onPick: (member) => Navigator.of(context).pop(member),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _GroupMembersSection extends StatelessWidget {
  final String schoolId;
  final String groupId;
  final String groupName;
  final String? myUid;
  final ValueChanged<_Member> onPick;

  const _GroupMembersSection({
    required this.schoolId,
    required this.groupId,
    required this.groupName,
    required this.myUid,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
          child: Text(
            groupName.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirestoreService.instance.streamGroupMembers(
            schoolId,
            groupId,
          ),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox.shrink();
            final members = snapshot.data!.docs
                .where((m) => m.id != myUid)
                .toList();
            if (members.isEmpty) {
              return const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  'No other members yet',
                  style: TextStyle(color: AppColors.textTertiary),
                ),
              );
            }
            return Column(
              children: members.map((m) {
                final name = (m.data()['displayName'] ?? 'Member') as String;
                return ListTile(
                  leading: Avatar(name: name, size: 44),
                  title: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onTap: () => onPick(_Member(m.id, name)),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class ChatDetailPage extends StatefulWidget {
  final String otherUid;
  final String otherName;
  const ChatDetailPage({
    super.key,
    required this.otherUid,
    required this.otherName,
  });

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final MessagesController _controller = MessagesController.instance;
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.openChat(
      otherUid: widget.otherUid,
      otherName: widget.otherName,
    );
  }

  @override
  void dispose() {
    _controller.closeChat();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    await _controller.sendMessage(
      otherUid: widget.otherUid,
      otherName: widget.otherName,
      text: text,
    );
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final myUid = _controller.currentUid ?? '';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Avatar(name: widget.otherName, size: 38),
            const SizedBox(width: 12),
            Text(
              widget.otherName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListenableBuilder(
              listenable: _controller,
              builder: (context, _) {
                if (_controller.messagesError != null) {
                  return _CenterNote(_controller.messagesError!);
                }
                if (_controller.messagesLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                final msgs = _controller.activeMessages;
                if (msgs.isEmpty) return _emptyState();
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _scrollToBottom(),
                );
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: msgs.length,
                  itemBuilder: (context, i) {
                    final msg = msgs[i];
                    final isUser = msg.senderId == myUid;
                    return _bubble(
                      msg.isDeleted ? 'This message was deleted' : msg.text,
                      isUser,
                      msg.timestamp,
                      deleted: msg.isDeleted,
                    );
                  },
                );
              },
            ),
          ),
          _inputBar(),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Avatar(name: widget.otherName, size: 72),
          const SizedBox(height: 16),
          Text(
            widget.otherName,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Say hi to start the conversation',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _bubble(
    String text,
    bool isUser,
    DateTime? time, {
    bool deleted = false,
  }) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        decoration: BoxDecoration(
          gradient: isUser && !deleted
              ? const LinearGradient(
                  colors: [AppColors.brandGreen, AppColors.brandDark],
                )
              : null,
          color: isUser && !deleted ? null : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          boxShadow: isUser && !deleted ? null : kCardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: TextStyle(
                color: deleted
                    ? AppColors.textTertiary
                    : (isUser ? Colors.white : AppColors.textPrimary),
                fontSize: 15,
                height: 1.3,
                fontStyle: deleted ? FontStyle.italic : FontStyle.normal,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              time != null ? DateFormat.jm().format(time) : 'now',
              style: TextStyle(
                fontSize: 10.5,
                color: isUser && !deleted
                    ? Colors.white70
                    : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.15, end: 0);
  }

  Widget _inputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        10,
        12,
        10 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: 'Type a message…',
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _send,
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.brandAccent, AppColors.brandDark],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
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
