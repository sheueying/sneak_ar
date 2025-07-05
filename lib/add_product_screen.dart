import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'add_size_screen.dart';
import 'my_products_screen.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _brandController = TextEditingController();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();
  final List<XFile> _images = [];
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  Map<String, int>? _stockMap;

  bool get _isFormValid =>
      _images.isNotEmpty &&
      _brandController.text.isNotEmpty &&
      _nameController.text.isNotEmpty &&
      _descController.text.isNotEmpty &&
      _priceController.text.isNotEmpty &&
      _quantityController.text.isNotEmpty &&
      _stockMap != null && _stockMap!.isNotEmpty;

  Future<void> _pickImage() async {
    final picked = await _picker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() {
        _images.addAll(picked);
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
    });
  }

  void _onPublish() async {
    if (!_isFormValid) return;
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');
      // Upload images to Firebase Storage
      List<String> imageUrls = [];
      for (var img in _images) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('product_images/${user.uid}_${DateTime.now().millisecondsSinceEpoch}_${img.name}');
        await ref.putFile(File(img.path));
        final url = await ref.getDownloadURL();
        imageUrls.add(url);
      }
      // Save product to Firestore
      await FirebaseFirestore.instance.collection('products').add({
        'brand': _brandController.text.trim(),
        'name': _nameController.text.trim(),
        'description': _descController.text.trim(),
        'price': _priceController.text.trim(),
        'quantity': int.tryParse(_quantityController.text.trim()) ?? 0,
        'sold': 0,
        'sellerId': user.uid,
        'imageUrls': imageUrls,
        'createdAt': FieldValue.serverTimestamp(),
        'stock': _stockMap,
      });
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product published successfully!')),
      );
      await Future.delayed(const Duration(milliseconds: 500));
      Navigator.pushAndRemoveUntil(
        // ignore: use_build_context_synchronously
        context,
        MaterialPageRoute(builder: (context) => const MyProductsScreen()),
        (route) => route.isFirst,
      );
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to publish: \n$e')),
      );
    }
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
        title: const Text('Add Product', style: TextStyle(color: Colors.black)),
        centerTitle: true,
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text('Upload product image', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              SizedBox(
                height: 120,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _images.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    if (index < _images.length) {
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(_images[index].path),
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () => _removeImage(index),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withAlpha(80),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, color: Colors.white, size: 20),
                              ),
                            ),
                          ),
                        ],
                      );
                    } else {
                      return GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: 120,
                          height: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3F0FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.add_photo_alternate, size: 50, color: Colors.grey),
                        ),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: 24),
              Text('Brand', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              TextField(
                controller: _brandController,
                decoration: InputDecoration(
                  hintText: 'Enter Brand',
                  filled: true,
                  fillColor: const Color(0xFFF0F6FF),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              Text('Product Name', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'Enter Product Name',
                  filled: true,
                  fillColor: const Color(0xFFF0F6FF),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              Text('Product Description', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              TextField(
                controller: _descController,
                decoration: InputDecoration(
                  hintText: 'Enter Product Description',
                  filled: true,
                  fillColor: const Color(0xFFF0F6FF),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                maxLines: 2,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              Text('Price', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              TextField(
                controller: _priceController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: 'Enter Product Price',
                  filled: true,
                  fillColor: const Color(0xFFF0F6FF),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              Text('Quantity', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              TextField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Enter Product Quantity',
                  filled: true,
                  fillColor: const Color(0xFFF0F6FF),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Product Size and Stock', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () async {
                      final stockMap = await Navigator.push<Map<String, int>>(
                        context,
                        MaterialPageRoute(builder: (context) => const AddSizeScreen()),
                      );
                      if (stockMap != null) {
                        setState(() {
                          _stockMap = stockMap;
                        });
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 120),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isFormValid && !_isLoading ? _onPublish : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[400],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text('Publish', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _priceController.dispose();
    _descController.dispose();
    _brandController.dispose();
    _nameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }
} 