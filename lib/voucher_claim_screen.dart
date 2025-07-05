import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class VoucherClaimScreen extends StatelessWidget {
  const VoucherClaimScreen({super.key});

  Future<void> claimVoucher(BuildContext context, String voucherId, Map<String, dynamic> voucherData) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final userVoucherRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('vouchers')
        .doc(voucherId);

    final userVoucher = await userVoucherRef.get();
    if (userVoucher.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You have already claimed this voucher!')),
      );
      return;
    }

    await userVoucherRef.set({
      ...voucherData,
      'used': false,
      'claimedAt': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Voucher claimed!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Available Vouchers', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      backgroundColor: const Color(0xFFF8FBFD),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('vouchers')
            .where('isActive', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final vouchers = snapshot.data!.docs;
          if (vouchers.isEmpty) return Center(child: Text('No vouchers available.', style: GoogleFonts.dmSans()));
          return ListView.builder(
            itemCount: vouchers.length,
            itemBuilder: (context, index) {
              final data = vouchers[index].data() as Map<String, dynamic>;
              final voucherId = vouchers[index].id;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  title: Text(data['code'] ?? '', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
                  subtitle: Text(data['description'] ?? '', style: GoogleFonts.dmSans()),
                  trailing: ElevatedButton(
                    child: Text('Claim', style: GoogleFonts.dmSans()),
                    onPressed: () => claimVoucher(context, voucherId, data),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
} 