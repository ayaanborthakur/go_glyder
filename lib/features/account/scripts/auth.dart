// lib/services/auth.dart

import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  // Get an instance of FirebaseAuth to use its features
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  // STREAM: Listens for changes in the user's authentication state (logged in or out)
  // This is the most important part for automatically redirecting users.
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // GET CURRENT USER: A quick way to get the current user object if one exists.
  User? get currentUser => _firebaseAuth.currentUser;

  // SIGN UP with Email and Password
  Future<UserCredential?> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      // Use FirebaseAuth to create a new user
      final UserCredential userCredential = await _firebaseAuth
          .createUserWithEmailAndPassword(email: email, password: password);
      return userCredential;
    } on FirebaseAuthException catch (e) {
      // This catches specific Firebase errors (e.g., 'email-already-in-use')
      // You can add more specific error handling here if you want.
      print('Firebase Auth Exception during sign-up: ${e.message}');
      return null;
    } catch (e) {
      // This catches any other unexpected errors.
      print('An unexpected error occurred during sign-up: $e');
      return null;
    }
  }

  // SIGN IN with Email and Password
  Future<UserCredential?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      // Use FirebaseAuth to sign in an existing user
      final UserCredential userCredential = await _firebaseAuth
          .signInWithEmailAndPassword(email: email, password: password);
      return userCredential;
    } on FirebaseAuthException catch (e) {
      // Handles errors like 'user-not-found' or 'wrong-password'
      print('Firebase Auth Exception during sign-in: ${e.message}');
      return null;
    } catch (e) {
      print('An unexpected error occurred during sign-in: $e');
      return null;
    }
  }

  // SIGN OUT
  Future<void> signOut() async {
    // Simply call the signOut method from FirebaseAuth
    await _firebaseAuth.signOut();
  }
}
