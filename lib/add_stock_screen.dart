import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AddStockScreen extends StatefulWidget {
  final List<String> sizes;
  const AddStockScreen({super.key, required this.sizes});

  @override
  State<AddStockScreen> createState() => _AddStockScreenState();
}

class _AddStockScreenState extends State<AddStockScreen> {
  late Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (var size in widget.sizes) size: TextEditingController()
    };
  }

  @override
  void dispose() {
    for (var c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _isFormValid {
    for (var c in _controllers.values) {
      if (c.text.isEmpty || int.tryParse(c.text) == null || int.parse(c.text) < 0) {
        return false;
      }
    }
    return true;
  }

  void _onSave() async {
    if (!_isFormValid) return;
    final Map<String, int> stockMap = {
      for (var size in widget.sizes) size: int.parse(_controllers[size]!.text)
    };
    if (!mounted) return;
    Navigator.pop(context, stockMap);
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
        title: const Text('Add Stock Quantity', style: TextStyle(color: Colors.black)),
        centerTitle: true,
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(child: Text('Size', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold))),
                  Expanded(child: Text('Stock', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold))),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: widget.sizes.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final size = widget.sizes[index];
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F0FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(size, style: GoogleFonts.dmSans(color: Colors.grey[700])),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: TextField(
                              controller: _controllers[size],
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                hintText: '0',
                                border: InputBorder.none,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isFormValid ? _onSave : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[400],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text('Save', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 