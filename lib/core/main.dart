import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:go_glyder/services/firebase.dart';
import 'package:go_glyder/features/account/scripts/auth.dart';

import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeFirebase();
  // google_sign_in v7 requires a one-time initialize before use.
  await GoogleSignIn.instance.initialize(
    serverClientId: kGoogleServerClientId,
  );
  runApp(const MyApp());
}
