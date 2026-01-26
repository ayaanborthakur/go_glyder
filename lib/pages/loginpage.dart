// lib/src/features/authentication/presentation/screens/login_screen.dart

import 'package:flutter/material.dart';
// Make sure this import path is correct for your project structure
import 'package:go_glyder/services/auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // HERE is where you "initialize" it for this screen
  final AuthService _authService = AuthService();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // ... rest of the state logic

  Future<void> _signIn() async {
    // ...
    // Now you can USE the instance
    final userCredential = await _authService.signInWithEmailAndPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );
    // ...
  }

  Future<void> _signUp() async {
    final userCredential = await _authService.signUpWithEmailAndPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Column(
        children: [
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(hintText: 'Email'),
          ),
          TextField(
            controller: _passwordController,
            decoration: const InputDecoration(hintText: 'Password'),
          ),
          ElevatedButton(onPressed: _signIn, child: const Text('Login')),
          ElevatedButton(onPressed: _signUp, child: const Text('Sign Up')),
        ],
      ),
    );
  }

  // ... build method etc.
}
