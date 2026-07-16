import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:go_glyder/models/school_event.dart';

/// Reads and writes the signed-in user's calendar events in Firestore.
/// Data lives under `users/{uid}/events`, so every new account starts empty.
class EventRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return _db.collection('users').doc(uid).collection('events');
  }

  /// Live stream of the user's events, ordered by date.
  Stream<List<SchoolEvent>> watchEvents() {
    return _col()
        .orderBy('date')
        .snapshots()
        .map((snap) => snap.docs.map(SchoolEvent.fromDoc).toList());
  }

  Future<void> addEvent(SchoolEvent event) => _col().add(event.toMap());

  Future<void> deleteEvent(String id) => _col().doc(id).delete();
}
