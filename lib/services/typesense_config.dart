// lib/services/typesense_config.dart
//
// Connection details for the Typesense Cloud cluster that powers calendar-
// event search on the map/search page.
//
// For the hackathon these are embedded directly (the admin key is used to
// index events from the client). For production you'd move indexing to a
// Cloud Function and ship only a *search-only* key here — but the values can
// already be overridden at build time without editing this file:
//
//   flutter run \
//     --dart-define=TYPESENSE_HOST=xyz-1.a1.typesense.net \
//     --dart-define=TYPESENSE_API_KEY=your_admin_key
//
class TypesenseConfig {
  /// Cluster host, e.g. `xyz123-1.a1.typesense.net` (no protocol, no port).
  static const String host = String.fromEnvironment(
    'TYPESENSE_HOST',
    defaultValue: 'tlu7jpor1643wysdp-1.a1.typesense.net',
  );

  static const int port = int.fromEnvironment(
    'TYPESENSE_PORT',
    defaultValue: 443,
  );

  /// 'https' for Typesense Cloud, 'http' for a plain local Docker instance.
  static const String protocol = String.fromEnvironment(
    'TYPESENSE_PROTOCOL',
    defaultValue: 'https',
  );

  /// Admin API key (indexes + searches). Swap for a search-only key once
  /// indexing moves server-side.
  static const String apiKey = String.fromEnvironment(
    'TYPESENSE_API_KEY',
    defaultValue: 'ZCym6gBLOvh0kQsFHjMal9xSDfsQ9cJg',
  );

  /// Name of the Typesense collection holding calendar events.
  static const String eventsCollection = 'calendar_events';

  /// True once real values have been filled in — the UI hides the event
  /// search bar (and skips indexing) until then, so nothing breaks when the
  /// cluster isn't configured yet.
  static bool get isConfigured =>
      !host.startsWith('YOUR_') && !apiKey.startsWith('YOUR_');
}
