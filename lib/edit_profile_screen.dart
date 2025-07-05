import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;


class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  String? profileImageUrl;
  bool isLoading = true;
  bool isEditing = false;
  // Google Places API
  final String _googleApiKey = "AIzaSyASkFODp_TCgNG8HsI_9R1NtdVz82uP_h8";
  List<Map<String, dynamic>> _addressSuggestions = [];

  @override
  void initState() {
    super.initState();
    fetchUserData();
    _addressController.addListener(_onAddressChanged);
  }

  void _onAddressChanged() async {
    if (!isEditing) return;
    final input = _addressController.text;
    if (input.isEmpty) {
      setState(() => _addressSuggestions = []);
      return;
    }
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${Uri.encodeComponent(input)}&types=address&components=country:MY&key=$_googleApiKey',
    );
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        _addressSuggestions = (data['predictions'] as List)
            .map((p) => {
                  'description': p['description'],
                  'place_id': p['place_id'],
                })
            .toList();
      });
    } else {
      setState(() {
        _addressSuggestions = [];
      });
    }
  }

  Future<void> _selectAddressSuggestion(Map<String, dynamic> suggestion) async {
    setState(() => _addressSuggestions = []);
    _addressController.removeListener(_onAddressChanged);
    final placeId = suggestion['place_id'];
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=formatted_address&key=$_googleApiKey',
    );
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final result = data['result'];
      if (result != null) {
        setState(() {
          _addressController.text = result['formatted_address'] ?? '';
        });
      }
    }
    _addressController.addListener(_onAddressChanged);
  }

  Future<void> fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.data();
      if (!mounted) return;
      setState(() {
        _nameController.text = data?['username'] ?? '';
        _emailController.text = data?['email'] ?? '';
        _phoneController.text = data?['phone'] ?? '';
        _addressController.text = data?['address'] ?? '';
        profileImageUrl = data?['profileImageUrl'];
        isLoading = false;
      });
    }
  }

  Future<void> saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'username': _nameController.text,
        'email': _emailController.text,
        'phone': _phoneController.text,
        'address': _addressController.text,
      });
      if (!mounted) return;
      setState(() {
        isEditing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );
    }
  }

  Future<void> pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 80);

    if (pickedFile != null) {
      File imageFile = File(pickedFile.path);
      await uploadProfileImage(imageFile);
    }
  }

  Future<void> uploadProfileImage(File imageFile) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('${user.uid}.jpg');
      await ref.putFile(imageFile);
      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'profileImageUrl': url,
      });

      if (!mounted) return;
      setState(() {
        profileImageUrl = url;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile image updated!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(isEditing ? Icons.check : Icons.edit, color: Colors.black),
            onPressed: () {
              if (isEditing) {
                saveProfile();
              } else {
                setState(() {
                  isEditing = true;
                });
              }
            },
          ),
        ],
        centerTitle: true,
      ),
      backgroundColor: const Color(0xFFF9F9F9),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundImage: (profileImageUrl != null && profileImageUrl!.isNotEmpty)
                            ? NetworkImage(profileImageUrl!)
                            : const AssetImage('assets/default_profile.png') as ImageProvider,
                      ),
                      Positioned(
                        bottom: -10,
                        child: GestureDetector(
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              builder: (context) => SafeArea(
                                child: Wrap(
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.camera_alt),
                                      title: const Text('Take Photo'),
                                      onTap: () {
                                        Navigator.pop(context);
                                        pickImage(ImageSource.camera);
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.photo_library),
                                      title: const Text('Choose from Gallery'),
                                      onTap: () {
                                        Navigator.pop(context);
                                        pickImage(ImageSource.gallery);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.white,
                            child: Icon(Icons.camera_alt, size: 20, color: Colors.blue[400]),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _nameController.text,
                    style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  _buildLabel('Full Name'),
                  _buildTextField(_nameController, 'Full Name', enabled: isEditing),
                  const SizedBox(height: 16),
                  _buildLabel('Email Address'),
                  _buildTextField(_emailController, 'Email Address', enabled: false),
                  const SizedBox(height: 16),
                  _buildLabel('Phone Number'),
                  _buildTextField(_phoneController, 'Phone Number', enabled: isEditing),
                  const SizedBox(height: 16),
                  _buildLabel('Address'),
                  _buildTextField(_addressController, 'Address', maxLines: 2, enabled: isEditing),
                  const SizedBox(height: 32),
                  if (isEditing)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[400],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.bold),
                        ),
                        child: const Text('Save Changes'),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: GoogleFonts.dmSans(fontWeight: FontWeight.w500, fontSize: 15),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {bool enabled = true, int maxLines = 1}) {
    if (controller == _addressController) {
      return Stack(
        children: [
          TextField(
            controller: controller,
            enabled: enabled,
            maxLines: maxLines,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFE3F0FF),
              hintText: hint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
            style: GoogleFonts.dmSans(),
          ),
          if (_addressSuggestions.isNotEmpty && enabled)
            Container(
              margin: const EdgeInsets.only(top: 60),
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _addressSuggestions.length,
                itemBuilder: (context, index) {
                  final s = _addressSuggestions[index];
                  return ListTile(
                    title: Text(s['description'] ?? ''),
                    onTap: () => _selectAddressSuggestion(s),
                  );
                },
              ),
            ),
        ],
      );
    } else {
      return TextField(
        controller: controller,
        enabled: enabled,
        maxLines: maxLines,
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color(0xFFE3F0FF),
          hintText: hint,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        ),
        style: GoogleFonts.dmSans(),
      );
    }
  }

  @override
  void dispose() {
    _addressController.removeListener(_onAddressChanged);
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }
} 