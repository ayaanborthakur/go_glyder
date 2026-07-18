// lib/models/chat_message.dart
//
// Typed model for a single message document stored at
// conversations/{convId}/messages/{msgId} in Firestore.

import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  /// The Firestore document ID.
  final String id;

  /// UID of the user who sent this message.
  final String senderId;

  /// Plain-text message body (will be ciphertext once E2E is added).
  final String text;

  /// Server-side timestamp when the message was written.
  final DateTime? timestamp;

  /// Soft-delete flag. When true the message should be rendered as
  /// "This message was deleted" rather than showing [text].
  final bool isDeleted;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.isDeleted = false,
  });

  /// Builds a [ChatMessage] from a Firestore document snapshot.
  factory ChatMessage.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    final ts = d['timestamp'];
    return ChatMessage(
      id: doc.id,
      senderId: (d['senderId'] as String?) ?? '',
      text: (d['text'] as String?) ?? '',
      timestamp: ts is Timestamp ? ts.toDate() : null,
      isDeleted: (d['isDeleted'] as bool?) ?? false,
    );
  }

  /// Serialises this message for a Firestore write.
  /// [timestamp] is always set server-side; do not include it here.
  Map<String, dynamic> toFirestore() => {
        'senderId': senderId,
        'text': text,
        'isDeleted': isDeleted,
        'timestamp': FieldValue.serverTimestamp(),
      };
}
