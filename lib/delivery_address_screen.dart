import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'add_delivery_address_screen.dart';

class DeliveryAddressScreen extends StatefulWidget {
  final String selectedAddress;
  const DeliveryAddressScreen({super.key, required this.selectedAddress});

  @override
  State<DeliveryAddressScreen> createState() => _DeliveryAddressScreenState();
}

class _DeliveryAddressScreenState extends State<DeliveryAddressScreen> {
  List<String> addresses = [];
  String? selected;
  String? primaryAddress;

  @override
  void initState() {
    super.initState();
    selected = widget.selectedAddress;
    _fetchAddresses();
  }

  Future<void> _fetchAddresses() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Fetch primary address from user doc
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      setState(() {
        primaryAddress = userDoc.data()?['address'] as String?;
      });

      // Fetch subcollection addresses
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('addresses')
          .get();
      setState(() {
        addresses = snapshot.docs.map((doc) => doc['address'] as String).toList();
      });
    }
  }

  void _addAddress() async {
    final newAddress = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddDeliveryAddressScreen()),
    );
    if (newAddress != null) {
      _fetchAddresses();
    }
  }

  void _save() async {
    Navigator.pop(context, selected);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Delivery Address', style: GoogleFonts.dmSans(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (primaryAddress != null && primaryAddress!.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(primaryAddress!, style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
                    tileColor: selected == primaryAddress ? const Color(0xFFE3F0FF) : null,
                    trailing: selected == primaryAddress ? const Icon(Icons.radio_button_checked, color: Colors.green) : null,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    onTap: () => setState(() => selected = primaryAddress),
                  ),
                ),
              ...addresses.map((address) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(address, style: GoogleFonts.dmSans()),
                  tileColor: selected == address ? const Color(0xFFE3F0FF) : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (selected == address)
                        const Icon(Icons.radio_button_checked, color: Colors.green),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        tooltip: 'Delete',
                        onPressed: () async {
                          final user = FirebaseAuth.instance.currentUser;
                          if (user != null) {
                            // Find the document with this address
                            final snapshot = await FirebaseFirestore.instance
                                .collection('users')
                                .doc(user.uid)
                                .collection('addresses')
                                .where('address', isEqualTo: address)
                                .get();
                            for (var doc in snapshot.docs) {
                              await doc.reference.delete();
                            }
                            // If the deleted address was selected, clear selection
                            if (selected == address) {
                              setState(() {
                                selected = primaryAddress;
                              });
                            }
                            _fetchAddresses();
                          }
                        },
                      ),
                    ],
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onTap: () => setState(() => selected = address),
                ),
              )),
              const SizedBox(height: 8),
              ListTile(
                title: Text('+ Add An Address', style: GoogleFonts.dmSans()),
                tileColor: const Color(0xFFE3F0FF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                onTap: _addAddress,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[400],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    'Save',
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
} 