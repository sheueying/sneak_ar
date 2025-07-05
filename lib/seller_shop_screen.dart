import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models/product.dart';
import 'widgets/home_product_card.dart';
import 'chat_screen.dart';
import 'seller_shop_info_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SellerShopScreen extends StatefulWidget {
  final String sellerId;
  final String? shopName;
  final String? profileImageUrl;

  const SellerShopScreen({super.key, required this.sellerId, this.shopName, this.profileImageUrl});

  @override
  State<SellerShopScreen> createState() => _SellerShopScreenState();
}

class _SellerShopScreenState extends State<SellerShopScreen> {
  String? _shopName;
  String? _profileImageUrl;
  List<Product> _products = [];
  bool _isLoadingProducts = true;

  @override
  void initState() {
    super.initState();
    _fetchSellerInfo();
    _fetchSellerProducts();
  }

  Future<void> _fetchSellerInfo() async {
    setState(() { });
    final doc = await FirebaseFirestore.instance.collection('sellers').doc(widget.sellerId).get();
    if (doc.exists) {
      setState(() {
        _shopName = doc.data()?['storeName'] ?? 'Shop';
        _profileImageUrl = doc.data()?['profileImageUrl'];
      });
    } else {
      setState(() { });
    }
  }

  Future<void> _fetchSellerProducts() async {
    setState(() { _isLoadingProducts = true; });
    final snapshot = await FirebaseFirestore.instance
        .collection('products')
        .where('sellerId', isEqualTo: widget.sellerId)
        .get();
    setState(() {
      _products = snapshot.docs.map((doc) => Product.fromFirestore(doc.id, doc.data())).toList();
      _isLoadingProducts = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final shopName = _shopName ?? widget.shopName ?? 'Shop';
    final profileImageUrl = _profileImageUrl ?? widget.profileImageUrl;
    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwner = currentUser != null && currentUser.uid == widget.sellerId;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('', style: TextStyle(color: Colors.black)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header with gradient and card effect
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFB6D0FF), Color(0xFFE3F0FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.07),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 36,
                      backgroundImage: (profileImageUrl != null && profileImageUrl.isNotEmpty)
                          ? NetworkImage(profileImageUrl)
                          : const AssetImage('assets/default_profile.png') as ImageProvider,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shopName,
                          style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.black87),
                        ),
                        const SizedBox(height: 6),
                        Text('Trusted Seller', style: GoogleFonts.dmSans(fontSize: 13, color: Colors.blueGrey)),
                      ],
                    ),
                  ),
                  if (isOwner)
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SellerShopInfoScreen()),
                        );
                      },
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit Shop'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[400],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w500),
                        elevation: 0,
                      ),
                    ),
                  if (!isOwner)
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              sellerId: widget.sellerId,
                              sellerName: shopName,
                              sellerProfileImageUrl: profileImageUrl,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                      label: const Text('Chat'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[400],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w500),
                        elevation: 0,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Text('Products', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 17)),
                  const SizedBox(width: 8),
                  Expanded(child: Divider(thickness: 1, color: Color(0xFFE3E3E3))),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blueGrey.withOpacity(0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: _isLoadingProducts
                    ? const Center(child: CircularProgressIndicator())
                    : _products.isEmpty
                        ? Center(child: Text('No products found', style: GoogleFonts.dmSans()))
                        : GridView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 0.75,
                            ),
                            itemCount: _products.length,
                            itemBuilder: (context, index) => Container(
                              decoration: BoxDecoration(
                                color: Color(0xFFF6FAFF), // very light blue
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: Color(0xFFE3EAF2), width: 1), // very light border
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blueGrey.withOpacity(0.04),
                                    blurRadius: 8,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: HomeProductCard(product: _products[index]),
                            ),
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 