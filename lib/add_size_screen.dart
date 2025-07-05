import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'add_stock_screen.dart';

class AddSizeScreen extends StatefulWidget {
  const AddSizeScreen({super.key});

  @override
  State<AddSizeScreen> createState() => _AddSizeScreenState();
}

class _AddSizeScreenState extends State<AddSizeScreen> {
  final List<String> _sizes = [];
  final List<String> _allSizes = [
    'UK 4', 'UK 5', 'UK 6', 'UK 7', 'UK 8', 'UK 9', 'UK 10', 'UK 11', 'UK 12', 'UK 13'
  ];


  void _removeSize(int index) {
    setState(() {
      _sizes.removeAt(index);
    });
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
        title: const Text('Add Size', style: TextStyle(color: Colors.black)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('Size', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                itemCount: _sizes.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  if (index < _sizes.length) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F6FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        title: Text(_sizes[index], style: GoogleFonts.dmSans(color: Colors.grey[700])),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () => _removeSize(index),
                        ),
                      ),
                    );
                  } else {
                    // Add Size row
                    return GestureDetector(
                      onTap: () {
                        final availableSizes = _allSizes.where((s) => !_sizes.contains(s)).toList();
                        showModalBottomSheet(
                          context: context,
                          builder: (context) {
                            String? modalSelectedSize;
                            return StatefulBuilder(
                              builder: (context, setModalState) {
                                return Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      DropdownButtonFormField<String>(
                                        value: modalSelectedSize,
                                        items: availableSizes
                                            .map((size) => DropdownMenuItem(
                                                  value: size,
                                                  child: Text(size),
                                                ))
                                            .toList(),
                                        onChanged: (val) {
                                          setModalState(() {
                                            modalSelectedSize = val;
                                          });
                                        },
                                        decoration: const InputDecoration(
                                          labelText: 'Select Size',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: modalSelectedSize == null
                                              ? null
                                              : () {
                                                  Navigator.pop(context, modalSelectedSize);
                                                },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blue[400],
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                          ),
                                          child: Text('Add Size', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ).then((selectedSize) {
                          if (selectedSize != null && !_sizes.contains(selectedSize)) {
                            setState(() {
                              _sizes.add(selectedSize);
                            });
                          }
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F6FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        height: 48,
                        child: Center(
                          child: Text('+ Add Size', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _sizes.isNotEmpty ? () async {
                    final stockMap = await Navigator.push<Map<String, int>>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddStockScreen(sizes: _sizes),
                      ),
                    );
                    if (stockMap != null) {
                      if (!mounted) return;
                      // ignore: use_build_context_synchronously
                      Navigator.pop(context, stockMap);
                    }
                  } : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[400],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text('Next: Add Stock Quantity', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 