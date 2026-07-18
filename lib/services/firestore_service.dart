// lib/services/firestore_service.dart
//
// Single place all Firestore reads/writes go through. Every feature page
// should use this instead of talking to FirebaseFirestore.instance directly,
// so collection names/paths only live in one spot.
//
// Data model: Schools are the top-level scope. A user can belong to several
// (e.g. two kids at two schools). Every community group lives INSIDE a
// school (`schools/{schoolId}/groups/{groupId}`), and carpool trips live
// inside a group. There is no separate "join code" for schools or groups —
// both are open: schools are picked from a public list, groups are found by
// searching within a school. Only becoming a verified ADMIN of a school
// requires a secret code (see claimSchoolAdmin) — that's the one thing that
// actually needs to be un-fakeable.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Thrown by group/school actions with a user-friendly message.
class GroupException implements Exception {
  final String message;
  GroupException(this.message);
  @override
  String toString() => message;
}

class FirestoreService {
  FirestoreService._internal();
  static final FirestoreService instance = FirestoreService._internal();

  final FirebaseFirestore db = FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  String? get currentUid => _uid;

  // ---------------------------------------------------------------------
  // Users / profiles
  // ---------------------------------------------------------------------
  CollectionReference<Map<String, dynamic>> get _users =>
      db.collection('users');

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

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamUserProfile(String uid) {
    return _users.doc(uid).snapshots();
  }

  Future<void> setUserRole(String role) {
    final uid = _uid;
    if (uid == null) return Future.value();
    return _users.doc(uid).set({'role': role}, SetOptions(merge: true));
  }

  Future<void> updateUserProfile({String? displayName, String? bio}) {
    final uid = _uid;
    if (uid == null) return Future.value();
    final data = <String, dynamic>{};
    if (displayName != null) data['displayName'] = displayName;
    if (bio != null) data['bio'] = bio;
    if (data.isEmpty) return Future.value();
    return _users.doc(uid).set(data, SetOptions(merge: true));
  }

  // ---------------------------------------------------------------------
  // Schools
  // ---------------------------------------------------------------------
  CollectionReference<Map<String, dynamic>> get schools =>
      db.collection('schools');

  /// Public list of all schools (name only) — used both to join one and to
  /// claim admin of one.
  Stream<QuerySnapshot<Map<String, dynamic>>> streamSchools() =>
      schools.orderBy('name').snapshots();

  Future<Map<String, dynamic>?> getSchool(String schoolId) async =>
      (await schools.doc(schoolId).get()).data();

  /// Whether the current user is a verified admin of [schoolId]. This reads
  /// the `admins` roster — the real gate — not the profile's `role` field.
  Stream<bool> streamIsSchoolAdmin(String schoolId) {
    final uid = _uid;
    if (uid == null) return Stream.value(false);
    return schools
        .doc(schoolId)
        .collection('admins')
        .doc(uid)
        .snapshots()
        .map((d) => d.exists);
  }

  /// Claim admin of a school with its secret code. The roster write only
  /// succeeds if the security rules verify the code server-side against the
  /// school's private config, so a wrong code is rejected.
  Future<void> claimSchoolAdmin({
    required String schoolId,
    required String code,
  }) async {
    final uid = _uid;
    if (uid == null) throw GroupException('You must be signed in.');
    try {
      await schools.doc(schoolId).collection('admins').doc(uid).set({
        'code': code.trim().toUpperCase(),
        'grantedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw GroupException("That admin code isn't valid for this school.");
      }
      rethrow;
    }
    // Convenience flags on the profile (display only — the roster is the gate).
    await _users.doc(uid).set({
      'role': 'admin',
      'adminSchoolId': schoolId,
    }, SetOptions(merge: true));
    // Being an admin implies membership too.
    await joinSchool(schoolId);
  }

  /// Joins a school as a regular member — no code needed, just pick it from
  /// the public list. Purely a self-write to the user's own profile.
  Future<void> joinSchool(String schoolId) async {
    final uid = _uid;
    if (uid == null) throw GroupException('You must be signed in.');
    await _users.doc(uid).set({
      'schools': FieldValue.arrayUnion([schoolId]),
    }, SetOptions(merge: true));
  }

  Future<void> leaveSchool(String schoolId) async {
    final uid = _uid;
    if (uid == null) return;
    await _users.doc(uid).set({
      'schools': FieldValue.arrayRemove([schoolId]),
    }, SetOptions(merge: true));
  }

  /// The signed-in user's joined school ids (empty for a new account).
  Stream<List<String>> streamMySchoolIds() {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _users.doc(uid).snapshots().map((d) {
      final list = d.data()?['schools'] as List?;
      return list?.cast<String>() ?? const <String>[];
    });
  }

  // ---------------------------------------------------------------------
  // Community posts (global feed — unchanged)
  // ---------------------------------------------------------------------
  CollectionReference<Map<String, dynamic>> get _posts =>
      db.collection('communityPosts');

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
  // Groups — nested under a school. Open discovery: no join code, just
  // search within the school and tap Join.
  // ---------------------------------------------------------------------
  CollectionReference<Map<String, dynamic>> _groupsCol(String schoolId) =>
      schools.doc(schoolId).collection('groups');

  CollectionReference<Map<String, dynamic>> _members(
    String schoolId,
    String groupId,
  ) => _groupsCol(schoolId).doc(groupId).collection('members');

  // The user's own list of joined groups (denormalized for a fast read).
  // Each entry also carries the schoolId so the app can rebuild the nested
  // path without an extra lookup.
  CollectionReference<Map<String, dynamic>> _myGroups(String uid) =>
      _users.doc(uid).collection('myGroups');

  /// Every group in a school — used for the searchable directory. One read
  /// for the whole list (schools have dozens of groups, not thousands);
  /// filtering by the search box happens client-side.
  Stream<QuerySnapshot<Map<String, dynamic>>> streamGroupsInSchool(
    String schoolId,
  ) {
    return _groupsCol(schoolId).orderBy('name').snapshots();
  }

  /// Live list of the current user's joined groups, across all schools
  /// (empty for a new account).
  Stream<QuerySnapshot<Map<String, dynamic>>> streamMyGroups() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _myGroups(uid).orderBy('joinedAt', descending: true).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamGroupMembers(
    String schoolId,
    String groupId,
  ) {
    return _members(schoolId, groupId).orderBy('displayName').snapshots();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getGroup(
    String schoolId,
    String groupId,
  ) {
    return _groupsCol(schoolId).doc(groupId).get();
  }

  /// Creates a group inside a school and adds the creator as its first
  /// member. Returns the new group's id.
  Future<String> createGroup({
    required String schoolId,
    required String name,
    required String description,
    String category = 'general',
    String icon = 'sun',
    String? pickupArea,
  }) async {
    final uid = _uid;
    if (uid == null) throw GroupException('You must be signed in.');

    final groupRef = _groupsCol(schoolId).doc();
    await groupRef.set({
      'name': name,
      'description': description,
      'category': category,
      'icon': icon,
      'pickupArea': pickupArea ?? '',
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'members': 1,
      'events': <Map<String, dynamic>>[],
    });
    await _writeMembership(schoolId, groupRef.id, name, icon);
    return groupRef.id;
  }

  /// Joins a group directly — found via search, no code needed.
  Future<void> joinGroup({
    required String schoolId,
    required String groupId,
    required String groupName,
    String icon = 'sun',
  }) async {
    final uid = _uid;
    if (uid == null) throw GroupException('You must be signed in.');
    final already = await _members(schoolId, groupId).doc(uid).get();
    if (already.exists) throw GroupException('You\'re already in this group.');

    await _writeMembership(schoolId, groupId, groupName, icon);
    await _groupsCol(schoolId).doc(groupId).update({
      'members': FieldValue.increment(1),
    });
  }

  Future<void> leaveGroup(String schoolId, String groupId) async {
    final uid = _uid;
    if (uid == null) return;
    await _members(schoolId, groupId).doc(uid).delete();
    await _myGroups(uid).doc(groupId).delete();
    await _groupsCol(schoolId).doc(groupId).update({
      'members': FieldValue.increment(-1),
    });
  }

  // Writes both the group's roster entry and the user's myGroups entry.
  Future<void> _writeMembership(
    String schoolId,
    String groupId,
    String name,
    String icon,
  ) async {
    final uid = _uid;
    if (uid == null) return;
    final me = FirebaseAuth.instance.currentUser;
    final displayName =
        me?.displayName ?? me?.email?.split('@').first ?? 'Member';
    await _members(schoolId, groupId).doc(uid).set({
      'displayName': displayName,
      'email': me?.email,
      'joinedAt': FieldValue.serverTimestamp(),
    });
    await _myGroups(uid).doc(groupId).set({
      'name': name,
      'icon': icon,
      'schoolId': schoolId,
      'joinedAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------------------------------------------------------------------
  // Group events — a small, manually-added list inline on the group doc.
  // (No Storage/versioning machinery: these are a handful of hand-typed
  // events, nowhere near the volume that would justify it.)
  // ---------------------------------------------------------------------
  Future<void> addGroupEvent({
    required String schoolId,
    required String groupId,
    required String title,
    required DateTime date,
    required String time,
    String location = '',
  }) async {
    final id = _groupsCol(schoolId).doc().id;
    await _groupsCol(schoolId).doc(groupId).update({
      'events': FieldValue.arrayUnion([
        {
          'id': id,
          'title': title,
          'date': Timestamp.fromDate(date),
          'time': time,
          'location': location,
        },
      ]),
    });
  }

  /// Removes one event by id. Firestore's arrayRemove needs an exact map
  /// match, so this reads the current array, filters client-side, and
  /// writes the whole (small) array back.
  Future<void> removeGroupEvent(
    String schoolId,
    String groupId,
    String eventId,
  ) async {
    final ref = _groupsCol(schoolId).doc(groupId);
    final doc = await ref.get();
    final events = (doc.data()?['events'] as List?) ?? const [];
    final filtered = events
        .cast<Map<String, dynamic>>()
        .where((e) => e['id'] != eventId)
        .toList();
    await ref.update({'events': filtered});
  }

  // ---------------------------------------------------------------------
  // Carpool trips + seat requests (posting & matching), scoped to a group.
  // ---------------------------------------------------------------------
  CollectionReference<Map<String, dynamic>> _trips(
    String schoolId,
    String groupId,
  ) => _groupsCol(schoolId).doc(groupId).collection('trips');

  CollectionReference<Map<String, dynamic>> _tripRequests(
    String schoolId,
    String groupId,
    String tripId,
  ) => _trips(schoolId, groupId).doc(tripId).collection('requests');

  Stream<QuerySnapshot<Map<String, dynamic>>> streamGroupTrips(
    String schoolId,
    String groupId,
  ) {
    return _trips(schoolId, groupId).orderBy('date').snapshots();
  }

  Future<String> createTrip({
    required String schoolId,
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
    final ref = await _trips(schoolId, groupId).add({
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

  Future<void> cancelTrip(String schoolId, String groupId, String tripId) {
    return _trips(
      schoolId,
      groupId,
    ).doc(tripId).update({'status': 'cancelled'});
  }

  /// A rider asks the driver for a seat (creates a pending request).
  Future<void> requestSeat(
    String schoolId,
    String groupId,
    String tripId,
  ) async {
    final uid = _uid;
    if (uid == null) throw GroupException('You must be signed in.');
    final me = FirebaseAuth.instance.currentUser;
    final riderName =
        me?.displayName ?? me?.email?.split('@').first ?? 'Rider';
    await _tripRequests(schoolId, groupId, tripId).doc(uid).set({
      'riderId': uid,
      'riderName': riderName,
      'status': 'pending',
      'requestedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamTripRequests(
    String schoolId,
    String groupId,
    String tripId,
  ) {
    return _tripRequests(
      schoolId,
      groupId,
      tripId,
    ).orderBy('requestedAt').snapshots();
  }

  /// The current user's own request on a trip (to show their status).
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamMyTripRequest(
    String schoolId,
    String groupId,
    String tripId,
  ) {
    return _tripRequests(
      schoolId,
      groupId,
      tripId,
    ).doc(_uid ?? 'anon').snapshots();
  }

  /// Driver accepts or declines a request. Accepting fills a seat atomically
  /// (and flips the trip to "full" when the last seat goes).
  Future<void> respondToRequest({
    required String schoolId,
    required String groupId,
    required String tripId,
    required String riderId,
    required bool accept,
  }) async {
    final tripRef = _trips(schoolId, groupId).doc(tripId);
    final reqRef = _tripRequests(schoolId, groupId, tripId).doc(riderId);

    if (!accept) {
      await reqRef.update({'status': 'declined'});
      return;
    }

    await db.runTransaction((tx) async {
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
  // same thread.
  // ---------------------------------------------------------------------
  CollectionReference<Map<String, dynamic>> get _conversations =>
      db.collection('conversations');

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
}
