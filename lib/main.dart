import 'package:flutter/material.dart';
import 'package:go_glyder/Services/firebase.dart';

import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeFirebase();
  runApp(const MyApp());
}
