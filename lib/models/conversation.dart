// lib/models/conversation.dart
//
// Typed model for a direct-message conversation document stored at
// conversations/{convId} in Firestore.

import 'package:cloud_firestore/cloud_firestore.dart';

class Conversation {
  /// The Firestore document ID (`uid1_uid2`, uids sorted ascending).
  final String id;

  /// The two participant UIDs.
  final List<String> participants;

  /// Display names keyed by UID: `{uid: displayName}`.
  final Map<String, String> names;

  /// Preview of the most recent message.
  final String lastMessage;

  /// Server-side timestamp of the most recent message.
  final DateTime? lastMessageAt;

  /// Unread message counts per participant: `{uid: count}`.
  /// Incremented on send for the *recipient*, reset to 0 on open by that user.
  final Map<String, int> unreadCount;

  const Conversation({
    required this.id,
    required this.participants,
    required this.names,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unreadCount,
  });

  /// Builds a [Conversation] from a Firestore document snapshot.
  factory Conversation.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};

    final rawParticipants = d['participants'];
    final participants = rawParticipants is List
        ? List<String>.from(rawParticipants)
        : <String>[];

    final rawNames = d['names'];
    final names = rawNames is Map
        ? Map<String, String>.from(
            rawNames.map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')),
          )
        : <String, String>{};

    final rawUnread = d['unreadCount'];
    final unreadCount = rawUnread is Map
        ? Map<String, int>.from(
            rawUnread.map(
              (k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0),
            ),
          )
        : <String, int>{};

    final ts = d['lastMessageAt'];
    final lastMessageAt = ts is Timestamp ? ts.toDate() : null;

    return Conversation(
      id: doc.id,
      participants: participants,
      names: names,
      lastMessage: (d['lastMessage'] as String?) ?? '',
      lastMessageAt: lastMessageAt,
      unreadCount: unreadCount,
    );
  }

  /// Convenience: given the current user's UID, returns the other participant's
  /// UID. Returns an empty string if the conversation is malformed.
  String otherUid(String myUid) =>
      participants.firstWhere((p) => p != myUid, orElse: () => '');

  /// Convenience: display name of the other participant.
  String otherName(String myUid) => names[otherUid(myUid)] ?? 'Member';

  /// Unread count for a specific user.
  int unreadFor(String uid) => unreadCount[uid] ?? 0;
}
