// lib/services/firestore_service.dart
//
// Single place all Firestore reads/writes go through. Every feature page
// should use this instead of talking to FirebaseFirestore.instance directly,
// so collection names/paths only live in one spot.

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Thrown by group actions with a user-friendly message.
class GroupException implements Exception {
  final String message;
  GroupException(this.message);
  @override
  String toString() => message;
}

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

  // ---------------------------------------------------------------------
  // Groups & membership (join via code / QR)
  // ---------------------------------------------------------------------

  // The user's own list of joined groups (denormalized for a fast read).
  CollectionReference<Map<String, dynamic>> _myGroups(String uid) =>
      _users.doc(uid).collection('myGroups');

  // The roster of members inside a group.
  CollectionReference<Map<String, dynamic>> _members(String groupId) =>
      _groups.doc(groupId).collection('members');

  /// Live list of the current user's groups (empty for a new account).
  Stream<QuerySnapshot<Map<String, dynamic>>> streamMyGroups() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _myGroups(uid).orderBy('joinedAt', descending: true).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamGroupMembers(
    String groupId,
  ) {
    return _members(groupId).orderBy('displayName').snapshots();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getGroup(String groupId) {
    return _groups.doc(groupId).get();
  }

  /// Creates a group, generates a unique join code, and adds the creator as
  /// the first member. Returns the new group's id.
  Future<String> createGroup({
    required String name,
    required String description,
    String icon = 'sun',
  }) async {
    final uid = _uid;
    if (uid == null) throw GroupException('You must be signed in.');

    final joinCode = await _uniqueJoinCode();
    final groupRef = _groups.doc();
    await groupRef.set({
      'name': name,
      'description': description,
      'icon': icon,
      'joinCode': joinCode,
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'members': 1,
    });
    await _writeMembership(groupRef.id, uid, name, icon);
    return groupRef.id;
  }

  /// Finds the group with [code] and joins it. Returns the group's name.
  /// Throws [GroupException] if there's no match or the user is already in it.
  Future<String> joinGroupByCode(String code) async {
    final uid = _uid;
    if (uid == null) throw GroupException('You must be signed in.');

    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) throw GroupException('Enter a join code.');

    final query = await _groups
        .where('joinCode', isEqualTo: normalized)
        .limit(1)
        .get();
    if (query.docs.isEmpty) {
      throw GroupException('No group found for code "$normalized".');
    }

    final groupDoc = query.docs.first;
    final already = await _members(groupDoc.id).doc(uid).get();
    if (already.exists) throw GroupException('You\'re already in this group.');

    final data = groupDoc.data();
    await _writeMembership(
      groupDoc.id,
      uid,
      (data['name'] ?? '') as String,
      (data['icon'] ?? 'sun') as String,
    );
    await _groups.doc(groupDoc.id).update({
      'members': FieldValue.increment(1),
    });
    return (data['name'] ?? 'the group') as String;
  }

  Future<void> leaveGroup(String groupId) async {
    final uid = _uid;
    if (uid == null) return;
    await _members(groupId).doc(uid).delete();
    await _myGroups(uid).doc(groupId).delete();
    await _groups.doc(groupId).update({'members': FieldValue.increment(-1)});
  }

  // Writes both the group's roster entry and the user's myGroups entry.
  Future<void> _writeMembership(
    String groupId,
    String uid,
    String name,
    String icon,
  ) async {
    final me = FirebaseAuth.instance.currentUser;
    final displayName =
        me?.displayName ?? me?.email?.split('@').first ?? 'Member';
    await _members(groupId).doc(uid).set({
      'displayName': displayName,
      'email': me?.email,
      'joinedAt': FieldValue.serverTimestamp(),
    });
    await _myGroups(uid).doc(groupId).set({
      'name': name,
      'icon': icon,
      'joinedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String> _uniqueJoinCode() async {
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = _randomCode();
      final existing = await _groups
          .where('joinCode', isEqualTo: code)
          .limit(1)
          .get();
      if (existing.docs.isEmpty) return code;
    }
    return _randomCode();
  }

  String _randomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no ambiguous 0/O/1/I
    final rnd = Random.secure();
    return List.generate(6, (_) => chars[rnd.nextInt(chars.length)]).join();
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
