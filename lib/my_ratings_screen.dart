import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class MyRatingsScreen extends StatefulWidget {
  const MyRatingsScreen({super.key});

  @override
  State<MyRatingsScreen> createState() => _MyRatingsScreenState();
}

class _MyRatingsScreenState extends State<MyRatingsScreen> with SingleTickerProviderStateMixin {
  String? _sellerId;
  double? _shopAvgRating;
  List<Map<String, dynamic>> _shopReviews = [];
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;
  Map<String, String> _usernames = {}; // userId -> username
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchRatings();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _fetchRatings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _sellerId = user.uid;
    // Fetch shop ratings
    final shopRatingsSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(_sellerId)
        .collection('shop_ratings')
        .get();
    double total = 0.0;
    int count = 0;
    final shopReviews = <Map<String, dynamic>>[];
    final userIdsToFetch = <String>{};
    for (var doc in shopRatingsSnap.docs) {
      final data = doc.data();
      final rating = (data['rating'] ?? 0).toDouble();
      if (rating > 0) {
        total += rating;
        count++;
      }
      final userId = doc.id;
      userIdsToFetch.add(userId);
      shopReviews.add({
        'rating': rating,
        'review': data['review'] ?? '',
        'userId': userId,
        'timestamp': data['timestamp'],
      });
    }
    final shopAvgRating = count > 0 ? total / count : null;

    // Fetch products by this seller
    final productsSnap = await FirebaseFirestore.instance
        .collection('products')
        .where('sellerId', isEqualTo: _sellerId)
        .get();
    final products = <Map<String, dynamic>>[];
    for (var prodDoc in productsSnap.docs) {
      final prodData = prodDoc.data();
      final prodId = prodDoc.id;
      // Fetch ratings for this product
      final prodRatingsSnap = await FirebaseFirestore.instance
          .collection('products')
          .doc(prodId)
          .collection('ratings')
          .get();
      double prodTotal = 0.0;
      int prodCount = 0;
      final prodReviews = <Map<String, dynamic>>[];
      for (var rDoc in prodRatingsSnap.docs) {
        final rData = rDoc.data();
        final r = (rData['rating'] ?? 0).toDouble();
        if (r > 0) {
          prodTotal += r;
          prodCount++;
        }
        final userId = rDoc.id;
        userIdsToFetch.add(userId);
        prodReviews.add({
          'rating': r,
          'review': rData['review'] ?? '',
          'userId': userId,
          'timestamp': rData['timestamp'],
        });
      }
      final prodAvgRating = prodCount > 0 ? prodTotal / prodCount : null;
      products.add({
        'id': prodId,
        'name': prodData['name'] ?? '',
        'image': (prodData['imageUrls'] is List && prodData['imageUrls'].isNotEmpty) ? prodData['imageUrls'][0] : '',
        'avgRating': prodAvgRating,
        'reviews': prodReviews,
      });
    }
    // Fetch usernames for all unique userIds
    final usernames = <String, String>{};
    if (userIdsToFetch.isNotEmpty) {
      final batches = userIdsToFetch.toList();
      for (final userId in batches) {
        try {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
          if (userDoc.exists) {
            usernames[userId] = userDoc.data()?['username'] ?? userDoc.data()?['name'] ?? 'User';
          } else {
            usernames[userId] = 'User';
          }
        } catch (e) {
          usernames[userId] = 'User';
        }
      }
    }
    setState(() {
      _shopAvgRating = shopAvgRating;
      _shopReviews = shopReviews;
      _products = products;
      _isLoading = false;
      _usernames = usernames;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Ratings', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        bottom: TabBar(
          controller: _tabController!,
          labelColor: Colors.blueAccent,
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: Colors.blueAccent,
          tabs: const [
            Tab(text: 'Shop Ratings'),
            Tab(text: 'Product Ratings'),
          ],
        ),
      ),
      backgroundColor: const Color(0xFFF9F9F9),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController!,
              children: [
                _buildShopRatingsTab(),
                _buildProductRatingsTab(),
              ],
            ),
    );
  }

  Widget _buildShopRatingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Shop Rating', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.star, color: Colors.amber, size: 28),
              const SizedBox(width: 6),
              Text(_shopAvgRating != null ? _shopAvgRating!.toStringAsFixed(1) : '-', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 22)),
              const SizedBox(width: 8),
              Text('/ 5.0', style: GoogleFonts.dmSans(fontSize: 16, color: Colors.grey[700])),
            ],
          ),
          const SizedBox(height: 8),
          if (_shopReviews.isEmpty)
            Text('No shop reviews yet.', style: GoogleFonts.dmSans(color: Colors.grey[600]))
          else
            ..._shopReviews.map((r) => _buildReviewTile(r)),
        ],
      ),
    );
  }

  Widget _buildProductRatingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Product Ratings', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          if (_products.isEmpty)
            Text('No products with ratings yet.', style: GoogleFonts.dmSans(color: Colors.grey[600]))
          else
            ..._products.map((p) => _buildProductRatings(p)),
        ],
      ),
    );
  }

  Widget _buildReviewTile(Map<String, dynamic> r) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(Icons.person, color: Colors.blue[300]),
        title: Row(
          children: [
            Text(_usernames[r['userId']] ?? 'User', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Icon(Icons.star, color: Colors.amber, size: 18),
            const SizedBox(width: 4),
            Text(r['rating'].toString(), style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
          ],
        ),
        subtitle: Text(r['review'] ?? '', style: GoogleFonts.dmSans()),
      ),
    );
  }

  Widget _buildProductRatings(Map<String, dynamic> p) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ExpansionTile(
        leading: p['image'] != null && p['image'].toString().isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(p['image'], width: 44, height: 44, fit: BoxFit.cover, errorBuilder: (c, o, s) => const Icon(Icons.image)),
              )
            : const Icon(Icons.inventory_2, size: 36, color: Colors.blueGrey),
        title: Text(p['name'] ?? '', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
        subtitle: Row(
          children: [
            Icon(Icons.star, color: Colors.amber, size: 18),
            const SizedBox(width: 4),
            Text(p['avgRating'] != null ? p['avgRating'].toStringAsFixed(1) : '-', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
            const SizedBox(width: 6),
            Text('/ 5.0', style: GoogleFonts.dmSans(fontSize: 13, color: Colors.grey[700])),
          ],
        ),
        children: [
          if (p['reviews'].isEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text('No reviews yet.', style: GoogleFonts.dmSans(color: Colors.grey[600])),
            )
          else
            ...p['reviews'].map<Widget>((r) => _buildReviewTile(r)).toList(),
        ],
      ),
    );
  }
} 