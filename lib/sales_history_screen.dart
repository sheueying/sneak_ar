import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
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
        title: Text('Sales History', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, color: Colors.black)),
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
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(child: Text("Error fetching sales. You may need to create a Firestore index.", style: GoogleFonts.dmSans()));
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final endOfDay = _endDate.add(const Duration(days: 1));
                      final docs = snapshot.data!.docs.where((doc) {
                        final timestamp = (doc.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
                        if (timestamp == null) return false;
                        final date = timestamp.toDate();
                        return date.isAfter(_startDate) && date.isBefore(endOfDay);
                      }).toList();
                      final List<_SoldItem> soldItems = [];
                      for (var doc in docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        final orderId = doc.id;
                        final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
                        final items = (data['items'] as List<dynamic>?) ?? [];
                        for (var item in items) {
                          if (item['sellerId'] == user.uid) {
                            soldItems.add(_SoldItem(
                              orderId: orderId,
                              productId: item['productId'] ?? '',
                              name: item['name'] ?? '',
                              image: (item['image'] ?? ''),
                              size: item['size']?.toString() ?? '',
                              price: double.tryParse(item['price'].toString()) ?? 0.0,
                              quantity: int.tryParse(item['quantity'].toString()) ?? 0,
                              dateSold: timestamp,
                            ));
                          }
                        }
                      }
                      soldItems.sort((a, b) => b.dateSold?.compareTo(a.dateSold ?? DateTime(2000)) ?? 0);
                      if (soldItems.isEmpty) {
                        return const Center(child: Text("No sales in this period."));
                      }
                      return ListView.separated(
                        itemCount: soldItems.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = soldItems[index];
                          return ListTile(
                            leading: item.image.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(item.image, width: 60, height: 60, fit: BoxFit.cover, errorBuilder: (c, o, s) => const Icon(Icons.image, size: 60)),
                                  )
                                : Container(width: 60, height: 60, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.image, size: 40)),
                            title: Text(item.name, style: GoogleFonts.dmSans(fontWeight: FontWeight.w500)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (item.size.isNotEmpty) Text('Size: ${item.size}', style: GoogleFonts.dmSans(fontSize: 13)),
                                Text('Order: ${item.orderId}', style: GoogleFonts.dmSans(fontSize: 12, color: Colors.grey[600])),
                                if (item.dateSold != null)
                                  Text('Sold: ${DateFormat('yyyy-MM-dd').format(item.dateSold!)}', style: GoogleFonts.dmSans(fontSize: 12, color: Colors.grey[600])),
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('RM${item.price.toStringAsFixed(2)}', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
                                Text('x${item.quantity}', style: GoogleFonts.dmSans(fontSize: 13)),
                              ],
                            ),
                            onTap: () {
                              _showOrderDetails(context, item.orderId, item.productId);
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

  void _showOrderDetails(BuildContext context, String orderId, String highlightProductId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('orders').doc(orderId).get();
    if (!doc.exists) return;
    final data = doc.data() as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>?) ?? [];
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
    final buyerId = data['userId'] ?? '';
    String buyerName = buyerId;
    if (buyerId.isNotEmpty) {
      final buyerDoc = await FirebaseFirestore.instance.collection('users').doc(buyerId).get();
      if (buyerDoc.exists) {
        buyerName = buyerDoc.data()?['username'] ?? buyerId;
      }
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text('Order #$orderId', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 16)),
              if (timestamp != null)
                Text('Date: ${DateFormat('yyyy-MM-dd').format(timestamp)}', style: GoogleFonts.dmSans(fontSize: 13, color: Colors.grey[700])),
              Text('Buyer: $buyerName', style: GoogleFonts.dmSans(fontSize: 13, color: Colors.grey[700])),
              const SizedBox(height: 16),
              Text('Products', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...items.map<Widget>((item) {
                final isHighlight = item['productId'] == highlightProductId;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: isHighlight ? Colors.blue[50] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                    border: isHighlight ? Border.all(color: Colors.blueAccent, width: 2) : null,
                  ),
                  child: ListTile(
                    leading: item['image'] != null && item['image'].toString().isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(item['image'], width: 44, height: 44, fit: BoxFit.cover, errorBuilder: (c, o, s) => const Icon(Icons.image)),
                          )
                        : Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.image)),
                    title: Text(item['name'] ?? '', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item['size'] != null && item['size'].toString().isNotEmpty)
                          Text('Size: ${item['size']}', style: GoogleFonts.dmSans(fontSize: 12)),
                        Text('RM${(double.tryParse(item['price'].toString()) ?? 0.0).toStringAsFixed(2)} x${item['quantity']}', style: GoogleFonts.dmSans(fontSize: 12)),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SoldItem {
  final String orderId;
  final String productId;
  final String name;
  final String image;
  final String size;
  final double price;
  final int quantity;
  final DateTime? dateSold;
  _SoldItem({
    required this.orderId,
    required this.productId,
    required this.name,
    required this.image,
    required this.size,
    required this.price,
    required this.quantity,
    required this.dateSold,
  });
} 