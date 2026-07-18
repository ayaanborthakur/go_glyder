// lib/services/school_calendar_service.dart
//
// School-wide calendars (Option C): the admin's exported .ics is parsed on
// device, recurring events are expanded for the next 12 months, and the
// flattened event list is uploaded as a single JSON file to Cloud Storage —
// NOT into a Firestore document. Firestore only ever holds a tiny pointer
// (id, name, version, storagePath) on the school doc.
//
// Members read the pointer (piggybacked on a school-doc read they need
// anyway), compare its version against a local cache, and only download
// from Storage when the version has actually changed. Steady state: zero
// Storage calls, one small Firestore read.

import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:icalendar_parser/icalendar_parser.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rrule/rrule.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

import 'package:go_glyder/models/calendar_entry.dart';
import 'package:go_glyder/services/firestore_service.dart';

class SchoolCalendarService {
  SchoolCalendarService._internal();
  static final SchoolCalendarService instance =
      SchoolCalendarService._internal();

  final FirestoreService _fs = FirestoreService.instance;

  /// How far ahead recurring events are expanded into concrete instances.
  static const _expansionWindow = Duration(days: 365);

  /// Parses [icsContent], expands recurrence, uploads the result to Storage,
  /// and updates the school's calendar index. Throws on failure.
  Future<void> uploadCalendar({
    required String schoolId,
    required String calendarName,
    required String icsContent,
  }) async {
    final events = _parseIcs(icsContent);
    if (events.isEmpty) {
      throw GroupException('No events were found in that file.');
    }

    final schoolDoc = await _fs.schools.doc(schoolId).get();
    final data = schoolDoc.data() ?? {};
    final existing = ((data['calendars'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();

    // Reuse the same calendar id if this is a re-upload (matched by name),
    // otherwise mint a new one. Each upload gets its own versioned file, so
    // rolling back to a previous version is just repointing storagePath.
    final match = existing.firstWhere(
      (c) => c['name'] == calendarName,
      orElse: () => const {},
    );
    final calendarId = (match['id'] as String?) ?? _randomId();
    final nextVersion = ((match['version'] as int?) ?? 0) + 1;

    final storagePath = 'calendars/$schoolId/${calendarId}_v$nextVersion.json';
    final jsonBody = jsonEncode(
      events
          .map(
            (e) => {
              'title': e.title,
              'description': e.description,
              'date': e.date.toIso8601String(),
              'time': e.time,
              'location': e.location,
            },
          )
          .toList(),
    );

    await FirebaseStorage.instance
        .ref(storagePath)
        .putString(jsonBody, format: PutStringFormat.raw);

    final updated = [
      ...existing.where((c) => c['id'] != calendarId),
      {
        'id': calendarId,
        'name': calendarName,
        'version': nextVersion,
        'storagePath': storagePath,
        'updatedAt': Timestamp.now(),
      },
    ];
    await _fs.schools.doc(schoolId).update({'calendars': updated});
  }

  Future<void> removeCalendar(String schoolId, String calendarId) async {
    final schoolDoc = await _fs.schools.doc(schoolId).get();
    final existing = ((schoolDoc.data()?['calendars'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();
    final updated = existing.where((c) => c['id'] != calendarId).toList();
    await _fs.schools.doc(schoolId).update({'calendars': updated});
  }

  /// School-wide events across every school the current user belongs to
  /// (cached per calendar). Cheap in steady state — one small Firestore read
  /// per school for the pointer, then local cache.
  Future<List<CalendarEntry>> fetchMySchoolEvents() async {
    final schoolIds = await _fs.streamMySchoolIds().first;
    final all = <CalendarEntry>[];
    for (final schoolId in schoolIds) {
      final school = await _fs.getSchool(schoolId);
      final name = (school?['name'] ?? 'School') as String;
      all.addAll(await fetchSchoolEvents(schoolId, name));
    }
    return all;
  }

  /// Returns every event from every calendar uploaded to [schoolId], using
  /// the local cache whenever the version hasn't changed.
  Future<List<CalendarEntry>> fetchSchoolEvents(
    String schoolId,
    String schoolName,
  ) async {
    final schoolDoc = await _fs.schools.doc(schoolId).get();
    final calendars = ((schoolDoc.data()?['calendars'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();

    final results = <CalendarEntry>[];
    for (final cal in calendars) {
      final id = cal['id'] as String?;
      final storagePath = cal['storagePath'] as String?;
      final version = cal['version'] as int?;
      if (id == null || storagePath == null || version == null) continue;

      final jsonBody = await _cachedOrDownload(
        schoolId: schoolId,
        calendarId: id,
        version: version,
        storagePath: storagePath,
      );
      if (jsonBody == null) continue;

      final decoded = jsonDecode(jsonBody) as List;
      for (final raw in decoded) {
        final m = raw as Map<String, dynamic>;
        results.add(
          CalendarEntry(
            id: '${id}_${m['date']}_${m['title']}',
            title: (m['title'] ?? '') as String,
            description: (m['description'] ?? '') as String,
            date: DateTime.parse(m['date'] as String),
            time: (m['time'] ?? '') as String,
            location: (m['location'] ?? '') as String,
            sourceLabel: schoolName,
            isSchoolWide: true,
          ),
        );
      }
    }
    return results;
  }

  Future<String?> _cachedOrDownload({
    required String schoolId,
    required String calendarId,
    required int version,
    required String storagePath,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final versionKey = 'cal_version_${schoolId}_$calendarId';
    final file = await _localFile(schoolId, calendarId);

    final cachedVersion = prefs.getInt(versionKey);
    if (cachedVersion == version && await file.exists()) {
      return file.readAsString();
    }

    final bytes = await FirebaseStorage.instance.ref(storagePath).getData();
    if (bytes == null) return null;
    final body = utf8.decode(bytes);
    await file.writeAsString(body);
    await prefs.setInt(versionKey, version);
    return body;
  }

  Future<File> _localFile(String schoolId, String calendarId) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/calendar_${schoolId}_$calendarId.json');
  }

  // ---------------------------------------------------------------------
  // .ics parsing + recurrence expansion
  // ---------------------------------------------------------------------

  List<_ParsedEvent> _parseIcs(String icsContent) {
    final ICalendar cal;
    try {
      cal = ICalendar.fromString(icsContent);
    } catch (e) {
      throw GroupException(
        'Could not read that file — make sure it\'s a valid .ics export.',
      );
    }

    final now = DateTime.now();
    final windowEnd = now.add(_expansionWindow);
    final results = <_ParsedEvent>[];

    for (final raw in cal.data) {
      if (raw['type'] != 'VEVENT') continue;

      final title = (raw['summary'] ?? 'Untitled event') as String;
      final description = (raw['description'] ?? '') as String;
      final location = (raw['location'] ?? '') as String;

      final dtStartRaw = raw['dtstart'];
      if (dtStartRaw is! IcsDateTime) continue;
      final start = _parseIcsDateTime(dtStartRaw);
      if (start == null) continue;

      final allDay = dtStartRaw.dt.length == 8; // YYYYMMDD, no time part
      final time = allDay
          ? 'All Day'
          : '${start.hour.toString().padLeft(2, '0')}:'
                '${start.minute.toString().padLeft(2, '0')}';

      final rruleStr = raw['rrule'] as String?;
      final exdates = <DateTime>{
        for (final ex in (raw['exdate'] as List? ?? const []))
          if (ex is IcsDateTime && _parseIcsDateTime(ex) != null)
            _parseIcsDateTime(ex)!.toLocal(),
      };

      if (rruleStr == null || rruleStr.isEmpty) {
        // Single, non-repeating event.
        if (!start.isAfter(windowEnd)) {
          results.add(_ParsedEvent(title, description, location, start, time));
        }
        continue;
      }

      // Recurring event: expand instances from ~a month ago through the next
      // ~12 months. Bounding on both sides keeps a weekly series that began
      // years ago from exploding into hundreds of stale past occurrences.
      try {
        final rule = RecurrenceRule.fromString(
          'RRULE:$rruleStr',
          options: const RecurrenceRuleFromStringOptions.lenient(),
        );
        final utcStart = start.copyWith(isUtc: true);
        final windowStart = now
            .subtract(const Duration(days: 31))
            .copyWith(isUtc: true);
        final instances = rule
            .getInstances(
              start: utcStart,
              after: windowStart,
              includeAfter: true,
              before: windowEnd.copyWith(isUtc: true),
            )
            .take(1000); // defensive cap against pathological rules
        for (final instant in instances) {
          final local = instant.copyWith(isUtc: false);
          if (exdates.contains(local)) continue;
          results.add(
            _ParsedEvent(title, description, location, local, time),
          );
        }
      } catch (_) {
        // Malformed RRULE — fall back to just the first occurrence rather
        // than dropping the event entirely.
        results.add(_ParsedEvent(title, description, location, start, time));
      }
    }

    results.sort((a, b) => a.date.compareTo(b.date));
    return results;
  }

  /// Minimal ICS date/time parser for the common `YYYYMMDD` and
  /// `YYYYMMDDTHHMMSS(Z)?` forms Google Calendar exports — Dart's
  /// [DateTime.tryParse] doesn't accept these (no separators).
  DateTime? _parseIcsDateTime(IcsDateTime ics) {
    final raw = ics.dt;
    final isUtc = raw.endsWith('Z');
    final clean = isUtc ? raw.substring(0, raw.length - 1) : raw;

    if (clean.length == 8) {
      final y = int.tryParse(clean.substring(0, 4));
      final m = int.tryParse(clean.substring(4, 6));
      final d = int.tryParse(clean.substring(6, 8));
      if (y == null || m == null || d == null) return null;
      return DateTime(y, m, d);
    }
    if (clean.length >= 15 && clean[8] == 'T') {
      final y = int.tryParse(clean.substring(0, 4));
      final m = int.tryParse(clean.substring(4, 6));
      final d = int.tryParse(clean.substring(6, 8));
      final hh = int.tryParse(clean.substring(9, 11));
      final mm = int.tryParse(clean.substring(11, 13));
      final ss = int.tryParse(clean.substring(13, 15));
      if ([y, m, d, hh, mm, ss].any((v) => v == null)) return null;
      return isUtc
          ? DateTime.utc(y!, m!, d!, hh!, mm!, ss!).toLocal()
          : DateTime(y!, m!, d!, hh!, mm!, ss!);
    }
    return DateTime.tryParse(raw);
  }

  String _randomId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rnd = Random.secure();
    return List.generate(12, (_) => chars[rnd.nextInt(chars.length)]).join();
  }
}

class _ParsedEvent {
  final String title;
  final String description;
  final String location;
  final DateTime date;
  final String time;
  _ParsedEvent(this.title, this.description, this.location, this.date, this.time);
}
