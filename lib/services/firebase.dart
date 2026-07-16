import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

/// Initializes Firebase for this app. Firestore itself is accessed through
/// [FirestoreService], which wraps FirebaseFirestore.instance — see
/// lib/services/firestore_service.dart.
Future<void> initializeFirebase() async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}
