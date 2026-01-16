import 'package:flutter/material.dart';

class CommunityPage extends StatelessWidget {
  const CommunityPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Community'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Welcome to the Community!',
              style: TextStyle(fontSize: 24),
            ),
            ElevatedButton(
              onPressed: () {

                // Logic to create a new community post or message
              },
              child: Text('Create Post'),
            ),
          ],
        ),
      ),
    );
  }
}