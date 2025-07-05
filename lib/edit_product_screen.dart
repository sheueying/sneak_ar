import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class EditProductScreen extends StatefulWidget {
  final String productId;
  final Map<String, dynamic> productData;
  const EditProductScreen({super.key, required this.productId, required this.productData});

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  late TextEditingController _brandController;
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _priceController;
  late Map<String, TextEditingController> _stockControllers;
  List<String> _imageUrls = [];
  final List<XFile> _newImages = [];
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final data = widget.productData;
    _brandController = TextEditingController(text: data['brand'] ?? '');
    _nameController = TextEditingController(text: data['name'] ?? '');
    _descController = TextEditingController(text: data['description'] ?? '');
    _priceController = TextEditingController(text: data['price']?.toString() ?? '');
    _imageUrls = (data['imageUrls'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final stockMap = data['stock'] as Map<String, dynamic>? ?? {};
    _stockControllers = {
      for (var entry in stockMap.entries)
        entry.key: TextEditingController(text: entry.value.toString())
    };
  }

  @override
  void dispose() {
    _brandController.dispose();
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    for (var c in _stockControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _isFormValid =>
      _brandController.text.isNotEmpty &&
      _nameController.text.isNotEmpty &&
      _descController.text.isNotEmpty &&
      _priceController.text.isNotEmpty &&
      (_imageUrls.isNotEmpty || _newImages.isNotEmpty) &&
      _stockControllers.values.every((c) => c.text.isNotEmpty);

  Future<void> _pickImage() async {
    final picked = await _picker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() {
        _newImages.addAll(picked);
      });
    }
  }

  void _removeImage(int index, {bool isNew = false}) {
    setState(() {
      if (isNew) {
        _newImages.removeAt(index);
      } else {
        _imageUrls.removeAt(index);
      }
    });
  }

  Future<void> _onSave() async {
    if (!_isFormValid) return;
    setState(() => _isLoading = true);
    try {
      // Upload new images
      List<String> allImageUrls = List.from(_imageUrls);
      for (var img in _newImages) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('product_images/${widget.productId}_${DateTime.now().millisecondsSinceEpoch}_${img.name}');
        await ref.putFile(File(img.path));
        final url = await ref.getDownloadURL();
        allImageUrls.add(url);
      }
      // Prepare stock map
      final stockMap = {
        for (var entry in _stockControllers.entries)
          entry.key: int.tryParse(entry.value.text) ?? 0
      };
      // Calculate total quantity
      final totalQuantity = stockMap.values.fold<int>(0, (sum, qty) => sum + qty);
      // Update Firestore
      await FirebaseFirestore.instance.collection('products').doc(widget.productId).update({
        'brand': _brandController.text.trim(),
        'name': _nameController.text.trim(),
        'description': _descController.text.trim(),
        'price': _priceController.text.trim(),
        'imageUrls': allImageUrls,
        'stock': stockMap,
        'quantity': totalQuantity,
      });
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product updated successfully!')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update: \n$e')),
      );
    }
  }

  void _showAddSizeDialog() {
    final formKey = GlobalKey<FormState>();
    final sizeController = TextEditingController();
    final stockController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Add New Size & Stock', style: GoogleFonts.dmSans()),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: sizeController,
                  decoration: const InputDecoration(labelText: 'Size (e.g., UK 8)'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a size';
                    }
                    if (_stockControllers.containsKey(value.trim())) {
                      return 'This size already exists';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: stockController,
                  decoration: const InputDecoration(labelText: 'Stock Quantity'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null ||
                        value.isEmpty ||
                        int.tryParse(value) == null ||
                        int.parse(value) < 0) {
                      return 'Enter a valid stock number';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final newSize = sizeController.text.trim();
                  setState(() {
                    _stockControllers[newSize] = TextEditingController(text: stockController.text);
                  });
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
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
        title: const Text('Edit Product', style: TextStyle(color: Colors.black)),
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
              Text('Product Images', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _imageUrls.length + _newImages.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    if (index < _imageUrls.length) {
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              _imageUrls[index],
                              width: 80,
                              height: 80,
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
                    } else if (index < _imageUrls.length + _newImages.length) {
                      final newIndex = index - _imageUrls.length;
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(_newImages[newIndex].path),
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () => _removeImage(newIndex, isNew: true),
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
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3F0FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.add_photo_alternate, size: 36, color: Colors.grey),
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
              ),
              const SizedBox(height: 16),
              Text('Stock', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _stockControllers.entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 60,
                        child: Text(entry.key, style: GoogleFonts.dmSans(fontSize: 13)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: entry.value,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: '0',
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                )).toList(),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _showAddSizeDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add New Size & Stock'),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isFormValid && !_isLoading ? _onSave : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[400],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text('Save', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 