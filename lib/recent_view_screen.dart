import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shoefit_application/models/product.dart';
import '../widgets/home_product_card.dart';

class RecentViewScreen extends StatefulWidget {
  const RecentViewScreen({super.key});

  @override
  State<RecentViewScreen> createState() => _RecentViewScreenState();
}

class _RecentViewScreenState extends State<RecentViewScreen> {
  List<Product> _recentProducts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRecentProducts();
  }

  Future<void> _fetchRecentProducts() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final recentViewsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('recent_views')
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();

      final productIds = recentViewsSnapshot.docs.map((doc) => doc.id).toList();

      if (productIds.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _recentProducts = [];
          });
        }
        return;
      }

      final productsSnapshot = await FirebaseFirestore.instance
          .collection('products')
          .where(FieldPath.documentId, whereIn: productIds)
          .get();

      final productsMap = {for (var doc in productsSnapshot.docs) doc.id: Product.fromFirestore(doc.id, doc.data())};
      final sortedProducts = productIds
          .map((id) => productsMap[id])
          .whereType<Product>()
          .toList();

      if (mounted) {
        setState(() {
          _recentProducts = sortedProducts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Recent View',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        shadowColor: Colors.grey.withOpacity(0.2),
      ),
      backgroundColor: const Color(0xFFF9F9F9),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _recentProducts.isEmpty
              ? Center(
                  child: Text(
                    'You have no recently viewed items.',
                    style: GoogleFonts.dmSans(fontSize: 16, color: Colors.grey),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16.0),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: _recentProducts.length,
                  itemBuilder: (context, index) {
                    final product = _recentProducts[index];
                    return HomeProductCard(product: product);
                  },
                ),
    );
  }
} 