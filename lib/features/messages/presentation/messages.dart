import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import 'package:go_glyder/core/theme.dart';

class Message {
  final String sender;
  final String text;
  final DateTime timestamp;
  final bool isUser;

  Message({
    required this.sender,
    required this.text,
    required this.timestamp,
    required this.isUser,
  });
}

class Contact {
  final String name;
  final bool isAvailable;
  final List<Message> messages;
  String lastMessage;

  Contact({
    required this.name,
    required this.isAvailable,
    required this.messages,
    required this.lastMessage,
  });
}

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
  final bool showStatus;
  final bool isOnline;

  const Avatar({
    super.key,
    required this.name,
    this.size = 52,
    this.showStatus = false,
    this.isOnline = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Container(
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
          ),
          if (showStatus)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: size * 0.28,
                height: size * 0.28,
                decoration: BoxDecoration(
                  color: isOnline ? AppColors.success : AppColors.textTertiary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
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
  late List<Contact> _contacts;
  late List<Contact> _suggested;

  @override
  void initState() {
    super.initState();
    _contacts = [
      Contact(
        name: 'John',
        isAvailable: true,
        lastMessage: 'Are you joining the carpool tomorrow?',
        messages: [
          Message(
            sender: 'John',
            text: 'Are you joining the carpool tomorrow?',
            timestamp: DateTime.now().subtract(const Duration(hours: 2)),
            isUser: false,
          ),
        ],
      ),
      Contact(
        name: 'Emma',
        isAvailable: true,
        lastMessage: 'See you tomorrow!',
        messages: [
          Message(
            sender: 'Emma',
            text: 'See you tomorrow!',
            timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
            isUser: false,
          ),
        ],
      ),
      Contact(
        name: 'Mike',
        isAvailable: true,
        lastMessage: 'Can you pick me up at 8 AM?',
        messages: [
          Message(
            sender: 'Mike',
            text: 'Can you pick me up at 8 AM?',
            timestamp: DateTime.now().subtract(const Duration(hours: 5)),
            isUser: false,
          ),
        ],
      ),
      Contact(
        name: 'Sarah',
        isAvailable: false,
        lastMessage: 'Thanks for the ride last week!',
        messages: [
          Message(
            sender: 'Sarah',
            text: 'Thanks for the ride last week!',
            timestamp: DateTime.now().subtract(const Duration(days: 1)),
            isUser: false,
          ),
        ],
      ),
      Contact(
        name: 'Alex',
        isAvailable: false,
        lastMessage: 'Running late, will be there soon',
        messages: [
          Message(
            sender: 'Alex',
            text: 'Running late, will be there soon',
            timestamp: DateTime.now().subtract(const Duration(hours: 3)),
            isUser: false,
          ),
        ],
      ),
    ];

    _suggested = [
      Contact(name: 'David', isAvailable: true, lastMessage: '', messages: []),
      Contact(name: 'Lisa', isAvailable: true, lastMessage: '', messages: []),
      Contact(name: 'James', isAvailable: false, lastMessage: '', messages: []),
      Contact(name: 'Priya', isAvailable: true, lastMessage: '', messages: []),
    ];
  }

  void _openChat(Contact contact) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChatDetailPage(contact: contact)),
    );
  }

  void _addSuggested(Contact c) {
    setState(() {
      _suggested.remove(c);
      _contacts.insert(
        0,
        Contact(
          name: c.name,
          isAvailable: c.isAvailable,
          lastMessage: 'Say hi to start the conversation',
          messages: [],
        ),
      );
    });
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
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 12, bottom: 24),
        children: [
          if (_suggested.isNotEmpty) _buildSuggested(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Text(
              'Recent Chats',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ..._contacts.asMap().entries.map((e) {
            return _ConversationTile(
              contact: e.value,
              onTap: () => _openChat(e.value),
            ).animate(delay: (60 * e.key).ms).fadeIn(duration: 350.ms).slideX(
              begin: 0.08,
              end: 0,
              curve: Curves.easeOut,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSuggested() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: Text(
            'Suggested Riders',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _suggested.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final c = _suggested[i];
              return Container(
                width: 120,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.lgAll,
                  boxShadow: kCardShadow,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Avatar(
                      name: c.name,
                      size: 48,
                      showStatus: true,
                      isOnline: c.isAvailable,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      c.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _addSuggested(c),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.brandTint,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Add',
                          style: TextStyle(
                            color: AppColors.brandDark,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate(delay: (80 * i).ms).fadeIn(duration: 350.ms).slideY(
                begin: 0.2,
                end: 0,
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final Contact contact;
  final VoidCallback onTap;

  const _ConversationTile({required this.contact, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final last = contact.messages.isNotEmpty
        ? contact.messages.last
        : null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              Avatar(
                name: contact.name,
                size: 54,
                showStatus: true,
                isOnline: contact.isAvailable,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      contact.lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (last != null)
                Text(
                  DateFormat.jm().format(last.timestamp),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChatDetailPage extends StatefulWidget {
  final Contact contact;
  const ChatDetailPage({super.key, required this.contact});

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      widget.contact.messages.add(
        Message(
          sender: 'You',
          text: text,
          timestamp: DateTime.now(),
          isUser: true,
        ),
      );
      widget.contact.lastMessage = text;
    });
    _controller.clear();
    _scrollToBottom();

    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      final reply = _reply(text);
      setState(() {
        widget.contact.messages.add(
          Message(
            sender: widget.contact.name,
            text: reply,
            timestamp: DateTime.now(),
            isUser: false,
          ),
        );
        widget.contact.lastMessage = reply;
      });
      _scrollToBottom();
    });
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

  String _reply(String msg) {
    final m = msg.toLowerCase();
    bool has(List<String> words) => words.any(m.contains);
    if (has(['hi', 'hey', 'hello'])) return 'Hey! How are you doing?';
    if (has(['join', 'coming', 'in?', 'you in'])) return 'Yeah, count me in!';
    if (has(['time', 'when', 'tomorrow', 'today', 'morning'])) {
      return 'What time works for you?';
    }
    if (has(['pick', 'where', 'location', 'address', 'meet'])) {
      return 'Sure! Where should I pick you up?';
    }
    if (has(['thanks', 'thank', 'appreciate'])) return 'Anytime! Happy to help.';
    return 'Sounds good! 👍';
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.contact;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Avatar(
              name: c.name,
              size: 38,
              showStatus: true,
              isOnline: c.isAvailable,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  c.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  c.isAvailable ? 'Active now' : 'Offline',
                  style: TextStyle(
                    fontSize: 12,
                    color: c.isAvailable
                        ? AppColors.brandAccent
                        : Colors.white70,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: c.messages.isEmpty
                ? _emptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: c.messages.length,
                    itemBuilder: (context, i) => _bubble(c.messages[i]),
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
          Avatar(name: widget.contact.name, size: 72),
          const SizedBox(height: 16),
          Text(
            widget.contact.name,
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

  Widget _bubble(Message m) {
    final isUser = m.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        decoration: BoxDecoration(
          gradient: isUser
              ? const LinearGradient(
                  colors: [AppColors.brandGreen, AppColors.brandDark],
                )
              : null,
          color: isUser ? null : AppColors.surface,
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
              m.text,
              style: TextStyle(
                color: isUser ? Colors.white : AppColors.textPrimary,
                fontSize: 15,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              DateFormat.jm().format(m.timestamp),
              style: TextStyle(
                fontSize: 10.5,
                color: isUser ? Colors.white70 : AppColors.textTertiary,
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
              controller: _controller,
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
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}
