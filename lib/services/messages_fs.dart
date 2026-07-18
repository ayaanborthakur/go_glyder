// lib/services/messages_fs.dart
//
// MessagingService — the single source of truth for all Firestore I/O related
// to direct messages. No UI imports, no BuildContext; this layer only knows
// about Firebase and the two typed models (Conversation, ChatMessage).
//
// Callers should go through MessagesController (messages_logic.dart) rather
// than using this service directly from a widget.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:go_glyder/models/chat_message.dart';
import 'package:go_glyder/models/conversation.dart';

/// Thrown by messaging operations with a user-readable message.
class MessagingException implements Exception {
  final String message;
  const MessagingException(this.message);
  @override
  String toString() => message;
}

class MessagingService {
  MessagingService._internal();
  static final MessagingService instance = MessagingService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ---------------------------------------------------------------------------
  // Identity helpers
  // ---------------------------------------------------------------------------

  /// UID of the currently signed-in user, or null if not signed in.
  String? get currentUid => FirebaseAuth.instance.currentUser?.uid;

  String _myName() {
    final me = FirebaseAuth.instance.currentUser;
    return me?.displayName ?? me?.email?.split('@').first ?? 'Me';
  }

  // ---------------------------------------------------------------------------
  // Firestore references
  // ---------------------------------------------------------------------------

  CollectionReference<Map<String, dynamic>> get _conversations =>
      _db.collection('conversations');

  CollectionReference<Map<String, dynamic>> _messages(String convId) =>
      _conversations.doc(convId).collection('messages');

  // ---------------------------------------------------------------------------
  // Conversation ID
  // ---------------------------------------------------------------------------

  /// Deterministic conversation ID shared by [currentUid] and [otherUid].
  /// Produces the same string regardless of which participant calls it first.
  String conversationIdFor(String otherUid) {
    final ids = [currentUid ?? '', otherUid]..sort();
    return ids.join('_');
  }

  // ---------------------------------------------------------------------------
  // Streams — read
  // ---------------------------------------------------------------------------

  /// All conversations the current user participates in, sorted by most-recent
  /// message descending. Emits an empty list while not signed in.
  Stream<List<Conversation>> streamMyConversations() {
    final uid = currentUid;
    if (uid == null) return const Stream.empty();

    return _conversations
        .where('participants', arrayContains: uid)
        .snapshots()
        .map((qs) {
      final docs = qs.docs
          .map(Conversation.fromFirestore)
          .toList()
        ..sort((a, b) {
          final ta = a.lastMessageAt?.millisecondsSinceEpoch ?? 0;
          final tb = b.lastMessageAt?.millisecondsSinceEpoch ?? 0;
          return tb.compareTo(ta);
        });
      return docs;
    });
  }

  /// All messages in [convId] ordered by timestamp ascending.
  Stream<List<ChatMessage>> streamConversationMessages(String convId) {
    return _messages(convId)
        .orderBy('timestamp')
        .snapshots()
        .map((qs) => qs.docs.map(ChatMessage.fromFirestore).toList());
  }

  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------

  /// Ensures the conversation shell document exists for the pair
  /// ([currentUid], [otherUid]). Safe to call repeatedly — uses merge so it
  /// never overwrites an existing conversation.
  ///
  /// Returns the conversation ID.
  Future<String> ensureConversation({
    required String otherUid,
    required String otherName,
  }) async {
    final uid = currentUid;
    if (uid == null) throw const MessagingException('You must be signed in.');

    final convId = conversationIdFor(otherUid);
    await _conversations.doc(convId).set({
      'participants': [uid, otherUid],
      'names': {uid: _myName(), otherUid: otherName},
      'lastMessage': '',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'unreadCount': {uid: 0, otherUid: 0},
    }, SetOptions(merge: true));

    return convId;
  }

  /// Sends [text] from the current user to [otherUid].
  ///
  /// Uses a Firestore batch so the conversation-shell update and the new
  /// message document are written atomically.
  Future<void> sendMessage({
    required String otherUid,
    required String otherName,
    required String text,
  }) async {
    final uid = currentUid;
    if (uid == null) throw const MessagingException('You must be signed in.');

    final trimmed = text.trim();
    if (trimmed.isEmpty) throw const MessagingException('Message cannot be empty.');

    final convId = conversationIdFor(otherUid);
    final convRef = _conversations.doc(convId);
    final msgRef = _messages(convId).doc(); // auto-ID

    final batch = _db.batch();

    // Upsert the conversation shell: lock participants on first create via
    // the Firestore security rule; subsequent updates only touch the
    // whitelisted fields (lastMessage, lastMessageAt, unreadCount).
    batch.set(
      convRef,
      {
        'participants': [uid, otherUid],
        'names': {uid: _myName(), otherUid: otherName},
        'lastMessage': trimmed,
        'lastMessageAt': FieldValue.serverTimestamp(),
        // Increment recipient's unread count; reset sender's to 0 on open.
        'unreadCount': {otherUid: FieldValue.increment(1)},
      },
      SetOptions(merge: true),
    );

    // Write the message document.
    batch.set(
      msgRef,
      ChatMessage(
        id: msgRef.id,
        senderId: uid,
        text: trimmed,
        timestamp: null, // overwritten by toFirestore() → serverTimestamp
      ).toFirestore(),
    );

    await batch.commit();
  }

  /// Resets the unread count for [currentUid] in [convId] to zero.
  /// Called when the user opens a chat thread.
  Future<void> markConversationRead(String convId) async {
    final uid = currentUid;
    if (uid == null) return;

    await _conversations.doc(convId).set(
      {'unreadCount': {uid: 0}},
      SetOptions(merge: true),
    );
  }

  /// Soft-deletes a message by setting `isDeleted = true`.
  /// Only the original sender may do this (enforced by the security rule).
  Future<void> deleteMessage({
    required String convId,
    required String messageId,
  }) async {
    if (currentUid == null) {
      throw const MessagingException('You must be signed in.');
    }
    await _messages(convId).doc(messageId).update({'isDeleted': true});
  }
}
