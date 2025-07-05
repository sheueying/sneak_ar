import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class OrderIncomeScreen extends StatefulWidget {
  const OrderIncomeScreen({super.key});

  @override
  State<OrderIncomeScreen> createState() => _OrderIncomeScreenState();
}

class _OrderIncomeScreenState extends State<OrderIncomeScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != (isStartDate ? _startDate : _endDate)) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('Order Income', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, color: Colors.black)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      backgroundColor: const Color(0xFFF9F9F9),
      body: Column(
        children: [
          _buildDateFilters(),
          Expanded(
            child: user == null
                ? const Center(child: Text("Please log in."))
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('orders')
                        .where('sellerIds', arrayContains: user.uid)
                        .where('status', isEqualTo: 'completed')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(child: Text("Error fetching income. You may need to create a Firestore index.", style: GoogleFonts.dmSans()));
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      final endOfDay = _endDate.add(const Duration(days: 1));
                      final orders = snapshot.data!.docs.where((doc) {
                        final timestamp = (doc.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
                        if (timestamp == null) return false;
                        final date = timestamp.toDate();
                        return date.isAfter(_startDate) && date.isBefore(endOfDay);
                      }).toList();

                      if (orders.isEmpty) {
                        return const Center(child: Text("No income in this period."));
                      }

                      return ListView.separated(
                        itemCount: orders.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final order = orders[index];
                          final orderData = order.data() as Map<String, dynamic>;
                          // Filter items to only show those by the current seller
                          final sellerItems = (orderData['items'] as List)
                              .where((item) => item['sellerId'] == user.uid)
                              .toList();
                          
                          double sellerIncome = 0;
                          for(var item in sellerItems) {
                            sellerIncome += (item['price'] as num? ?? 0) * (item['quantity'] as num? ?? 1);
                          }

                          if (sellerItems.isEmpty) return const SizedBox.shrink();

                          final firstItem = sellerItems.first;
                          final timestamp = (orderData['timestamp'] as Timestamp).toDate();

                          return ListTile(
                            leading: Image.network(
                              firstItem['image'] ?? '', 
                              width: 60, 
                              height: 60,
                              errorBuilder: (c, o, s) => const Icon(Icons.image, size: 60),
                            ),
                            title: Text(firstItem['name'] ?? 'N/A', style: GoogleFonts.dmSans(fontWeight: FontWeight.w500)),
                            subtitle: Text(
                              'Order Created On ${DateFormat.yMMMd().format(timestamp)}\nPayment Transferred Successfully',
                              style: GoogleFonts.dmSans(color: Colors.green, fontSize: 12),
                            ),
                            trailing: Text(
                              '+ RM${sellerIncome.toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                            ),
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

  Widget _buildDateFilters() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _selectDate(context, true),
              child: Text(DateFormat.yMMMd().format(_startDate)),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: Text('--'),
          ),
          Expanded(
            child: OutlinedButton(
              onPressed: () => _selectDate(context, false),
              child: Text(DateFormat.yMMMd().format(_endDate)),
            ),
          ),
        ],
      ),
    );
  }
} 