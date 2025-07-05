import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'seller_verification_screen.dart';

class SellerShopInfoScreen extends StatefulWidget {
  const SellerShopInfoScreen({super.key});

  @override
  State<SellerShopInfoScreen> createState() => _SellerShopInfoScreenState();
}

class _SellerShopInfoScreenState extends State<SellerShopInfoScreen> {
  final _shopNameController = TextEditingController();
  final _pickupAddressController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _emailController.text = user.email ?? '';
      _fetchSellerInfo(user.uid);
    }
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _pickupAddressController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _fetchSellerInfo(String uid) async {
    final doc = await FirebaseFirestore.instance.collection('sellers').doc(uid).get();
    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        _shopNameController.text = data['storeName'] ?? '';
        _pickupAddressController.text = data['pickupAddress'] ?? '';
        _emailController.text = data['email'] ?? '';
        _phoneController.text = data['phone'] ?? '';
      });
    }
  }

  Future<void> saveSellerInfo() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final docRef = FirebaseFirestore.instance.collection('sellers').doc(user.uid);

  await docRef.set({
    'storeName': _shopNameController.text,
    'pickupAddress': _pickupAddressController.text,
    'email': _emailController.text,
    'phone': _phoneController.text,
    'uid': user.uid,
    'createdAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true)); // merge: true allows updating existing fields

  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Seller information saved!')),
  );
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => SellerVerificationScreen(sellerDocId: user.uid),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Shop Information', style: TextStyle(color: Colors.black)),
        centerTitle: true,
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text('Shop Name', style: GoogleFonts.dmSans(fontWeight: FontWeight.w500)),
              _buildTextField(_shopNameController, 'Enter Shop Name'),
              const SizedBox(height: 16),
              Text('Pickup Address', style: GoogleFonts.dmSans(fontWeight: FontWeight.w500)),
              _buildTextField(_pickupAddressController, 'Enter Pickup Address'),
              const SizedBox(height: 16),
              Text('Email', style: GoogleFonts.dmSans(fontWeight: FontWeight.w500)),
              _buildTextField(_emailController, 'Enter Email'),
              const SizedBox(height: 16),
              Text('Phone Number', style: GoogleFonts.dmSans(fontWeight: FontWeight.w500)),
              _buildTextField(_phoneController, 'Enter Phone Number'),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: saveSellerInfo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[400],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    'Next',
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFFE3F0FF),
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      style: GoogleFonts.dmSans(),
    );
  }
} 