import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shoefit_application/user_profile_screen.dart';

class SellerVerificationSuccessScreen extends StatelessWidget {
  const SellerVerificationSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/verification_success.png', 
                  height: 200,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 32),
                Text(
                  'Thank you. Your request has been submitted successfully. Please allow 1–3 working days for review. The result will be sent to your inbox upon completion',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    color: Colors.grey[700],
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 120),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const UserProfileScreen()),
                        );
                      },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[400],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      'Done',
                      style: GoogleFonts.dmSans(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 