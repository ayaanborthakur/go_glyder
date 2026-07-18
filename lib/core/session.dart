import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// App-wide auth + profile state. The router listens to this to decide
/// between the login screen, the first-time role picker, and the app.
///
/// It tracks not just whether someone is signed in, but whether their profile
/// (and role) has loaded yet — so a brand-new account is routed to onboarding
/// exactly once, and returning users go straight in.
class Session extends ChangeNotifier {
  User? _user;
  String? _role;
  String? _adminSchoolId;
  bool _profileLoaded = false;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;

  Session() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
  }

  User? get user => _user;
  String? get role => _role;
  String? get adminSchoolId => _adminSchoolId;
  bool get isLoggedIn => _user != null;

  /// True until we've read the signed-in user's profile doc at least once.
  bool get profileLoading => _user != null && !_profileLoaded;

  /// Signed in, profile loaded, but no role chosen yet.
  bool get needsOnboarding =>
      _user != null && _profileLoaded && (_role == null || _role!.isEmpty);

  void _onAuthChanged(User? user) {
    _user = user;
    _profileSub?.cancel();
    _role = null;
    _adminSchoolId = null;
    _profileLoaded = false;
    notifyListeners();

    if (user == null) return;

    _profileSub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen(
          (doc) {
            _role = doc.data()?['role'] as String?;
            _adminSchoolId = doc.data()?['adminSchoolId'] as String?;
            _profileLoaded = true;
            notifyListeners();
          },
          onError: (_) {
            // Don't hang on a read error — let routing proceed.
            _profileLoaded = true;
            notifyListeners();
          },
        );
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _profileSub?.cancel();
    super.dispose();
  }
}

/// Single shared instance the router and screens read from.
final session = Session();
