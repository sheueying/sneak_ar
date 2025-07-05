import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'voucher_claim_screen.dart';
import 'package:flutter/services.dart';

class VoucherScreen extends StatelessWidget {
  const VoucherScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: Text('My Vouchers', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: const Color(0xFFF8FBFD),
      body: user == null
          ? const Center(child: Text('Not logged in'))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.add_card_rounded, color: Color(0xFF5B8DEF)),
                      label: Text('Redeem More Vouchers', style: GoogleFonts.dmSans(fontWeight: FontWeight.w500, color: Color(0xFF5B8DEF))),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF5B8DEF)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        backgroundColor: Colors.white,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const VoucherClaimScreen()),
                        );
                      },
                    ),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .collection('vouchers')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final vouchers = snapshot.data!.docs;
                      if (vouchers.isEmpty) {
                        return Center(child: Text('No vouchers yet', style: GoogleFonts.dmSans()));
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: vouchers.length,
                        itemBuilder: (context, index) {
                          final data = vouchers[index].data() as Map<String, dynamic>;
                          return _VoucherCard(
                            discountText: data['discountText'] ?? '',
                            code: data['code'] ?? '',
                            description: data['description'] ?? '',
                            termsUrl: data['termsUrl'],
                            onApply: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Voucher code copied: ${data['code']}', style: GoogleFonts.dmSans())),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class _VoucherCard extends StatelessWidget {
  final String discountText;
  final String code;
  final String description;
  final String? termsUrl;
  final VoidCallback onApply;

  const _VoucherCard({
    required this.discountText,
    required this.code,
    required this.description,
    this.termsUrl,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Discount label
            Container(
              width: 48,
              decoration: const BoxDecoration(
                color: Color(0xFF5B8DEF),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                ),
              ),
              child: Center(
                child: RotatedBox(
                  quarterTurns: -1,
                  child: Text(
                    'DISCOUNT',
                    style: GoogleFonts.dmSans(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ),
            // Voucher details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(discountText, style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(code, style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)),
                    const SizedBox(height: 4),
                    Text(description, style: GoogleFonts.dmSans(fontSize: 13, color: Colors.grey[700])),
                    if (termsUrl != null && termsUrl!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: GestureDetector(
                          onTap: () {
                            // 
                          },
                          child: Text(
                            '*Terms & conditions',
                            style: GoogleFonts.dmSans(fontSize: 13, color: Colors.blue, decoration: TextDecoration.underline),
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: code));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Voucher code copied: $code', style: GoogleFonts.dmSans())),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          side: BorderSide(color: Colors.grey[300]!),
                          padding: const EdgeInsets.symmetric(vertical: 0),
                        ),
                        child: Text('Apply Code', style: GoogleFonts.dmSans()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Remove/heart icon
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: Icon(Icons.favorite, color: Colors.red[300], size: 22),
            ),
          ],
        ),
      ),
    );
  }
} 