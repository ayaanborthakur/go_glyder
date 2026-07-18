import 'dart:developer' as developer;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:go_glyder/services/firebase.dart';
import 'package:go_glyder/services/notification_service.dart';
import 'package:go_glyder/features/account/scripts/auth.dart';

import 'app.dart';
import 'router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeFirebase();
  // google_sign_in v7 requires a one-time initialize before use. Only needed on non-Web platforms.
  if (!kIsWeb) {
    try {
      developer.log('Initializing GoogleSignIn on Mobile/Desktop...', name: 'GoGlyder.Main');
      await GoogleSignIn.instance.initialize(
        serverClientId: kGoogleServerClientId,
      );
      developer.log('GoogleSignIn initialized successfully.', name: 'GoGlyder.Main');
    } catch (e, stack) {
      developer.log(
        'Failed to initialize GoogleSignIn on Mobile/Desktop',
        name: 'GoGlyder.Main',
        error: e,
        stackTrace: stack,
      );
    }
  } else {
    developer.log('Skipping GoogleSignIn initialization on Web (will use Firebase Auth Popup).', name: 'GoGlyder.Main');
  }

  // Wire notification taps to the router, then start FCM. The token itself is
  // only saved once a user is signed in (see AuthService); initialize() here
  // just registers permission + the message listeners.
  NotificationService.instance.onNavigateToRoute = router.go;
  await NotificationService.instance.initialize();

  runApp(const MyApp());
}
