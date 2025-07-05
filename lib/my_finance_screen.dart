import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shoefit_application/order_income_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shoefit_application/transaction_history_screen.dart';
import 'package:shoefit_application/withdrawal_screen.dart';

class MyFinanceScreen extends StatelessWidget {
  const MyFinanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('My Finance', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, color: Colors.black)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF9F9F9),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total Balance', style: GoogleFonts.dmSans(color: Colors.grey[700])),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const TransactionHistoryScreen()),
                          );
                        },
                        child: Text(
                          'Transaction >',
                          style: GoogleFonts.dmSans(color: Colors.blueAccent, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (user == null)
                    Text(
                      'RM 0.00',
                      style: GoogleFonts.dmSans(fontSize: 32, fontWeight: FontWeight.bold),
                    )
                  else
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('orders')
                          .where('sellerIds', arrayContains: user.uid)
                          .where('status', isEqualTo: 'completed')
                          .snapshots(),
                      builder: (context, ordersSnapshot) {
                        if (ordersSnapshot.connectionState == ConnectionState.waiting) {
                          return Text('Calculating...', style: GoogleFonts.dmSans(fontSize: 28, fontWeight: FontWeight.bold));
                        }
                        if (ordersSnapshot.hasError || !ordersSnapshot.hasData) {
                          return Text('RM 0.00', style: GoogleFonts.dmSans(fontSize: 32, fontWeight: FontWeight.bold));
                        }

                        double totalIncome = 0.0;
                        for (final doc in ordersSnapshot.data!.docs) {
                          final orderData = doc.data() as Map<String, dynamic>;
                          final items = (orderData['items'] as List<dynamic>);
                          for (final item in items) {
                            if (item['sellerId'] == user.uid) {
                              final price = (item['price'] as num?) ?? 0;
                              final quantity = (item['quantity'] as num?) ?? 1;
                              totalIncome += price * quantity;
                            }
                          }
                        }

                        // --- REFUND STREAM ---
                        return StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('sellers')
                              .doc(user.uid)
                              .collection('refunds')
                              .snapshots(),
                          builder: (context, refundsSnapshot) {
                            double totalRefunds = 0.0;
                            if (refundsSnapshot.hasData) {
                              for (final doc in refundsSnapshot.data!.docs) {
                                final data = doc.data() as Map<String, dynamic>;
                                totalRefunds += (data['amount'] as num?)?.toDouble() ?? 0.0;
                              }
                            }

                            // --- WITHDRAWALS STREAM ---
                            return StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('withdrawals')
                                  .where('userId', isEqualTo: user.uid)
                                  .where('status', isEqualTo: 'approved')
                                  .snapshots(),
                              builder: (context, withdrawalsSnapshot) {
                                if (withdrawalsSnapshot.connectionState == ConnectionState.waiting && !withdrawalsSnapshot.hasData) {
                                   return Text('Calculating...', style: GoogleFonts.dmSans(fontSize: 28, fontWeight: FontWeight.bold));
                                }
                                double totalWithdrawals = 0.0;
                                if (withdrawalsSnapshot.hasData) {
                                  for (final doc in withdrawalsSnapshot.data!.docs) {
                                    final data = doc.data() as Map<String, dynamic>;
                                    totalWithdrawals += (data['amount'] as num?)?.toDouble() ?? 0.0;
                                  }
                                }

                                final netBalance = totalIncome - totalRefunds - totalWithdrawals;

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'RM ${netBalance.toStringAsFixed(2)}',
                                      style: GoogleFonts.dmSans(fontSize: 32, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 16),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: ElevatedButton(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(builder: (context) => WithdrawalScreen(currentBalance: netBalance)),
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue[400],
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                        ),
                                        child: const Text('Withdraw'),
                                      ),
                                    ),
                                  ],
                                );
                              }
                            );
                          }
                        );
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.receipt_long, color: Colors.black54),
              title: Text('Order Income', style: GoogleFonts.dmSans()),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const OrderIncomeScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
} 