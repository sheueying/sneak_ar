import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// A model to represent a unified transaction
class Transaction {
  final String type; // 'income' or 'withdrawal'
  final double amount;
  final DateTime date;
  final String status;
  final String details;

  Transaction({
    required this.type,
    required this.amount,
    required this.date,
    required this.status,
    required this.details,
  });
}

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  late Future<List<Transaction>> _transactionsFuture;

  @override
  void initState() {
    super.initState();
    _transactionsFuture = _fetchTransactions();
  }

  Future<List<Transaction>> _fetchTransactions() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return [];
    }

    // 1. Fetch completed orders (income)
    final ordersQuery = FirebaseFirestore.instance
        .collection('orders')
        .where('sellerIds', arrayContains: user.uid)
        .where('status', isEqualTo: 'to_rate')
        .get();

    // 2. Fetch withdrawal requests
    final withdrawalsQuery = FirebaseFirestore.instance
        .collection('withdrawals')
        .where('userId', isEqualTo: user.uid)
        .get();

    final results = await Future.wait([ordersQuery, withdrawalsQuery]);
    
    final List<Transaction> transactions = [];

    // Process incomes
    final orderDocs = results[0].docs;
    for (final doc in orderDocs) {
      final data = doc.data();
      final items = (data['items'] as List<dynamic>);
      double orderIncome = 0;
      for (final item in items) {
        if (item['sellerId'] == user.uid) {
          orderIncome += (item['price'] ?? 0) * (item['quantity'] ?? 1);
        }
      }
       final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
      transactions.add(Transaction(
        type: 'income',
        amount: orderIncome,
        date: timestamp,
        status: 'Completed',
        details: 'Order #${doc.id.substring(0, 6)}',
      ));
    }

    // Process withdrawals
    final withdrawalDocs = results[1].docs;
    for (final doc in withdrawalDocs) {
      final data = doc.data();
      final timestamp = (data['requestedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
      transactions.add(Transaction(
        type: 'withdrawal',
        amount: (data['amount'] as num).toDouble(),
        date: timestamp,
        status: data['status'] ?? 'Unknown',
        details: 'To ${data['bankName']}',
      ));
    }

    // Sort all transactions by date, newest first
    transactions.sort((a, b) => b.date.compareTo(a.date));
    
    return transactions;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Transaction History', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: FutureBuilder<List<Transaction>>(
        future: _transactionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('An error occurred: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No transactions found.'));
          }

          final transactions = snapshot.data!;
          return ListView.builder(
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final trans = transactions[index];
              final isIncome = trans.type == 'income';

              IconData icon;
              Color color;
              String title;

              if (isIncome) {
                icon = Icons.arrow_downward;
                color = Colors.green;
                title = 'Order Income';
              } else { // Withdrawal
                title = 'Withdrawal Request';
                if (trans.status.toLowerCase() == 'pending') {
                  icon = Icons.schedule;
                  color = Colors.orange;
                } else { // Approved, Rejected, etc.
                  icon = Icons.arrow_upward;
                  color = Colors.red;
                }
              }

              return ListTile(
                leading: Icon(
                  icon,
                  color: color,
                ),
                title: Text(title, style: GoogleFonts.dmSans(fontWeight: FontWeight.w500)),
                subtitle: Text(
                  '${trans.details} • ${trans.status[0].toUpperCase()}${trans.status.substring(1)}', 
                  style: GoogleFonts.dmSans()
                ),
                trailing: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${isIncome ? '+' : '-'} RM ${trans.amount.toStringAsFixed(2)}',
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('MMM d, yyyy').format(trans.date),
                      style: GoogleFonts.dmSans(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
} 