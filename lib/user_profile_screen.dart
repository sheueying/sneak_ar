import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/bottom_nav_bar.dart';
import 'home_screen.dart';
import 'edit_profile_screen.dart';
import 'seller_registration_intro_screen.dart';
import 'my_shop_screen.dart';
import 'cart_screen.dart';
import 'favourite_screen.dart';
import 'welcome_screen.dart';
import 'my_orders_screen.dart';
import 'recent_view_screen.dart';
import 'inbox_screen.dart';
import 'voucher_screen.dart';
// import 'ar_cam_screen.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  String? username;
  String? email;
  String? profileImageUrl;
  bool isLoading = true;
  String? sellerStatus;
  String? shopName;
  int _selectedIndex = 3;

  @override
  void initState() {
    super.initState();
    fetchUserData();
    fetchSellerData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  Future<void> fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      setState(() {
        username = doc.data()?['username'] ?? '';
        email = doc.data()?['email'] ?? '';
        profileImageUrl = doc.data()?['profileImageUrl'];
        isLoading = false;
      });
    }
  }

  Future<void> fetchSellerData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('sellers').doc(user.uid).get();
      if (doc.exists) {
        setState(() {
          sellerStatus = doc.data()?['verificationStatus'];
          shopName = doc.data()?['storeName'];
        });
      }
    }
  }

  Stream<int> _orderCountStream(String status) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('orders')
        .where('userId', isEqualTo: user.uid)
        .where('status', isEqualTo: status)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
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
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const CartScreen()),
      );
    } else if (index == 3) {
      // Already on Profile
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Row(
                      children: [
                        sellerStatus == 'approved'
                          ? ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MyShopScreen(
                                      shopName: shopName ?? 'My Shop',
                                      profileImageUrl: profileImageUrl,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.store, color: Colors.white),
                              label: const Text('My Shop'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[400],
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w500),
                              ),
                            )
                          : ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const SellerRegistrationIntroScreen()),
                                );
                              },
                              icon: const Icon(Icons.storefront, size: 18),
                              label: const Text('Start Selling'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[400],
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w500),
                              ),
                            ),
                        const Spacer(),
                      ],
                    ),
                  ),
                  // Profile Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            CircleAvatar(
                              radius: 44,
                              backgroundImage: (profileImageUrl != null && profileImageUrl!.isNotEmpty)
                                  ? NetworkImage(profileImageUrl!)
                                  : const AssetImage('assets/default_profile.png') as ImageProvider,
                            ),
                        
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          username ?? 'No Name',
                          style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        if (email != null)
                          Text(
                            email!,
                            style: GoogleFonts.dmSans(fontSize: 14, color: Colors.grey),
                          ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () async {
                            final updated = await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                            );
                            if (updated == true) {
                              fetchUserData();
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            side: BorderSide(color: Colors.grey[300]!),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 0),
                          ),
                          child: Text('Edit Profile', style: GoogleFonts.dmSans()),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Order Status Row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        StreamBuilder<int>(
                          stream: _orderCountStream('to_pay'),
                          builder: (context, snapshot) => _OrderStatusItem(
                            icon: Icons.account_balance_wallet,
                            label: 'To Pay',
                            count: snapshot.data ?? 0,
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const MyOrdersScreen(initialTabIndex: 0)),
                              );
                            },
                          ),
                        ),
                        StreamBuilder<int>(
                          stream: _orderCountStream('to_ship'),
                          builder: (context, snapshot) => _OrderStatusItem(
                            icon: Icons.local_shipping,
                            label: 'To Ship',
                            count: snapshot.data ?? 0,
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const MyOrdersScreen(initialTabIndex: 1)),
                              );
                            },
                          ),
                        ),
                        StreamBuilder<int>(
                          stream: _orderCountStream('to_receive'),
                          builder: (context, snapshot) => _OrderStatusItem(
                            icon: Icons.local_mall,
                            label: 'To Receive',
                            count: snapshot.data ?? 0,
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const MyOrdersScreen(initialTabIndex: 2)),
                              );
                            },
                          ),
                        ),
                        StreamBuilder<int>(
                          stream: _orderCountStream('to_rate'),
                          builder: (context, snapshot) => _OrderStatusItem(
                            icon: Icons.star_border,
                            label: 'To Rate',
                            count: snapshot.data ?? 0,
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const MyOrdersScreen(initialTabIndex: 3)),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  // List Section
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      children: [
                        _ProfileListItem(
                          icon: Icons.access_time, 
                          label: 'Recent View',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const RecentViewScreen()),
                            );
                          },
                        ),
                        _ProfileListItem(
                          icon: Icons.chat_bubble_outline,
                          label: 'My Inbox',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const InboxScreen(role: 'buyer')),
                            );
                          },
                        ),
                        _ProfileListItem(
                          icon: Icons.card_giftcard, 
                          label: 'My Voucher',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const VoucherScreen()),
                            );
                          },
                        ),
                        // Sign Out List Item
                        GestureDetector(
                          onTap: () async {
                            await FirebaseAuth.instance.signOut();
                            if (mounted) {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                                (route) => false,
                              );
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            child: Row(
                              children: [
                                const Icon(Icons.logout, color: Colors.black54),
                                const SizedBox(width: 16),
                                Text('Sign Out', style: GoogleFonts.dmSans(fontSize: 16)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _onTabTapped,
      ),
    );
  }
}

class _OrderStatusItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final VoidCallback? onTap;

  const _OrderStatusItem({required this.icon, required this.label, this.count = 0, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, size: 32, color: Colors.black87),
              if (count > 0)
                Positioned(
                  right: -5,
                  top: -5,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5)
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Center(
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(label, style: GoogleFonts.dmSans(fontSize: 13)),
        ],
      ),
    );
  }
}

class _ProfileListItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ProfileListItem({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: Row(
          children: [
            Icon(icon, color: Colors.black54),
            const SizedBox(width: 16),
            Text(label, style: GoogleFonts.dmSans(fontSize: 16)),
          ],
        ),
      ),
    );
  }
} 