import 'package:flutter/material.dart';

class CalendarPage extends StatelessWidget {
  const CalendarPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Calendar'),
      ),
      body: Center(
        child: Column(
          children: <Widget>[
            Text(
              'Upcoming Events',
              style: TextStyle(fontSize: 24),
            ),
            ListTile(
              title: Text('Carpool to Work'),
              subtitle: Text('Date: 2023-10-15'),
              trailing: Icon(Icons.arrow_forward),
              onTap: () {
                // Logic to schedule a ride
              },
            ),
          ],
        ),
      ),
    );
  }
}
