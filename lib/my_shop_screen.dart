import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'my_products_screen.dart';
import 'inbox_screen.dart';
import 'seller_order_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'my_finance_screen.dart';
import 'shop_performance_screen.dart';
import 'sales_history_screen.dart';
import 'seller_shop_screen.dart';
import 'my_ratings_screen.dart';
import 'welcome_screen.dart';

class MyShopScreen extends StatelessWidget {
  final String shopName;
  final String? profileImageUrl;

  const MyShopScreen({super.key, required this.shopName, this.profileImageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('My Shop', style: TextStyle(color: Colors.black)),
        centerTitle: true,
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            children: [
              const SizedBox(height: 8),
              CircleAvatar(
                radius: 44,
                backgroundImage: (profileImageUrl != null && profileImageUrl!.isNotEmpty)
                    ? NetworkImage(profileImageUrl!)
                    : const AssetImage('assets/default_profile.png') as ImageProvider,
              ),
              const SizedBox(height: 12),
              Text(
                shopName,
                style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () async {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SellerShopScreen(
                        sellerId: user.uid,
                        shopName: shopName,
                        profileImageUrl: profileImageUrl,
                      ),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  side: BorderSide(color: Colors.grey[300]!),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 0),
                ),
                child: Text('View Shop', style: GoogleFonts.dmSans()),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F0FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Order Status', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const SalesHistoryScreen()),
                            );
                          },
                          child: Text('View Sales History', style: GoogleFonts.dmSans(color: Colors.blueAccent, decoration: TextDecoration.underline)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _OrderStatusColumn(
                          label: 'To Ship',
                          status: 'to_ship',
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const SellerOrderScreen(initialTabIndex: 0)));
                          },
                        ),
                        _OrderStatusColumn(
                          label: 'Cancelled',
                          status: 'cancelled',
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const SellerOrderScreen(initialTabIndex: 3)));
                          },
                        ),
                        _OrderStatusColumn(
                          label: 'Return',
                          status: 'return_refund',
                           onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const SellerOrderScreen(initialTabIndex: 4)));
                          },
                        ),
                        _OrderStatusColumn(
                          label: 'Completed',
                          status: 'completed',
                           onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const SellerOrderScreen(initialTabIndex: 2)));
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F0FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ShopFeature(
                      icon: Icons.inventory_2,
                      label: 'My Products',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const MyProductsScreen()),
                        );
                      },
                    ),
                    const SizedBox(width: 28),
                    _ShopFeature(
                      icon: Icons.account_balance_wallet, 
                      label: 'My Finance',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const MyFinanceScreen()),
                        );
                      },
                    ),
                    const SizedBox(width: 18),
                    _ShopFeature(
                      icon: Icons.bar_chart, 
                      label: 'Shop Performance',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ShopPerformanceScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: Text('My Inbox', style: GoogleFonts.dmSans()),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const InboxScreen(role: 'seller')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.star_border),
                title: Text('My Ratings', style: GoogleFonts.dmSans()),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const MyRatingsScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.black54),
                title: Text('Sign Out', style: GoogleFonts.dmSans()),
                onTap: () async {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                      (route) => false,
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderStatusColumn extends StatelessWidget {
  final String label;
  final String status;
  final VoidCallback? onTap;
  const _OrderStatusColumn({required this.label, required this.status, this.onTap});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        children: [
          if (user == null)
            Text('0', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 18))
          else
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .where('sellerIds', arrayContains: user.uid)
                  .where(
                    (status == 'shipping' || status == 'completed')
                        ? 'sellerStatus'
                        : 'status',
                    isEqualTo: status,
                  )
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Text('-', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 18));
                }
                final count = snapshot.data?.docs.length ?? 0;
                return Text(
                  count.toString(),
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 18),
                );
              },
            ),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.dmSans(fontSize: 13)),
        ],
      ),
    );
  }
}

class _ShopFeature extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _ShopFeature({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, size: 32, color: Colors.blue[400]),
          ),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.dmSans(fontSize: 13)),
        ],
      ),
    );
  }
} 