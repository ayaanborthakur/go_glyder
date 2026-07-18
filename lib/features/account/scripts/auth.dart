// lib/features/account/scripts/auth.dart

import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:go_glyder/services/notification_service.dart';
import 'package:go_glyder/features/messages/logic/messages_logic.dart';

/// Web OAuth client ID from android/app/google-services.json (client_type 3).
/// google_sign_in needs this as the serverClientId so it returns an ID token
/// whose audience Firebase will accept.
const String kGoogleServerClientId =
    '163214469630-v7g1bmsgsjsrvf9j0npg98om8398vjo7.apps.googleusercontent.com';

/// Thrown when an auth action fails, carrying a user-friendly message.
class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  // Router listens to this to decide whether to show the login screen.
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  User? get currentUser => _firebaseAuth.currentUser;

  /// Signs in with Google. Returns the credential, or `null` if the user
  /// dismissed the Google account picker (a cancel, not an error).
  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        developer.log('Starting Google Sign-In on Web using signInWithPopup...', name: 'GoGlyder.Auth');
        final GoogleAuthProvider authProvider = GoogleAuthProvider();
        final UserCredential userCredential = await _firebaseAuth.signInWithPopup(authProvider);
        developer.log('Web Google Sign-In successful. User: ${userCredential.user?.uid}', name: 'GoGlyder.Auth');
        await _upsertUserDoc(userCredential.user);
        return userCredential;
      } else {
        developer.log('Starting Google Sign-In on Mobile/Desktop...', name: 'GoGlyder.Auth');
        // google_sign_in v7: authenticate() shows the native account picker.
        final GoogleSignInAccount account =
            await GoogleSignIn.instance.authenticate();

        developer.log('Google account retrieved: ${account.email}', name: 'GoGlyder.Auth');
        final idToken = account.authentication.idToken;
        if (idToken == null) {
          developer.log('Google sign-in ID token is null', name: 'GoGlyder.Auth');
          throw AuthException('Google sign-in failed. Please try again.');
        }

        final credential = GoogleAuthProvider.credential(idToken: idToken);
        final userCredential = await _firebaseAuth.signInWithCredential(
          credential,
        );
        developer.log('Firebase credential sign-in successful. User: ${userCredential.user?.uid}', name: 'GoGlyder.Auth');
        await _upsertUserDoc(userCredential.user);
        return userCredential;
      }
    } on GoogleSignInException catch (e, stack) {
      developer.log(
        'GoogleSignInException during sign-in',
        name: 'GoGlyder.Auth',
        error: e,
        stackTrace: stack,
      );
      // User backed out of the picker — not a real error.
      if (e.code == GoogleSignInExceptionCode.canceled) {
        developer.log('Google sign-in cancelled by user', name: 'GoGlyder.Auth');
        return null;
      }
      throw AuthException('Google sign-in failed: ${e.code}. Please try again.');
    } on FirebaseAuthException catch (e, stack) {
      developer.log(
        'FirebaseAuthException during sign-in: ${e.code} - ${e.message}',
        name: 'GoGlyder.Auth',
        error: e,
        stackTrace: stack,
      );
      const cancelCodes = {
        'web-context-canceled',
        'web-context-cancelled',
        'canceled',
        'user-cancelled',
        'popup-closed-by-user',
      };
      if (cancelCodes.contains(e.code)) {
        developer.log('Google sign-in cancelled by user (Firebase code: ${e.code})', name: 'GoGlyder.Auth');
        return null;
      }
      throw AuthException(e.message ?? 'Sign-in failed. Please try again.');
    } on AuthException {
      rethrow;
    } catch (e, stack) {
      developer.log(
        'Unexpected error during Google sign-in',
        name: 'GoGlyder.Auth',
        error: e,
        stackTrace: stack,
      );
      throw AuthException('Something went wrong: $e. Please try again.');
    }
  }

  /// Signs in with Microsoft via Firebase's OAuth provider. Returns the
  /// credential, or `null` if the user cancels the flow.
  ///
  /// No extra package needed — [MicrosoftAuthProvider] is built into
  /// firebase_auth. Requires the Microsoft provider to be enabled in the
  /// Firebase console (backed by an Azure AD app registration).
  Future<UserCredential?> signInWithMicrosoft() async {
    try {
      final provider = MicrosoftAuthProvider()
        ..setCustomParameters({'prompt': 'select_account'});

      final userCredential = kIsWeb
          ? await _firebaseAuth.signInWithPopup(provider)
          : await _firebaseAuth.signInWithProvider(provider);

      await _upsertUserDoc(userCredential.user);
      return userCredential;
    } on FirebaseAuthException catch (e) {
      // Various cancel codes across platforms — treat as a no-op.
      const cancelCodes = {
        'web-context-canceled',
        'web-context-cancelled',
        'canceled',
        'user-cancelled',
        'popup-closed-by-user',
      };
      if (cancelCodes.contains(e.code)) return null;
      throw AuthException(e.message ?? 'Microsoft sign-in failed. Try again.');
    } catch (_) {
      throw AuthException('Something went wrong. Please try again.');
    }
  }

  /// Creates/updates the user's profile document so the account is a real
  /// record and future per-user data has somewhere to live.
  ///
  /// Best-effort: a failure here (e.g. Firestore rules not yet deployed) must
  /// NOT fail the sign-in — the user is already authenticated at this point.
  Future<void> _upsertUserDoc(User? user) async {
    if (user == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'email': user.email,
        'displayName': user.displayName ?? user.email?.split('@').first,
        'photoUrl': user.photoURL,
        'lastSignInAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      developer.log(
        'Could not write user profile doc',
        name: 'GoGlyder.Auth',
        error: e,
      );
    }

    // Associate this device's FCM token with the account now that we know the
    // uid. Best-effort — a failure here must not block sign-in.
    await NotificationService.instance.saveTokenForUser(user.uid);
  }

  Future<void> signOut() async {
    try {
      // Stop pushes to this device and tear down the messaging stream before the
      // auth session goes away.
      final uid = _firebaseAuth.currentUser?.uid;
      if (uid != null) {
        await NotificationService.instance.clearTokenForUser(uid);
      }
      MessagesController.instance.unsubscribeFromConversations();

      if (!kIsWeb) {
        developer.log('Signing out of Google on Mobile/Desktop...', name: 'GoGlyder.Auth');
        await GoogleSignIn.instance.signOut();
      } else {
        developer.log('Skipping GoogleSignIn.signOut() on Web...', name: 'GoGlyder.Auth');
      }

      developer.log('Signing out of FirebaseAuth...', name: 'GoGlyder.Auth');
      await _firebaseAuth.signOut();
      developer.log('Sign-out complete.', name: 'GoGlyder.Auth');
    } catch (e, stack) {
      developer.log(
        'Error during sign-out',
        name: 'GoGlyder.Auth',
        error: e,
        stackTrace: stack,
      );
      // Even if an error happens, still attempt to sign out from Firebase
      try {
        await _firebaseAuth.signOut();
      } catch (_) {}
    }
  }
}
