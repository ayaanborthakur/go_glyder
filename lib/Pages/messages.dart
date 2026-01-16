import 'package:flutter/material.dart';

class MessagesPage extends StatelessWidget {
  const MessagesPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Messages'),
      ),
      body: Center(
        child: Column(
          children: <Widget>[
            Text(
              'User Messages',
              style: TextStyle(fontSize: 24),
            ),
            ListTile(
              title: Text('Message from John'),
              subtitle: Text('Are you joining the carpool tomorrow?'),
              trailing: Icon(Icons.reply),
              onTap: () {
                // Logic to reply to the message
              },
            ),
          ],
        ),
      ),
    );
  }
}
