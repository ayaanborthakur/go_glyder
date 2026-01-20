import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
  final String lastMessage;
  final String? profileImage;

  Contact({
    required this.name,
    required this.isAvailable,
    required this.messages,
    required this.lastMessage,
    this.profileImage,
  });
}

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final TextEditingController _messageController = TextEditingController();
  String _selectedContact = 'John';

  late List<Contact> _contacts;
  late List<Contact> _suggestedChats;

  @override
  void initState() {
    super.initState();
    _initializeContacts();
  }

  void _initializeContacts() {
    _contacts = [
      Contact(
        name: 'John',
        isAvailable: true,
        messages: [
          Message(
            sender: 'John',
            text: 'Are you joining the carpool tomorrow?',
            timestamp: DateTime.now().subtract(Duration(hours: 2)),
            isUser: false,
          ),
        ],
        lastMessage: 'Are you joining the carpool tomorrow?',
      ),
      Contact(
        name: 'Sarah',
        isAvailable: false,
        messages: [
          Message(
            sender: 'Sarah',
            text: 'Thanks for the ride last week!',
            timestamp: DateTime.now().subtract(Duration(days: 1)),
            isUser: false,
          ),
        ],
        lastMessage: 'Thanks for the ride last week!',
      ),
      Contact(
        name: 'Mike',
        isAvailable: true,
        messages: [
          Message(
            sender: 'Mike',
            text: 'Can you pick me up at 8 AM?',
            timestamp: DateTime.now().subtract(Duration(hours: 5)),
            isUser: false,
          ),
        ],
        lastMessage: 'Can you pick me up at 8 AM?',
      ),
      Contact(
        name: 'Emma',
        isAvailable: true,
        messages: [
          Message(
            sender: 'Emma',
            text: 'See you tomorrow!',
            timestamp: DateTime.now().subtract(Duration(minutes: 30)),
            isUser: false,
          ),
        ],
        lastMessage: 'See you tomorrow!',
      ),
      Contact(
        name: 'Alex',
        isAvailable: false,
        messages: [
          Message(
            sender: 'Alex',
            text: 'Running late, will be there soon',
            timestamp: DateTime.now().subtract(Duration(hours: 3)),
            isUser: false,
          ),
        ],
        lastMessage: 'Running late, will be there soon',
      ),
    ];

    _suggestedChats = [
      Contact(
        name: 'David',
        isAvailable: true,
        messages: [],
        lastMessage: 'New connection',
      ),
      Contact(
        name: 'Lisa',
        isAvailable: true,
        messages: [],
        lastMessage: 'Nearby rider',
      ),
      Contact(
        name: 'James',
        isAvailable: false,
        messages: [],
        lastMessage: 'Same route',
      ),
    ];
  }

  Contact _getSelectedContactObject() {
    return _contacts.firstWhere((c) => c.name == _selectedContact);
  }

  void _sendMessage() {
    if (_messageController.text.isEmpty) return;

    final contact = _getSelectedContactObject();
    final userMessage = _messageController.text;

    setState(() {
      contact.messages.add(
        Message(
          sender: 'You',
          text: userMessage,
          timestamp: DateTime.now(),
          isUser: true,
        ),
      );
    });

    _messageController.clear();

    Future.delayed(Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          contact.messages.add(
            Message(
              sender: _selectedContact,
              text: _generateContextualReply(userMessage, _selectedContact),
              timestamp: DateTime.now(),
              isUser: false,
            ),
          );
        });
      }
    });
  }

  void _addSuggestedChat(Contact suggested) {
    setState(() {
      _contacts.add(suggested);
      _suggestedChats.remove(suggested);
      _selectedContact = suggested.name;
    });
  }

  String _generateContextualReply(String userMessage, String contactName) {
    final messageLower = userMessage.toLowerCase();

    // Greeting responses
    if (_containsAny(messageLower, [
      'hi',
      'hello',
      'hey',
      'sup',
      'what\'s up',
    ])) {
      final greetings = [
        'Hey! How are you doing?',
        'Hi there! What\'s going on?',
        'Hey! Good to hear from you!',
        'What\'s up! How\'s it going?',
      ];
      return greetings[contactName.length % greetings.length];
    }

    // Question about availability/joining
    if (_containsAny(messageLower, [
      'join',
      'coming',
      'available',
      'free',
      'you in',
      'interested',
    ])) {
      final responses = [
        'Yeah, count me in!',
        'I\'m down for it!',
        'Absolutely, I\'m in!',
        'For sure! When is it?',
        'Sounds good to me!',
        'When are we doing this?',
      ];
      return responses[contactName.length % responses.length];
    }

    // Time/Schedule related
    if (_containsAny(messageLower, [
      'time',
      'when',
      'what time',
      'schedule',
      'tomorrow',
      'today',
      'morning',
      'evening',
      'am',
      'pm',
      'o\'clock',
    ])) {
      final responses = [
        'What time works for you?',
        'Let me check my schedule.',
        'I\'m flexible, whenever suits you.',
        'Morning or evening?',
        'Can we make it around 8?',
        'I\'m available most times.',
      ];
      return responses[contactName.length % responses.length];
    }

    // Pickup/Location related
    if (_containsAny(messageLower, [
      'pick',
      'pickup',
      'pick me',
      'location',
      'where',
      'address',
      'meet',
      'see you',
    ])) {
      final responses = [
        'Sure! Where should I pick you up?',
        'I can pick you up. What\'s the location?',
        'No problem! Send me the address.',
        'Cool, I\'ll be there!',
        'Where are you located?',
        'I\'ll come get you!',
      ];
      return responses[contactName.length % responses.length];
    }

    // Thanks/Gratitude
    if (_containsAny(messageLower, [
      'thanks',
      'thank you',
      'appreciate',
      'grateful',
      'ty',
      'thx',
    ])) {
      final responses = [
        'You\'re welcome! Anytime!',
        'No problem at all!',
        'Happy to help!',
        'My pleasure!',
        'Don\'t mention it!',
        'Glad I could help!',
      ];
      return responses[contactName.length % responses.length];
    }

    // Urgency/Emergency
    if (_containsAny(messageLower, [
      'urgent',
      'asap',
      'emergency',
      'hurry',
      'quick',
      'rush',
      'right now',
      'immediately',
    ])) {
      final responses = [
        'I\'ll be right there!',
        'On my way!',
        'I\'m coming now!',
        'No problem, leaving soon!',
        'I\'ll make it fast!',
      ];
      return responses[contactName.length % responses.length];
    }

    // Cancellation/Postponement
    if (_containsAny(messageLower, [
      'cancel',
      'postpone',
      'reschedule',
      'change',
      'later',
      'not today',
      'another time',
    ])) {
      final responses = [
        'No worries, we can reschedule.',
        'That\'s fine, let\'s plan for later.',
        'No problem at all!',
        'When would work better for you?',
        'All good, whenever you\'re ready.',
      ];
      return responses[contactName.length % responses.length];
    }

    // Cost/Payment related
    if (_containsAny(messageLower, [
      'cost',
      'price',
      'pay',
      'money',
      'gas',
      'fare',
      'split',
      'how much',
    ])) {
      final responses = [
        'We can split it 50/50.',
        'However you want to split it works for me.',
        'Don\'t worry about it!',
        'We can figure it out.',
        'Let\'s split the gas cost.',
      ];
      return responses[contactName.length % responses.length];
    }

    // Route/Direction related
    if (_containsAny(messageLower, [
      'route',
      'way',
      'direction',
      'path',
      'road',
      'highway',
      'freeway',
    ])) {
      final responses = [
        'I know a good route!',
        'Let\'s take the fastest way.',
        'I\'ll navigate, no worries.',
        'I know the traffic patterns well.',
        'Let me map it out.',
      ];
      return responses[contactName.length % responses.length];
    }

    // Confirmation responses
    if (_containsAny(messageLower, [
      'ok',
      'okay',
      'sure',
      'yep',
      'yes',
      'absolutely',
      'definitely',
      'for sure',
      'sounds good',
    ])) {
      final responses = [
        'Great! Looking forward to it!',
        'Awesome! See you then!',
        'Perfect!',
        'Let\'s do it!',
        'Sounds like a plan!',
      ];
      return responses[contactName.length % responses.length];
    }

    // Disagreement/Hesitation
    if (_containsAny(messageLower, [
      'no',
      'nope',
      'can\'t',
      'won\'t',
      'not',
      'maybe',
      'unsure',
      'i don\'t think',
    ])) {
      final responses = [
        'That\'s okay! Maybe another time.',
        'No problem, I understand.',
        'All good, whenever you\'re ready.',
        'Let me know if plans change!',
        'Maybe next time!',
      ];
      return responses[contactName.length % responses.length];
    }

    // Default contextual responses
    final defaultResponses = [
      'Sounds good!',
      'I hear you!',
      'Totally!',
      'For sure!',
      'Definitely!',
      'I agree!',
      'You\'re right!',
      'Exactly!',
    ];
    return defaultResponses[contactName.length % defaultResponses.length];
  }

  bool _containsAny(String text, List<String> keywords) {
    return keywords.any((keyword) => text.contains(keyword));
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    if (time.day == now.day &&
        time.month == now.month &&
        time.year == now.year) {
      return DateFormat('HH:mm').format(time);
    }
    return DateFormat('MMM dd').format(time);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Messages', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: Row(
        children: [
          Container(
            width: MediaQuery.of(context).size.width * 0.32,
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(
                right: BorderSide(color: Colors.grey[200]!, width: 1),
              ),
            ),
            child: _buildContactsList(),
          ),
          Expanded(child: _buildChatArea()),
        ],
      ),
    );
  }

  Widget _buildContactsList() {
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            separatorBuilder: (_, _) =>
                Divider(height: 1, color: Colors.grey[200]),
            itemCount: _contacts.length,
            itemBuilder: (context, index) {
              final contact = _contacts[index];
              final isSelected = contact.name == _selectedContact;
              return _buildContactTile(contact, isSelected);
            },
          ),
        ),
        if (_suggestedChats.isNotEmpty)
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey[200]!, width: 1),
              ),
            ),
            child: _buildSuggestedSection(),
          ),
      ],
    );
  }

  Widget _buildContactTile(Contact contact, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedContact = contact.name;
        });
      },
      child: Container(
        color: isSelected
            ? Color(0x1A007AFF)
            : Colors.transparent,
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _getAvatarColors(contact.name),
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      contact.name[0],
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: contact.isAvailable
                          ? Color(0xFF34C759)
                          : Color(0xFFFF3B30),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    contact.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(12, 16, 12, 8),
          child: Text(
            'Suggested Chats',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.grey[700],
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...List.generate(_suggestedChats.length, (index) {
          final suggested = _suggestedChats[index];
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0x1A007AFF),
                    Color(0x1A34C759),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!, width: 1),
              ),
              padding: EdgeInsets.all(10),
              child: Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _getAvatarColors(suggested.name),
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            suggested.name[0],
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: suggested.isAvailable
                                ? Color(0xFF34C759)
                                : Color(0xFFFF3B30),
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          suggested.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          suggested.lastMessage,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _addSuggestedChat(suggested),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Color(0xFF007AFF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Add',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        SizedBox(height: 12),
      ],
    );
  }

  Widget _buildChatArea() {
    final contact = _getSelectedContactObject();
    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Colors.grey[200]!, width: 1),
            ),
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _getAvatarColors(contact.name),
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        contact.name[0],
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: contact.isAvailable
                            ? Color(0xFF34C759)
                            : Color(0xFFFF3B30),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      contact.isAvailable ? '🟢 Available' : '🔴 Not available',
                      style: TextStyle(
                        color: contact.isAvailable
                            ? Color(0xFF34C759)
                            : Color(0xFFFF3B30),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            reverse: true,
            itemCount: contact.messages.length,
            itemBuilder: (context, index) {
              final message =
                  contact.messages[contact.messages.length - 1 - index];
              return _buildMessageBubble(message);
            },
          ),
        ),
        _buildInputArea(),
      ],
    );
  }

  Widget _buildMessageBubble(Message message) {
    final isUser = message.isUser;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) CircleAvatar(radius: 16, child: Text(message.sender[0])),
          SizedBox(width: 8),
          Column(
            crossAxisAlignment: isUser
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Container(
                constraints: BoxConstraints(maxWidth: 220),
                padding: EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                decoration: BoxDecoration(
                  gradient: isUser
                      ? LinearGradient(
                          colors: [Color(0xFF007AFF), Color(0xFF0051D5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : LinearGradient(
                          colors: [Colors.grey[300]!, Colors.grey[200]!],
                        ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(isUser ? 16 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),

                child: Text(
                  message.text,
                  style: TextStyle(
                    color: isUser ? Colors.white : Colors.black87,
                    fontSize: 15,
                    height: 1.3,
                  ),
                ),
              ),

              SizedBox(height: 4),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  _formatTime(message.timestamp),
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
              ),
            ],
          ),
          if (isUser) SizedBox(width: 8),
        ],
      ),

    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: TextStyle(color: Colors.grey[500]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Color(0xFF007AFF), width: 2),
                ),
                filled: true,
                fillColor: Colors.grey[50],
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF007AFF), Color(0xFF0051D5)],
              ),
              shape: BoxShape.circle,
            ),
            child: FloatingActionButton(
              mini: true,
              onPressed: _sendMessage,
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Icon(Icons.send, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  List<Color> _getAvatarColors(String name) {
    final colors = [
      [Color(0xFF007AFF), Color(0xFF0051D5)],
      [Color(0xFFFF3B30), Color(0xFFFF1744)],
      [Color(0xFF34C759), Color(0xFF00B341)],
      [Color(0xFFFF9500), Color(0xFFFF6B00)],
      [Color(0xFFAF52DE), Color(0xFF9933FF)],
      [Color(0xFF5AC8FA), Color(0xFF0076FF)],
      [Color(0xFFFFCC00), Color(0xFFFF9500)],
      [Color(0xFF4CD964), Color(0xFF34C759)],
    ];
    return colors[name.length % colors.length];
  }
}
