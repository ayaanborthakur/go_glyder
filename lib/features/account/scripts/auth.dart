// lib/features/account/scripts/auth.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_glyder/services/firestore_service.dart';

/// Thrown when an auth action fails, carrying a user-friendly message
/// that the UI can show directly.
class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

class AuthService {
  // Get an instance of FirebaseAuth to use its features
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  // STREAM: Listens for changes in the user's authentication state (logged in or out).
  // The router listens to this to decide whether to show the login screen.
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // GET CURRENT USER: A quick way to get the current user object if one exists.
  User? get currentUser => _firebaseAuth.currentUser;

  // SIGN UP with Email and Password
  Future<UserCredential> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Create the user's profile document so the account is a real record.
      final user = credential.user;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'email': email,
          'displayName': email.split('@').first,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      return credential;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_friendlyMessage(e));
    } catch (_) {
      throw AuthException('Something went wrong. Please try again.');
    }
  }

  // SIGN IN with Email and Password
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      // FIX: Changed "createUserWithEmailAndPassword" to "signInWithEmailAndPassword"
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create the corresponding Firestore profile doc for this user.
      final uid = credential.user?.uid;
      if (uid != null) {
        await FirestoreService.instance.createUserProfile(
          uid: uid,
          email: email,
        );
      }
      return credential;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_friendlyMessage(e));
    } catch (_) {
      throw AuthException('Something went wrong. Please try again.');
    }
  } // Only one bracket here now!

  // SIGN OUT
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  // Maps raw Firebase error codes to messages a person can actually understand.
  String _friendlyMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address doesn\'t look right.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'weak-password':
        return 'Please use a stronger password (at least 6 characters).';
      case 'network-request-failed':
        return 'No internet connection. Please check and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }
}
