// lib/features/messages/presentation/messages.dart
//
// Messages feature — presentation layer only.
//
// All data access goes through MessagesController (messages_logic.dart).
// No direct Firestore or Firebase imports here.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import 'package:go_glyder/core/theme.dart';
import 'package:go_glyder/features/messages/logic/messages_logic.dart';
import 'package:go_glyder/services/firestore_service.dart'; // for streamMyGroups / streamGroupMembers


// ─────────────────────────────────────────────────────────────────────────────
// Shared avatar widget
// ─────────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
// Conversations list page
// ─────────────────────────────────────────────────────────────────────────────

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final MessagesController _ctrl = MessagesController.instance;

  @override
  void initState() {
    super.initState();
    _ctrl.subscribeToConversations();
  }

  @override
  void dispose() {
    // Do NOT call unsubscribeFromConversations here — MessagesPage sits inside
    // MainScreen's persistent BottomNavigationBar, so it should stay live.
    // If you navigate away entirely (sign-out), handle cleanup in the auth
    // listener instead.
    super.dispose();
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
        listenable: _ctrl,
        builder: (context, _) {
          if (_ctrl.conversationsLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_ctrl.conversationsError != null) {
            return _CenterNote(_ctrl.conversationsError!);
          }
          if (_ctrl.conversations.isEmpty) return _emptyState();

          return ListView.builder(
            padding: const EdgeInsets.only(top: 12, bottom: 24),
            itemCount: _ctrl.conversations.length,
            itemBuilder: (context, i) {
              final conv = _ctrl.conversations[i];
              final myUid = _ctrl.currentUid ?? '';
              final otherName = conv.otherName(myUid);
              final unread = conv.unreadFor(myUid);

              return _ConversationTile(
                name: otherName,
                lastMessage: conv.lastMessage.isEmpty
                    ? 'Say hi to start the conversation'
                    : conv.lastMessage,
                time: conv.lastMessageAt != null
                    ? DateFormat.jm().format(conv.lastMessageAt!)
                    : '',
                unreadCount: unread,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChatDetailPage(
                      otherUid: conv.otherUid(myUid),
                      otherName: otherName,
                    ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Conversation list tile
// ─────────────────────────────────────────────────────────────────────────────

class _ConversationTile extends StatelessWidget {
  final String name;
  final String lastMessage;
  final String time;
  final int unreadCount;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.unreadCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasUnread = unreadCount > 0;
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
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            hasUnread ? FontWeight.w800 : FontWeight.w700,
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
                        fontWeight:
                            hasUnread ? FontWeight.w600 : FontWeight.w400,
                        color: hasUnread
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
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
                      style: TextStyle(
                        fontSize: 12,
                        color: hasUnread
                            ? AppColors.brandAccent
                            : AppColors.textTertiary,
                        fontWeight:
                            hasUnread ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  if (hasUnread) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brandAccent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
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

// ─────────────────────────────────────────────────────────────────────────────
// New message picker — choose a group member to DM
// ─────────────────────────────────────────────────────────────────────────────

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
    final myUid = MessagesController.instance.currentUid;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('New Message')),
      body: StreamBuilder(
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
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: groups.map((g) {
              final groupName = (g.data()['name'] ?? 'Group') as String;
              return _GroupMembersSection(
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
  final String groupId;
  final String groupName;
  final String? myUid;
  final ValueChanged<_Member> onPick;

  const _GroupMembersSection({
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
        StreamBuilder(
          stream: FirestoreService.instance.streamGroupMembers(groupId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox.shrink();
            final members =
                snapshot.data!.docs.where((m) => m.id != myUid).toList();
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

// ─────────────────────────────────────────────────────────────────────────────
// Chat detail page
// ─────────────────────────────────────────────────────────────────────────────

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
  final MessagesController _ctrl = MessagesController.instance;
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _ctrl.openChat(otherUid: widget.otherUid, otherName: widget.otherName);
    _ctrl.addListener(_onControllerUpdate);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onControllerUpdate);
    _ctrl.closeChat();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onControllerUpdate() {
    // Auto-scroll to the bottom whenever new messages arrive.
    if (_ctrl.activeMessages.isNotEmpty) {
      _scrollToBottom();
    }
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

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    await _ctrl.sendMessage(
      otherUid: widget.otherUid,
      otherName: widget.otherName,
      text: text,
    );
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
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
      body: ListenableBuilder(
        listenable: _ctrl,
        builder: (context, _) {
          return Column(
            children: [
              // Error banner
              if (_ctrl.messagesError != null)
                _ErrorBanner(
                  message: _ctrl.messagesError!,
                  onDismiss: _ctrl.clearError,
                ),
              Expanded(child: _buildMessageList()),
              _inputBar(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMessageList() {
    if (_ctrl.messagesLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final msgs = _ctrl.activeMessages;
    if (msgs.isEmpty) return _emptyState();

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: msgs.length,
      itemBuilder: (context, i) {
        final msg = msgs[i];
        final isMe = msg.senderId == _ctrl.currentUid;
        return _bubble(
          text: msg.isDeleted ? 'This message was deleted' : msg.text,
          isUser: isMe,
          isDeleted: msg.isDeleted,
          time: msg.timestamp,
          messageId: msg.id,
          convId: _ctrl.activeChatConvId ?? '',
          senderId: msg.senderId,
        );
      },
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

  Widget _bubble({
    required String text,
    required bool isUser,
    required bool isDeleted,
    required DateTime? time,
    required String messageId,
    required String convId,
    required String senderId,
  }) {
    return GestureDetector(
      // Long-press to delete (sender only, non-deleted messages)
      onLongPress: isUser && !isDeleted && convId.isNotEmpty
          ? () => _confirmDelete(convId, messageId)
          : null,
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72,
          ),
          decoration: BoxDecoration(
            gradient: isUser && !isDeleted
                ? const LinearGradient(
                    colors: [AppColors.brandGreen, AppColors.brandDark],
                  )
                : null,
            color: isUser && !isDeleted ? null : AppColors.surface,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isUser ? 18 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 18),
            ),
            boxShadow: isUser ? null : kCardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: TextStyle(
                  color: isDeleted
                      ? AppColors.textTertiary
                      : (isUser ? Colors.white : AppColors.textPrimary),
                  fontSize: 15,
                  height: 1.3,
                  fontStyle:
                      isDeleted ? FontStyle.italic : FontStyle.normal,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                time != null ? DateFormat.jm().format(time) : 'now',
                style: TextStyle(
                  fontSize: 10.5,
                  color: isUser ? Colors.white70 : AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.15, end: 0);
  }

  Future<void> _confirmDelete(String convId, String messageId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete message'),
        content: const Text('This message will be marked as deleted for everyone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _ctrl.deleteMessage(convId: convId, messageId: messageId);
    }
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
              enabled: !_ctrl.isSending,
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
            onTap: _ctrl.isSending ? null : _send,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: _ctrl.isSending
                    ? null
                    : const LinearGradient(
                        colors: [AppColors.brandAccent, AppColors.brandDark],
                      ),
                color: _ctrl.isSending ? AppColors.divider : null,
                shape: BoxShape.circle,
              ),
              child: _ctrl.isSending
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.brandGreen,
                      ),
                    )
                  : const Icon(
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

// ─────────────────────────────────────────────────────────────────────────────
// Shared helper widgets
// ─────────────────────────────────────────────────────────────────────────────

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

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _ErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.danger.withAlpha(20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.danger, fontSize: 13),
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close, size: 18, color: AppColors.danger),
          ),
        ],
      ),
    );
  }
}
