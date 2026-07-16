import 'package:cloud_firestore/cloud_firestore.dart';

/// A calendar event. Read from the shared `calendarEvents` collection;
/// writes go through [FirestoreService].
class SchoolEvent {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final String time;

  SchoolEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.time,
  });

  factory SchoolEvent.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final ts = data['date'];
    return SchoolEvent(
      id: doc.id,
      title: (data['title'] ?? '') as String,
      description: (data['description'] ?? '') as String,
      date: ts is Timestamp ? ts.toDate() : DateTime.now(),
      time: (data['time'] ?? '') as String,
    );
  }
}
