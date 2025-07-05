import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'package:intl/intl.dart';

class ReturnRefundScreen extends StatefulWidget {
  final String orderId;
  const ReturnRefundScreen({super.key, required this.orderId});

  @override
  State<ReturnRefundScreen> createState() => _ReturnRefundScreenState();
}

class _ReturnRefundScreenState extends State<ReturnRefundScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedReason;
  String _otherReason = '';
  String _additionalComments = '';
  XFile? _pickedImage;
  bool _isSubmitting = false;

  String? _returnMethod;
  DateTime? _pickupDate;
  TimeOfDay? _pickupTime;

  final List<String> _reasons = [
    'Wrong item received',
    'Item damaged/defective',
    'Item not as described',
    'Missing parts/accessories',
    'Other',
  ];

  final List<String> _returnMethods = [
    'Drop off at location',
    'Request pick-up',
  ];

  Future<String?> _uploadImage(XFile image) async {
    final ref = FirebaseStorage.instance
        .ref('return_refund_images/${widget.orderId}_${DateTime.now().millisecondsSinceEpoch}');
    await ref.putData(await image.readAsBytes());
    return await ref.getDownloadURL();
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    if (date is Timestamp) {
      return DateFormat('yyyy-MM-dd').format(date.toDate());
    }
    if (date is String) {
      try {
        return DateFormat('yyyy-MM-dd').format(DateTime.parse(date));
      } catch (_) {
        return date;
      }
    }
    return date.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Return/Refund Request',
            style: GoogleFonts.dmSans(
                color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        centerTitle: true,
      ),
      backgroundColor: const Color(0xFFF9F9F9),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance.collection('orders').doc(widget.orderId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Order not found.'));
          }
          final data = snapshot.data!.data()!;
          // If a return/refund request already exists, show details
          if (data['status'] == 'return_refund') {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text('Status: ${data['refundStatus'] ?? '-'}', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
                if (data['refundStatus'] == 'rejected' && data['refundRejectReason'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text('Rejection Reason: ${data['refundRejectReason']}', style: GoogleFonts.dmSans(color: Colors.red)),
                  ),
                if (data['refundReason'] != null && data['refundReason'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text('Refund Reason: ${data['refundReason']}', style: GoogleFonts.dmSans()),
                  ),
                if (data['returnReason'] != null && data['returnReason'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text('Return Reason: ${data['returnReason']}', style: GoogleFonts.dmSans()),
                  ),
                if (data['returnComments'] != null && data['returnComments'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text('Comments: ${data['returnComments']}', style: GoogleFonts.dmSans()),
                  ),
                if (data['returnImageUrl'] != null && data['returnImageUrl'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Proof:', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            data['returnImageUrl'],
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) => Container(
                              width: 100,
                              height: 100,
                              color: Colors.grey[200],
                              child: const Icon(Icons.broken_image, size: 40, color: Colors.grey),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (data['returnMethod'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text('Return Method: ${data['returnMethod']}', style: GoogleFonts.dmSans()),
                  ),
                if (data['pickupDate'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'Pickup Date: \\${_formatDate(data['pickupDate'])}',
                      style: GoogleFonts.dmSans(),
                    ),
                  ),
                if (data['pickupTime'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text('Pickup Time: \\${data['pickupTime']}', style: GoogleFonts.dmSans()),
                  ),
              ],
            );
          }

          // Otherwise, show the form to submit a new request
          return SafeArea(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Please fill in the details below to request a return or refund.',
                          style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w500, fontSize: 15),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 18),
                        DropdownButtonFormField<String>(
                          value: _selectedReason,
                          items: _reasons
                              .map((reason) => DropdownMenuItem(
                                    value: reason,
                                    child: Text(reason,
                                        style: GoogleFonts.dmSans(fontSize: 15)),
                                  ))
                              .toList(),
                          onChanged: (val) => setState(() => _selectedReason = val),
                          decoration: InputDecoration(
                            labelText: 'Reason',
                            labelStyle: GoogleFonts.dmSans(),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            filled: true,
                            fillColor: Colors.blue[50],
                          ),
                          validator: (val) =>
                              val == null ? 'Please select a reason' : null,
                        ),
                        if (_selectedReason == 'Other') ...[
                          const SizedBox(height: 14),
                          TextFormField(
                            decoration: InputDecoration(
                              labelText: 'Other reason',
                              labelStyle: GoogleFonts.dmSans(),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: Colors.blue[50],
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                            ),
                            onChanged: (val) => _otherReason = val,
                            validator: (val) => _selectedReason == 'Other' &&
                                    (val == null || val.isEmpty)
                                ? 'Please specify your reason'
                                : null,
                          ),
                        ],
                        const SizedBox(height: 14),
                        TextFormField(
                          decoration: InputDecoration(
                            labelText: 'Additional comments (optional)',
                            labelStyle: GoogleFonts.dmSans(),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.blue[50],
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                          ),
                          maxLines: 2,
                          onChanged: (val) => _additionalComments = val,
                        ),
                        const SizedBox(height: 14),
                        if (_pickedImage != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(_pickedImage!.path),
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final picker = ImagePicker();
                            final picked = await picker.pickImage(
                                source: ImageSource.gallery);
                            if (picked != null) {
                              setState(() => _pickedImage = picked);
                            }
                          },
                          icon: const Icon(Icons.photo, size: 20),
                          label: Text('Add Photo',
                              style: GoogleFonts.dmSans(fontWeight: FontWeight.w500)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[400],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 10),
                          ),
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          value: _returnMethod,
                          items: _returnMethods
                              .map((method) => DropdownMenuItem(
                                    value: method,
                                    child: Text(method, style: GoogleFonts.dmSans(fontSize: 15)),
                                  ))
                              .toList(),
                          onChanged: (val) => setState(() => _returnMethod = val),
                          decoration: InputDecoration(
                            labelText: 'Return Method',
                            labelStyle: GoogleFonts.dmSans(),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            filled: true,
                            fillColor: Colors.blue[50],
                          ),
                          validator: (val) => val == null ? 'Please select a return method' : null,
                        ),
                        if (_returnMethod == 'Request pick-up') ...[
                          const SizedBox(height: 14),
                          ListTile(
                            title: Text(_pickupDate == null
                                ? 'Select pick-up date'
                                : 'Pick-up date: ${_pickupDate!.toLocal().toString().split(' ')[0]}'),
                            trailing: const Icon(Icons.calendar_today),
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now().add(const Duration(days: 1)),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 30)),
                              );
                              if (picked != null) setState(() => _pickupDate = picked);
                            },
                          ),
                          ListTile(
                            title: Text(_pickupTime == null
                                ? 'Select pick-up time'
                                : 'Pick-up time: ${_pickupTime!.format(context)}'),
                            trailing: const Icon(Icons.access_time),
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.now(),
                              );
                              if (picked != null) setState(() => _pickupTime = picked);
                            },
                          ),
                        ],
                        if (_returnMethod == 'Drop off at location') ...[
                          const SizedBox(height: 8),
                          Text(
                            'Please drop off your return package at any of the following courier branches: J&T, PosLaju, DHL, etc, after approval.',
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () async {
                            if (!_formKey.currentState!.validate()) return;
                            setState(() => _isSubmitting = true);

                            String? imageUrl;
                            if (_pickedImage != null) {
                              imageUrl = await _uploadImage(_pickedImage!);
                            }

                            final reason = _selectedReason == 'Other'
                                ? _otherReason
                                : _selectedReason;

                            await FirebaseFirestore.instance
                                .collection('orders')
                                .doc(widget.orderId)
                                .update({
                              'status': 'return_refund',
                              'sellerStatus': 'return_refund',
                              'returnReason': reason,
                              'returnComments': _additionalComments,
                              'returnImageUrl': imageUrl,
                              'returnRequestedAt': FieldValue.serverTimestamp(),
                              'refundStatus': 'pending',
                              'returnMethod': _returnMethod,
                              'pickupDate': _pickupDate?.toIso8601String(),
                              'pickupTime': _pickupTime != null ? _pickupTime!.format(context) : null,
                            });

                            if (mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Return/Refund request submitted.',
                                    style: GoogleFonts.dmSans(),
                                  ),
                                  backgroundColor: Colors.blue[400],
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text('Submit Request', style: GoogleFonts.dmSans()),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
} 