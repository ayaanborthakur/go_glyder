import 'package:flutter/material.dart';

class FindRoutePage extends StatelessWidget {
  const FindRoutePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Find Route')),
      body: const Center(
        child: Text(
          'Find Route Page',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
