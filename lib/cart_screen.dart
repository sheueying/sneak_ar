// ignore_for_file: empty_catches

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_screen.dart';
import 'favourite_screen.dart';
// import 'ar_cam_screen.dart';
import 'user_profile_screen.dart';
import 'widgets/bottom_nav_bar.dart';
import 'checkout_screen.dart';
import 'services/easyparcel_service.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final Set<String> _selectedItems = {};
  int _selectedIndex = 2;

  double? _shippingFee;
  bool _isFetchingShipping = false;
  String? _buyerPostcode;

  @override
  void initState() {
    super.initState();
    _fetchBuyerPostcode();
  }

  Future<void> _fetchBuyerPostcode() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final address = userDoc.data()?['address'] ?? '';
      final match = RegExp(r'\b(\d{5})\b').firstMatch(address);
      setState(() {
        _buyerPostcode = match?.group(1) ?? '';
      });
    }
  }

  Future<void> _fetchShippingFee(String? sellerId) async {
    if (kDebugMode) print('Entered _fetchShippingFee: sellerId=$sellerId, buyerPostcode=$_buyerPostcode');
    if (_buyerPostcode == null || _buyerPostcode!.isEmpty || sellerId == null) return;
    setState(() { _isFetchingShipping = true; });
    String sellerPostcode = '50450'; // fallback static seller postcode
    try {
      final sellerDoc = await FirebaseFirestore.instance.collection('sellers').doc(sellerId).get();
      final sellerData = sellerDoc.data();
      if (sellerData != null && sellerData['pickupAddress'] != null) {
        final pickupAddress = sellerData['pickupAddress'] as String;
        final match = RegExp(r'\b(\d{5})\b').firstMatch(pickupAddress);
        if (match != null) sellerPostcode = match.group(1)!;
      }
    } catch (e) {}
    if (kDebugMode) {
      print('Fetching shipping fee: sellerPostcode=$sellerPostcode, buyerPostcode=$_buyerPostcode');
    }
    try {
      final rates = await EasyParcelService.getRates(
        fromPostcode: sellerPostcode,
        toPostcode: _buyerPostcode!,
        weightKg: 1.0,
      );
      if (kDebugMode) {
        print('EasyParcel rates: $rates');
      }
      if (rates.isNotEmpty) {
        final cheapest = rates.reduce((a, b) => a.price < b.price ? a : b);
        setState(() { _shippingFee = cheapest.price; });
      } else {
        setState(() { _shippingFee = null; });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching shipping fee: $e');
      }
      setState(() { _shippingFee = null; });
    } finally {
      setState(() { _isFetchingShipping = false; });
    }
  }

  void _onTabTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else if (index == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const FavouriteScreen()),
      );
    } else if (index == 2) {
      // Already on Cart
    } else if (index == 3) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const UserProfileScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('Not logged in'));

    final cartRef = FirebaseFirestore.instance
        .collection('carts')
        .doc(user.uid)
        .collection('items');

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Cart', style: GoogleFonts.dmSans(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
        automaticallyImplyLeading: false,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: cartRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final items = snapshot.data!.docs;
          if (items.isEmpty) return const Center(child: Text('Cart is empty'));

          if (_buyerPostcode == null || _buyerPostcode!.isEmpty) {
            return Column(
              children: [
                Container(
                  color: Colors.yellow[100],
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Your address is missing or invalid. Please update your profile with a valid address including a 5-digit postcode.')),
                    ],
                  ),
                ),
              ],
            );
          }

          double subtotal = 0;
          for (var doc in items) {
            final data = doc.data() as Map<String, dynamic>;
            final itemId = doc.id;
            if (_selectedItems.contains(itemId)) {
              final price = double.tryParse(data['price'].toString()) ?? 0.0;
              final quantity = int.tryParse(data['quantity'].toString()) ?? 1;
              subtotal += price * quantity;
            }
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final data = items[i].data() as Map<String, dynamic>;
                    final itemId = items[i].id;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withAlpha((0.1 * 255).toInt()),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: _selectedItems.contains(itemId),
                              onChanged: (checked) {
                                setState(() {
                                  if (checked == true) {
                                    _selectedItems.add(itemId);
                                  } else {
                                    _selectedItems.remove(itemId);
                                  }
                                  // Fetch shipping fee for the first selected item
                                  if (_selectedItems.isNotEmpty) {
                                    var firstSelected;
                                    for (var doc in items) {
                                      if (_selectedItems.contains(doc.id)) {
                                        firstSelected = doc;
                                        break;
                                      }
                                    }
                                    if (firstSelected != null) {
                                      final sellerId = (firstSelected.data() as Map<String, dynamic>)['sellerId'];
                                      _fetchShippingFee(sellerId);
                                    }
                                  } else {
                                    _shippingFee = null;
                                  }
                                });
                              },
                            ),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                data['image'] ?? '',
                                width: 70,
                                height: 70,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  width: 70,
                                  height: 70,
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.image, color: Colors.grey),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data['name'] ?? '',
                                      style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 16),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '${data['size']}',
                                      style: GoogleFonts.dmSans(color: Colors.grey[600]),
                                    ),
                                    Text(
                                      'RM ${data['price']}',
                                      style: GoogleFonts.dmSans(color: Colors.grey[700]),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove, size: 20),
                                          onPressed: () {
                                            if ((data['quantity'] ?? 1) > 1) {
                                              cartRef.doc(items[i].id).update({'quantity': data['quantity'] - 1});
                                            }
                                          },
                                        ),
                                        Text('${data['quantity']}', style: GoogleFonts.dmSans()),
                                        IconButton(
                                          icon: const Icon(Icons.add, size: 20),
                                          onPressed: () {
                                            cartRef.doc(items[i].id).update({'quantity': data['quantity'] + 1});
                                          },
                                        ),
                                        const Spacer(),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                                          onPressed: () {
                                            cartRef.doc(items[i].id).delete();
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withAlpha((0.1 * 255).toInt()),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Subtotal', style: GoogleFonts.dmSans()),
                        Text('RM ${subtotal.toStringAsFixed(2)}', style: GoogleFonts.dmSans()),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Shipping', style: GoogleFonts.dmSans()),
                        Text(
                          _isFetchingShipping
                            ? 'Calculating...'
                            : _shippingFee != null
                                ? 'RM 	${_shippingFee!.toStringAsFixed(2)}'
                                : 'N/A',
                          style: GoogleFonts.dmSans(),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Cost', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
                        Text('RM ${(subtotal + (_shippingFee ?? 0)).toStringAsFixed(2)}', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (_selectedItems.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Please select at least one item to checkout.'),
                                backgroundColor: Colors.red[400],
                              ),
                            );
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CheckoutScreen(selectedItemIds: _selectedItems.toList()),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[400],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text('Checkout', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _onTabTapped,
      ),
    );
  }
} 