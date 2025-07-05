import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ArrangeShipmentScreen extends StatefulWidget {
  final String orderId;
  const ArrangeShipmentScreen({super.key, required this.orderId});

  @override
  State<ArrangeShipmentScreen> createState() => _ArrangeShipmentScreenState();
}

class _ArrangeShipmentScreenState extends State<ArrangeShipmentScreen> {
  final formKey = GlobalKey<FormState>();
  final trackingController = TextEditingController();
  final otherCourierController = TextEditingController();
  String? selectedCourier;
  bool isSubmitting = false;
  String? submitError;
  Map<String, dynamic>? shippingDetails;
  bool isLoadingOrder = true;

  final List<String> couriers = [
    'J&T Express',
    'Pos Laju',
    'DHL eCommerce',
    'Ninja Van',
    'City-Link Express',
    'Shopee Xpress',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _fetchOrderShippingDetails();
  }

  Future<void> _fetchOrderShippingDetails() async {
    setState(() { isLoadingOrder = true; });
    final doc = await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).get();
    final data = doc.data();
    setState(() {
      shippingDetails = data?['shippingInfo'] ?? {};
      isLoadingOrder = false;
    });
  }

  @override
  void dispose() {
    trackingController.dispose();
    otherCourierController.dispose();
    super.dispose();
  }

  Future<void> confirmShipment() async {
    setState(() { isSubmitting = true; submitError = null; });
    try {
      final courierName = selectedCourier == 'Other' ? otherCourierController.text : selectedCourier;
      await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).update({
        'status': 'to_receive',
        'sellerStatus': 'shipping',
        'shippingDetails': {
          ...?shippingDetails,
          'courierName': courierName,
          'trackingNumber': trackingController.text,
          'shippedAt': FieldValue.serverTimestamp(),
        }
      });
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shipment info updated and buyer notified.')),
        );
      }
    } catch (e) {
      setState(() { submitError = 'Failed to update shipment: $e'; });
    } finally {
      setState(() { isSubmitting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Arrange Shipment', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      backgroundColor: Colors.grey[50],
      body: isLoadingOrder
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: formKey,
                child: ListView(
                  children: [
                    Text('Buyer Shipping Address', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 10),
                    _buildBuyerAddressBox(),
                    const SizedBox(height: 24),
                    Text('Your Shipment Details', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedCourier,
                      items: couriers.map((courier) => DropdownMenuItem(
                        value: courier,
                        child: Text(courier, style: GoogleFonts.dmSans()),
                      )).toList(),
                      onChanged: isSubmitting ? null : (val) => setState(() => selectedCourier = val),
                      decoration: InputDecoration(
                        labelText: 'Courier',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (value) => value == null || value.isEmpty ? 'Select a courier' : null,
                    ),
                    if (selectedCourier == 'Other') ...[
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: otherCourierController,
                        decoration: InputDecoration(
                          labelText: 'Enter Courier Name',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: (value) => value == null || value.isEmpty ? 'Enter courier name' : null,
                      ),
                    ],
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: trackingController,
                      decoration: InputDecoration(
                        labelText: 'Tracking Number',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (value) => value == null || value.isEmpty ? 'Enter tracking number' : null,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () {
                              if (formKey.currentState!.validate()) confirmShipment();
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[400],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      child: isSubmitting
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Confirm Shipment'),
                    ),
                    if (submitError != null) ...[
                      const SizedBox(height: 12),
                      Text(submitError!, style: const TextStyle(color: Colors.red)),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBuyerAddressBox() {
    final address = shippingDetails?['address'] ?? '';
    final postcode = shippingDetails?['postcode'] ?? '';
    final city = shippingDetails?['city'] ?? '';
    final state = shippingDetails?['state'] ?? '';
    final name = shippingDetails?['name'] ?? '';
    final phone = shippingDetails?['phone'] ?? '';
    if (address.isEmpty && postcode.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Text('No shipping address found.', style: GoogleFonts.dmSans(color: Colors.grey)),
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (name.isNotEmpty) Text(name, style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
          if (phone.isNotEmpty) Text(phone, style: GoogleFonts.dmSans()),
          if (address.isNotEmpty) Text(address, style: GoogleFonts.dmSans()),
          if (postcode.isNotEmpty || city.isNotEmpty || state.isNotEmpty)
            Text('$postcode $city, $state', style: GoogleFonts.dmSans()),
        ],
      ),
    );
  }
} 