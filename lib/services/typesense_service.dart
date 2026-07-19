// lib/services/typesense_service.dart
//
// Typesense-powered search over calendar events. The events themselves are
// already loaded on-device (SchoolCalendarService); this service pushes them
// into a Typesense "calendar_events" collection and runs typo-tolerant,
// autocomplete-style queries against it for the search bar on the map page.
//
// For the hackathon, indexing happens straight from the client using the
// admin key in TypesenseConfig. In production you'd move indexing to a Cloud
// Function and ship only a search-only key.

import 'package:typesense/typesense.dart';

import 'package:go_glyder/models/calendar_entry.dart';
import 'package:go_glyder/services/typesense_config.dart';

/// One event returned from a Typesense search, trimmed to what the search bar
/// and the map's destination handoff need.
class EventSearchResult {
  final String id;
  final String title;
  final String location;
  final String sourceLabel;
  final String time;

  EventSearchResult({
    required this.id,
    required this.title,
    required this.location,
    required this.sourceLabel,
    required this.time,
  });

  factory EventSearchResult.fromDocument(Map<String, dynamic> doc) {
    return EventSearchResult(
      id: (doc['id'] ?? '') as String,
      title: (doc['title'] ?? '') as String,
      location: (doc['location'] ?? '') as String,
      sourceLabel: (doc['sourceLabel'] ?? '') as String,
      time: (doc['time'] ?? '') as String,
    );
  }

  /// An event is only useful as a destination if it has an address.
  bool get hasLocation => location.trim().isNotEmpty;
}

class TypesenseSearchService {
  TypesenseSearchService._();
  static final TypesenseSearchService instance = TypesenseSearchService._();

  Client? _client;
  bool _collectionReady = false;

  bool get isConfigured => TypesenseConfig.isConfigured;

  Client _ensureClient() {
    return _client ??= Client(
      Configuration(
        TypesenseConfig.apiKey,
        nodes: {
          Node(
            TypesenseConfig.protocol == 'http' ? Protocol.http : Protocol.https,
            TypesenseConfig.host,
            port: TypesenseConfig.port,
          ),
        },
        connectionTimeout: const Duration(seconds: 10),
      ),
    );
  }

  /// Creates the collection the first time it's needed. All fields are stored
  /// as strings and marked optional so a sparse event (no location/time)
  /// still indexes cleanly.
  Future<void> _ensureCollection(Client client) async {
    if (_collectionReady) return;
    try {
      await client.collection(TypesenseConfig.eventsCollection).retrieve();
    } catch (_) {
      final schema = Schema(
        TypesenseConfig.eventsCollection,
        {
          Field('title', type: Type.string),
          Field('location', type: Type.string, isOptional: true),
          Field('sourceLabel',
              type: Type.string, isOptional: true, isFacetable: true),
          Field('description', type: Type.string, isOptional: true),
          Field('date', type: Type.string, isOptional: true),
          Field('time', type: Type.string, isOptional: true),
        },
      );
      try {
        await client.collections.create(schema);
      } catch (_) {
        // Raced with another create (or it already exists) — safe to ignore.
      }
    }
    _collectionReady = true;
  }

  /// Upserts [events] into the Typesense collection. Idempotent — documents
  /// are keyed by the CalendarEntry id, so re-syncing just refreshes them.
  Future<void> syncEvents(List<CalendarEntry> events) async {
    if (!isConfigured || events.isEmpty) return;
    final client = _ensureClient();
    await _ensureCollection(client);

    final docs = events
        .map(
          (e) => <String, dynamic>{
            // Typesense needs a non-empty id; fall back to a composite key
            // for older events that predate stable ids.
            'id': e.id.trim().isNotEmpty
                ? e.id
                : '${e.sourceLabel}_${e.title}_${e.date.toIso8601String()}',
            'title': e.title,
            'location': e.location,
            'sourceLabel': e.sourceLabel,
            'description': e.description,
            'date': e.date.toIso8601String(),
            'time': e.time,
          },
        )
        .toList();

    await client
        .collection(TypesenseConfig.eventsCollection)
        .documents
        .importDocuments(docs, options: {'action': 'upsert'});
  }

  /// Typo-tolerant search over event title, location, and source. Returns an
  /// empty list on any error so the search bar degrades gracefully.
  Future<List<EventSearchResult>> search(String query) async {
    if (!isConfigured) return [];
    try {
      final client = _ensureClient();
      await _ensureCollection(client);

      final res = await client
          .collection(TypesenseConfig.eventsCollection)
          .documents
          .search({
        'q': query.trim().isEmpty ? '*' : query,
        'query_by': 'title,location,sourceLabel',
        'per_page': '8',
        'sort_by': '_text_match:desc',
      });

      final hits = (res['hits'] as List?) ?? const [];
      return hits
          .map((h) => (h as Map)['document'] as Map<String, dynamic>?)
          .whereType<Map<String, dynamic>>()
          .map(EventSearchResult.fromDocument)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
