// lib/student_login_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'home_page.dart';

class StudentLoginPage extends StatefulWidget {
  const StudentLoginPage({super.key});
  @override
  State<StudentLoginPage> createState() => _StudentLoginPageState();
}

class _StudentLoginPageState extends State<StudentLoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _signIn() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      _showFeedback("Please enter both email and password.");
      return;
    }

    setState(() {
      _isLoading = true;
    });
    try {
      // Step 1: Sign in with Firebase Auth
      final userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = userCredential.user;
      if (user == null) {
        _showFeedback("Failed to sign in. Please try again.");
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Step 2: Perform the Role Check
      final userRef = FirebaseDatabase.instance.ref('users/${user.uid}');
      final snapshot = await userRef.get();

      if (snapshot.exists && mounted) {
        // Step 3: If check passes, navigate to the student home page
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const HomePage()));
      } else {
        // Step 4: If check fails, the user is not a student. Sign them out and show an error.
        await FirebaseAuth.instance.signOut();
        _showFeedback("You are not registered as a student.");
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      if (e.code == 'user-not-found' ||
          e.code == 'invalid-credential' ||
          e.code == 'wrong-password') {
        errorMessage =
            "Invalid credentials. Please check your email and password.";
      } else {
        errorMessage = "An error occurred: ${e.message}";
      }
      _showFeedback(errorMessage);
    } catch (e) {
      // Handle any other errors including the PigeonUserDetails error
      String errorMessage = "Authentication error. Please try again later.";
      if (e.toString().contains('PigeonUserDetails')) {
        errorMessage = "Authentication service temporarily unavailable. Please try again.";
      }
      _showFeedback(errorMessage);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showFeedback("Please enter your email to reset password.");
      return;
    }

    setState(() {
      _isLoading = true;
    });
    try {
      final event = await FirebaseDatabase.instance
          .ref('users')
          .orderByChild('email')
          .equalTo(email)
          .once();
      if (!event.snapshot.exists) {
        _showFeedback("This email is not registered as a student.");
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showFeedback("Password reset link sent to your email.", isError: false);
    } on FirebaseAuthException catch (e) {
      _showFeedback("Error: ${e.message}");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showFeedback(String message, {bool isError = true}) {
    final snackBar = SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red : Colors.green,
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),
                Icon(Icons.school_rounded,
                    size: 80, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text('Student Portal',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary)),
                const SizedBox(height: 60),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                      labelText: 'Campus Email',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12))),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12))),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _forgotPassword,
                    child: const Text('Forgot Password?'),
                  ),
                ),
                const SizedBox(height: 20),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : FilledButton(
                        onPressed: _signIn,
                        child: const Text('SIGN IN'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
