import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Error messages mapped to field keys
  Map<String, String?> _errors = {
    'username': null,
    'email': null,
    'password': null,
    'confirm': null,
  };

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _validateAndSubmit() async {
    setState(() {
      _errors = {
        'username': _usernameController.text.trim().isEmpty
            ? 'Username is required'
            : null,
        'email': _validateEmail(_emailController.text.trim()),
        'password': _validatePassword(_passwordController.text),
        'confirm': _passwordController.text != _confirmPasswordController.text
            ? 'Passwords do not match'
            : null,
      };
    });

    if (_errors.values.every((error) => error == null)) {
      try {
        final userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        //save into Cloud Firestore
        await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
          'uid': userCredential.user!.uid,
          'username': _usernameController.text.trim(),
          'email': _emailController.text.trim(),
          'createdAt': Timestamp.now(),
        });

        await userCredential.user?.updateDisplayName(
          _usernameController.text.trim(),
        );


        await userCredential.user?.reload();


        if (!mounted) return;


        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const LoginScreen(),
            settings: const RouteSettings(
              arguments: 'Account created successfully! Please log in.',
            ),
          ),
        );

      } on FirebaseAuthException catch (e) {
        if (!mounted) return;

        final message = switch (e.code) {
          'email-already-in-use' => 'Email already in use',
          'weak-password' => 'Password is too weak',
          'invalid-email' => 'Invalid email address',
          _ => e.message ?? 'Something went wrong',
        };


        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        });
      }
    }
  }


  String? _validateEmail(String email) {
    if (email.isEmpty) {
      return 'Email is required';
    } else if (!RegExp(r'\S+@\S+\.\S+').hasMatch(email)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String password) {
    if (password.isEmpty) return 'Password is required';
    if (password.length < 8) return 'At least 8 characters required';
    if (!RegExp(r'[A-Z]').hasMatch(password)) return 'Include an uppercase letter';
    if (!RegExp(r'[a-z]').hasMatch(password)) return 'Include a lowercase letter';
    if (!RegExp(r'[0-9]').hasMatch(password)) return 'Include a number';
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) {
      return 'Include a special character';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2E418C),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 80, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  'Create Account',
                  style: GoogleFonts.dmSans(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Let’s Create Account Together',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Username
              _buildLabel('Username'),
              _buildInputField(
                controller: _usernameController,
                hint: 'Enter Username',
              ),
              _buildErrorText(_errors['username']),

              const SizedBox(height: 16),

              // Email
              _buildLabel('Email Address'),
              _buildInputField(
                controller: _emailController,
                hint: 'Enter Email Address',
              ),
              _buildErrorText(_errors['email']),

              const SizedBox(height: 16),

              // Password
              _buildLabel('Password'),
              _buildInputField(
                controller: _passwordController,
                hint: 'Enter Password',
                obscure: _obscurePassword,
                toggle: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              _buildErrorText(_errors['password']),

              const SizedBox(height: 16),

              // Confirm Password
              _buildLabel('Confirm Password'),
              _buildInputField(
                controller: _confirmPasswordController,
                hint: 'Re-enter Password',
                obscure: _obscureConfirmPassword,
                toggle: () {
                  setState(() {
                    _obscureConfirmPassword = !_obscureConfirmPassword;
                  });
                },
              ),
              _buildErrorText(_errors['confirm']),

              const SizedBox(height: 130),

              // Sign Up Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _validateAndSubmit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    backgroundColor: const Color(0xFF64B5F6),
                  ),
                  child: Text(
                    'Sign Up',
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                    );
                  },

                  child: RichText(
                    text: TextSpan(
                      text: 'Have An Account? ',
                      style: GoogleFonts.dmSans(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                      children: [
                        TextSpan(
                          text: 'Login',
                          style: GoogleFonts.dmSans(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Label widget
  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.dmSans(color: Colors.white),
    );
  }

  // Error text widget
  Widget _buildErrorText(String? error) {
    return error != null
        ? Padding(
      padding: const EdgeInsets.only(left: 12, top: 4),
      child: Text(
        error,
        style: const TextStyle(color: Colors.red, fontSize: 12),
      ),
    )
        : const SizedBox.shrink();
  }

  // Input field widget
  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
    VoidCallback? toggle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(30),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: Colors.white54),
                border: InputBorder.none,
              ),
            ),
          ),
          if (toggle != null)
            IconButton(
              onPressed: toggle,
              icon: Icon(
                obscure ? Icons.visibility_off : Icons.visibility,
                color: Colors.white54,
              ),
            ),
        ],
      ),
    );
  }
}
