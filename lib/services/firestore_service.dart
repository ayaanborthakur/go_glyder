// lib/services/firestore_service.dart
//
// Single place all Firestore reads/writes go through. Every feature page
// should use this instead of talking to FirebaseFirestore.instance directly,
// so collection names/paths only live in one spot.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  FirestoreService._internal();
  static final FirestoreService instance = FirestoreService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ---------------------------------------------------------------------
  // Users / profiles
  // ---------------------------------------------------------------------
  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  Future<void> createUserProfile({required String uid, required String email}) {
    return _users.doc(uid).set({
      'email': email,
      'displayName': email.split('@').first,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final snap = await _users.doc(uid).get();
    return snap.data();
  }

  // ---------------------------------------------------------------------
  // Community: carpool groups + feed posts
  // ---------------------------------------------------------------------
  CollectionReference<Map<String, dynamic>> get _groups =>
      _db.collection('carpoolGroups');

  CollectionReference<Map<String, dynamic>> get _posts =>
      _db.collection('communityPosts');

  Stream<QuerySnapshot<Map<String, dynamic>>> streamCarpoolGroups() {
    return _groups.orderBy('name').snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamCommunityPosts() {
    return _posts.orderBy('createdAt', descending: true).snapshots();
  }

  Future<void> createCommunityPost({
    required String author,
    required String content,
  }) {
    return _posts.add({
      'author': author,
      'content': content,
      'likes': 0,
      'comments': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'authorUid': _uid,
    });
  }

  Future<void> likePost(String postId) {
    return _posts.doc(postId).update({'likes': FieldValue.increment(1)});
  }

  Future<void> joinCarpoolGroup(String groupId) {
    return _groups.doc(groupId).update({'members': FieldValue.increment(1)});
  }

  // ---------------------------------------------------------------------
  // Calendar events
  // ---------------------------------------------------------------------
  CollectionReference<Map<String, dynamic>> get _events =>
      _db.collection('calendarEvents');

  Stream<QuerySnapshot<Map<String, dynamic>>> streamCalendarEvents() {
    return _events.orderBy('date').snapshots();
  }

  Future<void> createCalendarEvent({
    required String title,
    required String description,
    required DateTime date,
    required String time,
  }) {
    return _events.add({
      'title': title,
      'description': description,
      'date': Timestamp.fromDate(date),
      'time': time,
      'createdBy': _uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteCalendarEvent(String eventId) {
    return _events.doc(eventId).delete();
  }

  // ---------------------------------------------------------------------
  // Messages: one chat document per (current user, contact) pair, with a
  // `messages` subcollection ordered by timestamp.
  // ---------------------------------------------------------------------
  CollectionReference<Map<String, dynamic>> get _contacts => _uid == null
      ? _db.collection('users').doc('anonymous').collection('contacts')
      : _users.doc(_uid).collection('contacts');

  String _chatIdFor(String contactName) => contactName.toLowerCase();

  Stream<QuerySnapshot<Map<String, dynamic>>> streamContacts() {
    return _contacts.orderBy('lastMessageAt', descending: true).snapshots();
  }

  Future<void> upsertContact({
    required String name,
    required bool isAvailable,
    required String lastMessage,
  }) {
    return _contacts.doc(_chatIdFor(name)).set({
      'name': name,
      'isAvailable': isAvailable,
      'lastMessage': lastMessage,
      'lastMessageAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamMessages(
    String contactName,
  ) {
    return _contacts
        .doc(_chatIdFor(contactName))
        .collection('messages')
        .orderBy('timestamp')
        .snapshots();
  }

  Future<void> sendMessage({
    required String contactName,
    required String sender,
    required String text,
    required bool isUser,
  }) async {
    final chatRef = _contacts.doc(_chatIdFor(contactName));
    await chatRef.collection('messages').add({
      'sender': sender,
      'text': text,
      'isUser': isUser,
      'timestamp': FieldValue.serverTimestamp(),
    });
    await chatRef.set({
      'name': contactName,
      'lastMessage': text,
      'lastMessageAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
