import 'package:flutter/material.dart';
import 'package:go_glyder/Services/gmaps.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({Key? key}) : super(key: key);

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Center(
        child: Column(
          children: <Widget>[
            TextField(
              decoration: const InputDecoration(hintText: 'Search for users'),
              onChanged: (value) {
                // Logic to search for users
              },
            ),
            MapScreen(),
          ],
        ),
      ),
    );
  }
}
