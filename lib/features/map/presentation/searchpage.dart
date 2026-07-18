import 'package:flutter/material.dart';
import 'package:go_glyder/services/gmaps.dart';

// MapScreen now owns its own search UI (origin + destination fields
// overlaying the map, Google-Maps-style), so this page is just a thin
// wrapper that keeps the /search route stable -- no second AppBar or
// search box here anymore.
class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const MapScreen();
  }
}
