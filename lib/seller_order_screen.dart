import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'arrange_shipment_screen.dart';

class SellerOrderScreen extends StatefulWidget {
  final int initialTabIndex;
  const SellerOrderScreen({super.key, this.initialTabIndex = 0});

  @override
  State<SellerOrderScreen> createState() => _SellerOrderScreenState();
}

class _SellerOrderScreenState extends State<SellerOrderScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = ['To Ship', 'Shipping', 'Completed', 'Cancellation', 'Return/Refund'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this, initialIndex: widget.initialTabIndex);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, String> statusMap = {
      'To Ship': 'to_ship',
      'Shipping': 'shipping',      // sellerStatus
      'Completed': 'completed',    // sellerStatus
      'Cancellation': 'cancelled',
      'Return/Refund': 'return_refund',
    };

    return Scaffold(
      appBar: AppBar(
        title: Text('My Sales', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, color: Colors.black)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _tabs.map((String title) => Tab(text: title)).toList(),
          labelStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w500),
          unselectedLabelStyle: GoogleFonts.dmSans(),
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue[400],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs.map((tab) {
          final status = statusMap[tab] ?? 'unknown';
          return SellerOrderList(status: status);
        }).toList(),
      ),
    );
  }
}

class SellerOrderList extends StatefulWidget {
  final String status;
  const SellerOrderList({super.key, required this.status});

  @override
  State<SellerOrderList> createState() => _SellerOrderListState();
}

class _SellerOrderListState extends State<SellerOrderList> {
  void _showArrangeShipmentDialog(BuildContext context, String orderId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ArrangeShipmentScreen(orderId: orderId),
      ),
    );
  }

  void _showProductOrderDetail(BuildContext context, Map<String, dynamic> product, Map<String, dynamic> orderData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductOrderDetailScreen(product: product, orderData: orderData),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text("Please log in to see your sales."));
    }

    Query query = FirebaseFirestore.instance
        .collection('orders')
        .where('sellerIds', arrayContains: user.uid);

    if (widget.status == 'to_ship' || widget.status == 'cancelled') {
      query = query.where('status', isEqualTo: widget.status);
    } else if (widget.status == 'return_refund') {
      query = query.where('status', isEqualTo: 'return_refund');
    } else {
      query = query.where('sellerStatus', isEqualTo: widget.status);
    }

    query = query.orderBy('timestamp', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("No orders found. Note: A data model change is required to see seller orders.", style: GoogleFonts.dmSans()));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text("No orders in this category.", style: GoogleFonts.dmSans()));
        }

        final orders = snapshot.data!.docs;

        return ListView.builder(
          itemCount: orders.length,
          padding: const EdgeInsets.all(8),
          itemBuilder: (context, index) {
            final order = orders[index];
            final orderData = order.data() as Map<String, dynamic>;
            final allItems = orderData['items'] as List<dynamic>;

            final sellerItems = allItems.where((item) => item['sellerId'] == user.uid).toList();

            if (sellerItems.isEmpty) {
              return const SizedBox.shrink();
            }
            
            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...sellerItems.map((item) {
                      return InkWell(
                        onTap: () => _showProductOrderDetail(context, item, orderData),
                        child: SellerOrderItemTile(
                          item: item,
                          status: orderData['status'],
                        ),
                      );
                    }),
                    if (widget.status == 'to_ship') ...[
                      const Divider(height: 20, thickness: 1),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton(
                            onPressed: () => _showArrangeShipmentDialog(context, order.id),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[400],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: const Text('Arrange Shipment'),
                          ),
                        ],
                      ),
                    ],
                    if (widget.status == 'return_refund' && orderData['status'] == 'return_refund') ...[
                      const Divider(height: 20, thickness: 1),
                      // Refund/Return Status
                      if (orderData['refundStatus'] != null)
                        Text('Status:${orderData['refundStatus'].toString().toUpperCase()}', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
                      // Refund Reason (if present)
                      if (orderData['refundReason'] != null && orderData['refundReason'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text('Refund Reason: ${orderData['refundReason']}', style: GoogleFonts.dmSans()),
                        ),
                      // Return Reason (if present)
                      if (orderData['returnReason'] != null && orderData['returnReason'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text('Return Reason: ${orderData['returnReason']}', style: GoogleFonts.dmSans()),
                        ),
                      // Comments
                      if (orderData['returnComments'] != null && orderData['returnComments'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text('Comments: ${orderData['returnComments']}', style: GoogleFonts.dmSans()),
                        ),
                      // Proof Image
                      if (orderData['returnImageUrl'] != null && orderData['returnImageUrl'].toString().isNotEmpty)
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
                                  orderData['returnImageUrl'],
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
                      // Return Method
                      if (orderData['returnMethod'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text('Return Method: ${orderData['returnMethod']}', style: GoogleFonts.dmSans()),
                        ),
                      // Pickup Date
                      if (orderData['pickupDate'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text('Pickup Date: ${orderData['pickupDate']}', style: GoogleFonts.dmSans()),
                        ),
                      // Pickup Time
                      if (orderData['pickupTime'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text('Pickup Time: ${orderData['pickupTime']}', style: GoogleFonts.dmSans()),
                        ),
                      // Approve/Reject Buttons
                      if (orderData['refundStatus'] == 'pending') ...[
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton(
                              onPressed: () async {
                                await FirebaseFirestore.instance.collection('orders').doc(order.id).update({
                                  'refundStatus': 'approved',
                                  'refundApprovedAt': FieldValue.serverTimestamp(),
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[400],
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.bold),
                              ),
                              child: const Text('Approve'),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton(
                              onPressed: () async {
                                String? rejectReason = await showDialog<String>(
                                  context: context,
                                  builder: (context) {
                                    final TextEditingController reasonController = TextEditingController();
                                    return AlertDialog(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                      title: Row(
                                        children: [
                                          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              'Reject Return/Refund?',
                                              style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 20),
                                            ),
                                          ),
                                        ],
                                      ),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Please provide a reason for rejection:', style: GoogleFonts.dmSans(fontWeight: FontWeight.w500)),
                                          const SizedBox(height: 6),
                                          TextField(
                                            controller: reasonController,
                                            minLines: 2,
                                            maxLines: 4,
                                            decoration: InputDecoration(
                                              hintText: 'Let the buyer know why you are rejecting...',
                                              filled: true,
                                              fillColor: Colors.grey[100],
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                            ),
                                          ),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(context).pop(),
                                          child: Text('Cancel', style: GoogleFonts.dmSans(color: Colors.grey[700], fontWeight: FontWeight.w500)),
                                        ),
                                        ElevatedButton(
                                          onPressed: () {
                                            if (reasonController.text.trim().isEmpty) return;
                                            Navigator.of(context).pop(reasonController.text.trim());
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red[400],
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                            textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.bold),
                                          ),
                                          child: const Text('Reject'),
                                        ),
                                      ],
                                    );
                                  },
                                );
                                if (rejectReason != null && rejectReason.isNotEmpty) {
                                  await FirebaseFirestore.instance.collection('orders').doc(order.id).update({
                                    'refundStatus': 'rejected',
                                    'refundRejectedAt': FieldValue.serverTimestamp(),
                                    'refundRejectReason': rejectReason,
                                  });
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.bold),
                              ),
                              child: const Text('Reject'),
                            ),
                          ],
                        ),
                      ],
                      if (orderData['refundStatus'] == 'approved')
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text('Refund/return approved. Waiting for buyer to return item.', style: GoogleFonts.dmSans(color: Colors.green[700])),
                        ),
                      if (orderData['refundStatus'] == 'rejected')
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text('Refund/return rejected.', style: GoogleFonts.dmSans(color: Colors.red)),
                        ),
                      if (orderData['refundStatus'] == null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text('Refund/return status unknown.', style: GoogleFonts.dmSans(color: Colors.grey)),
                        ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class SellerOrderItemTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final String status;
  const SellerOrderItemTile({super.key, required this.item, required this.status});

  String _formatStatus(String status) {
    return status.replaceAll('_', ' ').split(' ').map((l) => l[0].toUpperCase() + l.substring(1)).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: Image.network(
              item['image'] ?? '',
              width: 70,
              height: 70,
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, stack) => Container(
                width: 70,
                height: 70,
                color: Colors.grey[200],
                child: const Icon(Icons.broken_image, size: 40, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['name'] ?? 'No Name', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                if (item['size'] != null && item['size'].isNotEmpty) 
                  Text('Size: ${item['size']}', style: GoogleFonts.dmSans(color: Colors.grey[600])),
                const SizedBox(height: 4),
                Text('RM ${item['price']?.toStringAsFixed(2)}', style: GoogleFonts.dmSans(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Text(
            _formatStatus(status), 
            style: GoogleFonts.dmSans(color: Colors.grey[700], fontStyle: FontStyle.italic)
          ),
        ],
      ),
    );
  }
}

class ProductOrderDetailScreen extends StatelessWidget {
  final Map<String, dynamic> product;
  final Map<String, dynamic> orderData;
  const ProductOrderDetailScreen({super.key, required this.product, required this.orderData});

  Future<String> _fetchBuyerUsername(String userId) async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    return doc.data()?['username'] ?? userId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Product Order Detail', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      backgroundColor: Colors.grey[50],
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: ListView(
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12.0),
                      child: Image.network(
                        product['image'] ?? '',
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
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(product['name'] ?? 'No Name', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 20)),
                          if (product['size'] != null && product['size'].toString().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text('Size: ${product['size']}', style: GoogleFonts.dmSans(color: Colors.grey[700])),
                            ),
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text('RM ${product['price']?.toStringAsFixed(2)}', style: GoogleFonts.dmSans(fontWeight: FontWeight.w500, color: Colors.blue[700], fontSize: 16)),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text('Qty: ${product['quantity'] ?? 1}', style: GoogleFonts.dmSans()),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text('Order Information', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 17)),
            const SizedBox(height: 10),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.receipt_long, size: 20, color: Colors.blueGrey),
                        const SizedBox(width: 8),
                        Text('Order ID:', style: GoogleFonts.dmSans(fontWeight: FontWeight.w500)),
                        const SizedBox(width: 6),
                        Expanded(child: Text(orderData['orderId'] ?? '', style: GoogleFonts.dmSans())),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.info_outline, size: 20, color: Colors.blueGrey),
                        const SizedBox(width: 8),
                        Text('Status:', style: GoogleFonts.dmSans(fontWeight: FontWeight.w500)),
                        const SizedBox(width: 6),
                        Text(orderData['status'] ?? '', style: GoogleFonts.dmSans()),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.person, size: 20, color: Colors.blueGrey),
                        const SizedBox(width: 8),
                        Text('Buyer:', style: GoogleFonts.dmSans(fontWeight: FontWeight.w500)),
                        const SizedBox(width: 6),
                        FutureBuilder<String>(
                          future: _fetchBuyerUsername(orderData['userId'] ?? ''),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2));
                            }
                            return Text(snapshot.data ?? '', style: GoogleFonts.dmSans());
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.attach_money, size: 20, color: Colors.blueGrey),
                        const SizedBox(width: 8),
                        Text('Total:', style: GoogleFonts.dmSans(fontWeight: FontWeight.w500)),
                        const SizedBox(width: 6),
                        Text('RM ${orderData['totalAmount']?.toStringAsFixed(2) ?? ''}', style: GoogleFonts.dmSans()),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text('Shipping Information', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 17)),
            const SizedBox(height: 10),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (orderData['shippingDetails'] != null) ...[
                      Row(
                        children: [
                          const Icon(Icons.local_shipping, size: 20, color: Colors.blueGrey),
                          const SizedBox(width: 8),
                          Text('Courier:', style: GoogleFonts.dmSans(fontWeight: FontWeight.w500)),
                          const SizedBox(width: 6),
                          Text(orderData['shippingDetails']['courierName'] ?? '', style: GoogleFonts.dmSans()),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.confirmation_number, size: 20, color: Colors.blueGrey),
                          const SizedBox(width: 8),
                          Text('Tracking:', style: GoogleFonts.dmSans(fontWeight: FontWeight.w500)),
                          const SizedBox(width: 6),
                          Text(orderData['shippingDetails']['trackingNumber'] ?? '', style: GoogleFonts.dmSans()),
                        ],
                      ),
                    ],
                    if (orderData['shippingInfo'] != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.person_pin_circle, size: 20, color: Colors.blueGrey),
                          const SizedBox(width: 8),
                          Text('Recipient:', style: GoogleFonts.dmSans(fontWeight: FontWeight.w500)),
                          const SizedBox(width: 6),
                          Text(orderData['shippingInfo']['name'] ?? '', style: GoogleFonts.dmSans()),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 20, color: Colors.blueGrey),
                          const SizedBox(width: 8),
                          Text('Address:', style: GoogleFonts.dmSans(fontWeight: FontWeight.w500)),
                          const SizedBox(width: 6),
                          Expanded(child: Text(orderData['shippingInfo']['address'] ?? '', style: GoogleFonts.dmSans())),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.phone, size: 20, color: Colors.blueGrey),
                          const SizedBox(width: 8),
                          Text('Phone:', style: GoogleFonts.dmSans(fontWeight: FontWeight.w500)),
                          const SizedBox(width: 6),
                          Text(orderData['shippingInfo']['phone'] ?? '', style: GoogleFonts.dmSans()),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 