import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shoefit_application/checkout_screen.dart';
import 'return_refund_screen.dart';

class MyOrdersScreen extends StatefulWidget {
  final int initialTabIndex;
  const MyOrdersScreen({super.key, this.initialTabIndex = 0});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = ['To Pay', 'To Ship', 'To Receive', 'To Rate', 'Return/Refund'];
  final Map<String, String> _statusMap = {
    'To Pay': 'to_pay',
    'To Ship': 'to_ship',
    'To Receive': 'to_receive',
    'To Rate': 'to_rate',
    'Return/Refund': 'return_refund',
  };
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

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
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text('My Orders', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, color: Colors.black)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
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
          final status = _statusMap[tab] ?? tab.toLowerCase();
          return OrderList(status: status, parentContext: _scaffoldKey.currentContext);
        }).toList(),
      ),
    );
  }
}

class OrderList extends StatelessWidget {
  final String status;
  final BuildContext? parentContext;
  const OrderList({super.key, required this.status, this.parentContext});

  void _continueToCheckout(BuildContext context, List<dynamic> items, String orderId) async {
    final List<Map<String, dynamic>> directItems = List<Map<String, dynamic>>.from(items);
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutScreen(
          directItems: directItems,
          sourceOrderId: orderId,
        ),
      ),
    );
  }

  void _showCancelOrderDialog(BuildContext context, String orderId) {
    final TextEditingController reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Cancel Order?',
                style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 20),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to cancel this order? This action cannot be undone.',
              style: GoogleFonts.dmSans(fontSize: 15, color: Colors.grey[800]),
            ),
            const SizedBox(height: 18),
            Text('Reason for cancellation (optional):', style: GoogleFonts.dmSans(fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            TextField(
              controller: reasonController,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Let the seller know why you are cancelling...'
                    ,
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
            child: Text('No, Keep Order', style: GoogleFonts.dmSans(color: Colors.grey[700], fontWeight: FontWeight.w500)),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
                'refundStatus': 'pending',
                'refundReason': reasonController.text,
                'refundRequestedAt': FieldValue.serverTimestamp(),
              });
              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Refund/return request sent to seller.')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[400],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.bold),
            ),
            child: const Text('Yes, Request Refund/Return'),
          ),
        ],
      ),
    );
  }

  void _cancelOrder(BuildContext context, String orderId) async {
    await FirebaseFirestore.instance.collection('orders').doc(orderId).delete();
    if (context.mounted) {
      Navigator.of(context).pop(true);
    }
  }

  void _confirmOrderReceived(BuildContext context, String orderId) async {
    await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
      'status': 'to_rate',
      'sellerStatus': 'completed',
    });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order marked as received! Thank you for your purchase.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text("Please log in to see your orders."));
    }

    if (kDebugMode) {
      print('Current user: \\${user.uid}');
    }
    if (kDebugMode) {
      print('Querying for status: \\$status');
    }

    // Create the appropriate query based on the status
    Query query = FirebaseFirestore.instance
        .collection('orders')
        .where('userId', isEqualTo: user.uid);

    if (status == 'return_refund') {
      query = query.where('status', isEqualTo: 'return_refund');
    } else {
      query = query.where('status', isEqualTo: status);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          if (kDebugMode) {
            print('StreamBuilder error: \\${snapshot.error}');
          }
          return Center(child: Text("Something went wrong: \\${snapshot.error}"));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          if (kDebugMode) {
            print('StreamBuilder waiting for data...');
          }
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          if (kDebugMode) {
            print('No orders found for this query.');
          }
          return Center(child: Text("No orders in this category.", style: GoogleFonts.dmSans()));
        }

        if (kDebugMode) {
          print('Fetched docs: \\${snapshot.data!.docs.length}');
        }
        for (var doc in snapshot.data!.docs) {
          if (kDebugMode) {
            print('Order: \\${doc.id} data: \\${doc.data()}');
          }
        }

        final orders = snapshot.data!.docs;

        return ListView.builder(
          itemCount: orders.length,
          padding: const EdgeInsets.all(8),
          itemBuilder: (context, index) {
            final order = orders[index];
            final orderData = order.data() as Map<String, dynamic>;
            final items = orderData['items'] as List<dynamic>;
            final orderId = order.id;
            
            // Calculate the total quantity of all items in the order
            final totalQuantity = items.fold<int>(0, (sum, item) => sum + (item['quantity'] as int? ?? 1));

            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...items.map((item) => OrderItemTile(item: item)),
                    const Divider(height: 20, thickness: 1),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('$totalQuantity item(s)'),
                        Text(
                          'Total: RM ${orderData['totalAmount']?.toStringAsFixed(2)}',
                          style: GoogleFonts.dmSans(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    if (status == 'return_refund') ...[
                      const SizedBox(height: 8),
                      if (orderData['refundStatus'] != null)
                        Text('Status: ${orderData['refundStatus'].toString().toUpperCase()}', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
                      if (orderData['refundReason'] != null && orderData['refundReason'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text('Reason: ${orderData['refundReason']}', style: GoogleFonts.dmSans()),
                        ),
                      if (orderData['returnReason'] != null && orderData['returnReason'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text('Reason: ${orderData['returnReason']}', style: GoogleFonts.dmSans()),
                        ),
                      if (orderData['returnComments'] != null && orderData['returnComments'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text('Comments: ${orderData['returnComments']}', style: GoogleFonts.dmSans()),
                        ),
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
                      if (orderData['returnMethod'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text('Return Method: ${orderData['returnMethod']}', style: GoogleFonts.dmSans()),
                        ),
                      if (orderData['pickupDate'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text('Pickup Date: ${orderData['pickupDate']}', style: GoogleFonts.dmSans()),
                        ),
                      if (orderData['pickupTime'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text('Pickup Time: ${orderData['pickupTime']}', style: GoogleFonts.dmSans()),
                        ),
                    ],
                    if (status == 'to_receive' && orderData['shippingDetails'] != null)
                      _buildShippingDetails(context, orderData['shippingDetails']),
                    if (status == 'to_pay')
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton(
                            onPressed: () => _continueToCheckout(context, items, orderId),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[400],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: const Text('Pay Now'),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton(
                            onPressed: () => _cancelOrder(context, orderId),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: const Text('Cancel Order'),
                          ),
                        ],
                      ),
                    if (status == 'to_receive')
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton(
                              onPressed: () => _confirmOrderReceived(context, orderId),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[400],
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: const Text('Order Received'),
                            ),
                          ],
                        ),
                      ),
                    if (status == 'to_rate')
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton(
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ProductRatingScreen(
                                      orderId: orderId,
                                      products: items.map((item) => Map<String, dynamic>.from(item)).toList(),
                                      sellerId: orderData['sellerIds'] != null && orderData['sellerIds'].isNotEmpty ? orderData['sellerIds'][0] : '',
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[400],
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: const Text('Rate Products'),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton(
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ReturnRefundScreen(orderId: orderId),
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: const Text('Return/Refund'),
                            ),
                          ],
                        ),
                      ),
                    if (status == 'to_ship')
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => _showCancelOrderDialog(context, orderId),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: const Text('Cancel Order'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildShippingDetails(BuildContext context, Map<String, dynamic> shippingDetails) {
    final courier = shippingDetails['courierName'] ?? 'N/A';
    final trackingNumber = shippingDetails['trackingNumber'] ?? 'N/A';

    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue[100]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tracking Information', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Courier:', style: GoogleFonts.dmSans()),
                Text(courier, style: GoogleFonts.dmSans(fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Tracking No:', style: GoogleFonts.dmSans()),
                Text(trackingNumber, style: GoogleFonts.dmSans(fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy Tracking Number'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: trackingNumber));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tracking number copied to clipboard!')),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue[600],
                  side: BorderSide(color: Colors.blue[200]!),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class OrderItemTile extends StatelessWidget {
  final Map<String, dynamic> item;
  const OrderItemTile({super.key, required this.item});

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
                  Text(' ${item['size']}', style: GoogleFonts.dmSans(color: Colors.grey[600])),
                const SizedBox(height: 4),
                Text('RM ${item['price']?.toStringAsFixed(2)}', style: GoogleFonts.dmSans(fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- Product Rating Screen ---
class ProductRatingScreen extends StatefulWidget {
  final String orderId;
  final List<Map<String, dynamic>> products;
  final String sellerId;
  const ProductRatingScreen({super.key, required this.orderId, required this.products, required this.sellerId});

  @override
  State<ProductRatingScreen> createState() => _ProductRatingScreenState();
}

class _ProductRatingScreenState extends State<ProductRatingScreen> {
  final Map<String, int> _ratings = {};
  final Map<String, String> _reviews = {};
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Rate Your Products', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ...widget.products.map((product) {
            final productId = product['productId'];
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (product['image'] != null && product['image'].toString().isNotEmpty)
                          Image.network(product['image'], width: 60, height: 60, fit: BoxFit.cover),
                        const SizedBox(width: 12),
                        Expanded(child: Text(product['name'] ?? '', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: List.generate(5, (i) {
                        final star = i + 1;
                        return IconButton(
                          icon: Icon(
                            _ratings[productId] != null && _ratings[productId]! >= star
                                ? Icons.star
                                : Icons.star_border,
                            color: Colors.amber,
                          ),
                          onPressed: () {
                            setState(() {
                              _ratings[productId] = star;
                            });
                          },
                        );
                      }),
                    ),
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Write a review (optional)',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: const EdgeInsets.all(8),
                      ),
                      onChanged: (val) => _reviews[productId] = val,
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submitRatings,
            child: _isSubmitting
                ? const CircularProgressIndicator()
                : Text('Submit Ratings', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _submitRatings() async {
    setState(() => _isSubmitting = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    for (final product in widget.products) {
      final productId = product['productId'];
      final rating = _ratings[productId];
      if (rating != null) {
        await FirebaseFirestore.instance
            .collection('products')
            .doc(productId)
            .collection('ratings')
            .doc(user.uid)
            .set({
          'rating': rating,
          'review': _reviews[productId] ?? '',
          'timestamp': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }

    // Update order status to 'completed' for both buyer and seller
    await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).update({
      'status': 'completed',
      'sellerStatus': 'completed',
    });

    // Show shop rating dialog before popping
    await showShopRatingDialog(context, widget.sellerId);

    if (mounted) {
      setState(() => _isSubmitting = false);
      Navigator.of(context).pop(true);
    }
  }
}

// --- Shop Rating Dialog ---
Future<void> showShopRatingDialog(BuildContext context, String sellerId) async {
  int shopRating = 0;
  String shopReview = '';
  bool isSubmitting = false;
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  await showDialog(
    context: context,
    barrierDismissible: !isSubmitting,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Rate the Shop'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (sellerId.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      'Seller information is missing. You can still rate, but submission is disabled.',
                      style: TextStyle(color: Colors.red, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final star = i + 1;
                    return IconButton(
                      icon: Icon(
                        shopRating >= star ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 32,
                      ),
                      onPressed: isSubmitting
                          ? null
                          : () {
                              setState(() {
                                shopRating = star;
                              });
                            },
                    );
                  }),
                ),
                TextField(
                  enabled: !isSubmitting,
                  decoration: const InputDecoration(
                    hintText: 'Write a review (optional)',
                  ),
                  onChanged: (val) => shopReview = val,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: shopRating == 0 || isSubmitting || sellerId.isEmpty
                    ? null
                    : () async {
                        setState(() => isSubmitting = true);
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(sellerId)
                            .collection('shop_ratings')
                            .doc(user.uid)
                            .set({
                          'rating': shopRating,
                          'review': shopReview,
                          'timestamp': FieldValue.serverTimestamp(),
                        }, SetOptions(merge: true));
                        setState(() => isSubmitting = false);
                        Navigator.of(context).pop();
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit'),
              ),
            ],
          );
        },
      );
    },
  );
} 