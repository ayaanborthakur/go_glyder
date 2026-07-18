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

  /// Stream a user's profile (for a profile screen).
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamUserProfile(String uid) {
    return _users.doc(uid).snapshots();
  }

  /// Sets the signed-in user's role (parent / staff / admin).
  Future<void> setUserRole(String role) {
    final uid = _uid;
    if (uid == null) return Future.value();
    return _users.doc(uid).set({'role': role}, SetOptions(merge: true));
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
    required String schoolName,
    required String description,
    String category = 'general',
    String icon = 'sun',
    String? pickupArea,
  }) async {
    final uid = _uid;
    if (uid == null) throw GroupException('You must be signed in.');

    final joinCode = await _uniqueJoinCode();
    final groupRef = _groups.doc();
    await groupRef.set({
      'name': name,
      'schoolName': schoolName,
      'description': description,
      'category': category,
      'icon': icon,
      'pickupArea': pickupArea ?? '',
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
  // Carpool trips + seat requests (posting & matching), scoped to a group
  // ---------------------------------------------------------------------
  CollectionReference<Map<String, dynamic>> _trips(String groupId) =>
      _groups.doc(groupId).collection('trips');

  CollectionReference<Map<String, dynamic>> _tripRequests(
    String groupId,
    String tripId,
  ) => _trips(groupId).doc(tripId).collection('requests');

  Stream<QuerySnapshot<Map<String, dynamic>>> streamGroupTrips(String groupId) {
    return _trips(groupId).orderBy('date').snapshots();
  }

  Future<String> createTrip({
    required String groupId,
    required String origin,
    required String destination,
    required DateTime date,
    required String time,
    required int seats,
    double distanceMiles = 0,
    String notes = '',
  }) async {
    final uid = _uid;
    if (uid == null) throw GroupException('You must be signed in.');
    final me = FirebaseAuth.instance.currentUser;
    final driverName =
        me?.displayName ?? me?.email?.split('@').first ?? 'Driver';
    final ref = await _trips(groupId).add({
      'driverId': uid,
      'driverName': driverName,
      'origin': origin,
      'destination': destination,
      'date': Timestamp.fromDate(date),
      'time': time,
      'seatsTotal': seats,
      'seatsTaken': 0,
      'riders': <String>[],
      // One-way distance; each accepted rider banks this many carbon miles
      // (and so does the driver, for carpooling someone).
      'distanceMiles': distanceMiles,
      'notes': notes,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> cancelTrip(String groupId, String tripId) {
    return _trips(groupId).doc(tripId).update({'status': 'cancelled'});
  }

  /// A rider asks the driver for a seat (creates a pending request).
  Future<void> requestSeat(String groupId, String tripId) async {
    final uid = _uid;
    if (uid == null) throw GroupException('You must be signed in.');
    final me = FirebaseAuth.instance.currentUser;
    final riderName =
        me?.displayName ?? me?.email?.split('@').first ?? 'Rider';
    await _tripRequests(groupId, tripId).doc(uid).set({
      'riderId': uid,
      'riderName': riderName,
      'status': 'pending',
      'requestedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamTripRequests(
    String groupId,
    String tripId,
  ) {
    return _tripRequests(groupId, tripId).orderBy('requestedAt').snapshots();
  }

  /// The current user's own request on a trip (to show their status).
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamMyTripRequest(
    String groupId,
    String tripId,
  ) {
    return _tripRequests(groupId, tripId).doc(_uid ?? 'anon').snapshots();
  }

  /// Driver accepts or declines a request. Accepting fills a seat atomically
  /// (and flips the trip to "full" when the last seat goes).
  Future<void> respondToRequest({
    required String groupId,
    required String tripId,
    required String riderId,
    required bool accept,
  }) async {
    final tripRef = _trips(groupId).doc(tripId);
    final reqRef = _tripRequests(groupId, tripId).doc(riderId);

    if (!accept) {
      await reqRef.update({'status': 'declined'});
      return;
    }

    await _db.runTransaction((tx) async {
      final trip = (await tx.get(tripRef)).data() ?? {};
      final total = (trip['seatsTotal'] ?? 0) as int;
      final taken = (trip['seatsTaken'] ?? 0) as int;
      if (taken >= total) throw GroupException('This ride is already full.');

      tx.update(reqRef, {'status': 'accepted'});
      tx.update(tripRef, {
        'seatsTaken': taken + 1,
        'riders': FieldValue.arrayUnion([riderId]),
        'status': (taken + 1 >= total) ? 'full' : 'open',
      });

      // Bank carbon miles: the passenger avoided driving this distance, and
      // the driver gets credit for carpooling them. Both accrue the miles.
      final miles = ((trip['distanceMiles'] ?? 0) as num).toDouble();
      final driverId = trip['driverId'] as String?;
      if (miles > 0) {
        tx.set(_users.doc(riderId), {
          'carbonMiles': FieldValue.increment(miles),
        }, SetOptions(merge: true));
        if (driverId != null) {
          tx.set(_users.doc(driverId), {
            'carbonMiles': FieldValue.increment(miles),
          }, SetOptions(merge: true));
        }
      }
    });
  }

  // ---------------------------------------------------------------------
  // Direct conversations — real two-way messaging. One shared doc per pair
  // of users (id = both uids sorted), so BOTH participants read/write the
  // same thread. Supersedes the per-user `contacts` methods above.
  // ---------------------------------------------------------------------
  String? get currentUid => _uid;

  CollectionReference<Map<String, dynamic>> get _conversations =>
      _db.collection('conversations');

  /// Deterministic conversation id shared by the current user and [otherUid].
  String conversationIdFor(String otherUid) {
    final ids = [_uid ?? '', otherUid]..sort();
    return ids.join('_');
  }

  /// The current user's conversations. Sorted client-side (by lastMessageAt)
  /// so no composite Firestore index is required. Empty for a new account.
  Stream<QuerySnapshot<Map<String, dynamic>>> streamMyConversations() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _conversations.where('participants', arrayContains: uid).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamConversationMessages(
    String conversationId,
  ) {
    return _conversations
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp')
        .snapshots();
  }

  /// Creates the conversation shell if needed so an empty chat can be opened
  /// before the first message. Returns the conversation id.
  Future<String> ensureConversation({
    required String otherUid,
    required String otherName,
  }) async {
    final uid = _uid;
    if (uid == null) throw GroupException('You must be signed in.');
    final convId = conversationIdFor(otherUid);
    await _conversations.doc(convId).set({
      'participants': [uid, otherUid],
      'names': {uid: _myName(), otherUid: otherName},
      'lastMessageAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return convId;
  }

  Future<void> sendDirectMessage({
    required String otherUid,
    required String otherName,
    required String text,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    final convRef = _conversations.doc(conversationIdFor(otherUid));
    await convRef.set({
      'participants': [uid, otherUid],
      'names': {uid: _myName(), otherUid: otherName},
      'lastMessage': text,
      'lastMessageAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await convRef.collection('messages').add({
      'senderId': uid,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  String _myName() {
    final me = FirebaseAuth.instance.currentUser;
    return me?.displayName ?? me?.email?.split('@').first ?? 'Me';
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
