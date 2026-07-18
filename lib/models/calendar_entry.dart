/// A single calendar item as shown on the merged Calendar page, regardless
/// of whether it came from a school-wide upload (Storage) or a group's own
/// manually-added events (inline Firestore array).
class CalendarEntry {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final String time;
  final String location;

  /// What to label/tag this entry with — the school name or the group name.
  final String sourceLabel;

  /// School-wide entries (from the admin's uploaded calendar) are tagged
  /// differently than a specific group's own events.
  final bool isSchoolWide;

  /// Present only for group events, so the UI can offer delete/manage.
  final String? schoolId;
  final String? groupId;

  CalendarEntry({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.time,
    required this.location,
    required this.sourceLabel,
    required this.isSchoolWide,
    this.schoolId,
    this.groupId,
  });
}
