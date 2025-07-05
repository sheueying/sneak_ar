import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'seller_verification_success_screen.dart';

class SellerVerificationScreen extends StatefulWidget {
  final String sellerDocId;
  const SellerVerificationScreen({super.key, required this.sellerDocId});

  @override
  State<SellerVerificationScreen> createState() => _SellerVerificationScreenState();
}

class _SellerVerificationScreenState extends State<SellerVerificationScreen> {
  final _fullNameController = TextEditingController();
  final _nricController = TextEditingController();

  File? _nricFront;
  File? _nricBack;
  File? _nricSelfie;

  bool isLoading = false;

  Future<void> pickImage(ImageSource source, String type) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 80);
    if (pickedFile != null) {
      setState(() {
        if (type == 'front') _nricFront = File(pickedFile.path);
        if (type == 'back') _nricBack = File(pickedFile.path);
        if (type == 'selfie') _nricSelfie = File(pickedFile.path);
      });
    }
  }

  Future<String> uploadImage(File file, String type) async {
    final user = FirebaseAuth.instance.currentUser;
    final ref = FirebaseStorage.instance
        .ref()
        .child('seller_verification')
        .child('${user!.uid}_${type}_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  Future<void> submitVerification() async {
    if (_nricFront == null || _nricBack == null || _nricSelfie == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload all required images.')),
      );
      return;
    }
    setState(() => isLoading = true);

    final nricFrontUrl = await uploadImage(_nricFront!, 'front');
    final nricBackUrl = await uploadImage(_nricBack!, 'back');
    final nricSelfieUrl = await uploadImage(_nricSelfie!, 'selfie');

    await FirebaseFirestore.instance.collection('sellers').doc(widget.sellerDocId).update({
      'fullName': _fullNameController.text,
      'nricNumber': _nricController.text,
      'nricFrontUrl': nricFrontUrl,
      'nricBackUrl': nricBackUrl,
      'nricSelfieUrl': nricSelfieUrl,
      'verificationStatus': 'pending',
    });

    if (!mounted) return;
    setState(() => isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Verification submitted!')),
    );
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const SellerVerificationSuccessScreen()),
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
        title: const Text('Seller Verification', style: TextStyle(color: Colors.black)),
        centerTitle: true,
      ),
      backgroundColor: Colors.white,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text('Full Name', style: GoogleFonts.dmSans(fontWeight: FontWeight.w500)),
                    _buildTextField(_fullNameController, 'Enter Full Name'),
                    const SizedBox(height: 16),
                    Text('NRIC Number', style: GoogleFonts.dmSans(fontWeight: FontWeight.w500)),
                    _buildTextField(_nricController, 'Enter NRIC Number'),
                    const SizedBox(height: 24),
                    Text('Photo of NRIC', style: GoogleFonts.dmSans(fontWeight: FontWeight.w500)),
                    Text('Please upload a front and back of your NRIC',
                        style: GoogleFonts.dmSans(fontSize: 13, color: Colors.grey[600])),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildImagePicker(_nricFront, () => pickImage(ImageSource.gallery, 'front')),
                        const SizedBox(width: 16),
                        _buildImagePicker(_nricBack, () => pickImage(ImageSource.gallery, 'back')),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text('Please upload a image of you holding your NRIC',
                        style: GoogleFonts.dmSans(fontSize: 13, color: Colors.grey[600])),
                    const SizedBox(height: 4),
                    Text('*sample', style: GoogleFonts.dmSans(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3F0FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset('assets/nric_sample.png', fit: BoxFit.cover),
                          ),
                        ),
                        const SizedBox(width: 16),
                        _buildImagePicker(_nricSelfie, () => pickImage(ImageSource.gallery, 'selfie')),
                      ],
                    ),
                    const SizedBox(height: 100),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: submitVerification,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[400],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          'Submit',
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

  Widget _buildImagePicker(File? image, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: const Color(0xFFE3F0FF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: image == null
            ? const Icon(Icons.image, size: 80, color: Colors.grey)
            : ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(image, fit: BoxFit.cover),
              ),
      ),
    );
  }
} 