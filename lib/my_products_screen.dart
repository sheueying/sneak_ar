import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_product_screen.dart';
import 'edit_product_screen.dart';

class MyProductsScreen extends StatefulWidget {
  const MyProductsScreen({super.key});

  @override
  State<MyProductsScreen> createState() => _MyProductsScreenState();
}

class _MyProductsScreenState extends State<MyProductsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? sellerId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    sellerId = FirebaseAuth.instance.currentUser?.uid;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('My Products', style: TextStyle(color: Colors.black)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.blue[400],
          labelColor: Colors.blue[400],
          unselectedLabelColor: Colors.grey,
          labelStyle: GoogleFonts.dmSans(fontWeight: FontWeight.bold),
          tabs: [
            Tab(text: 'All Product'),
            Tab(text: 'Sold Out'),
          ],
        ),
      ),
      backgroundColor: const Color(0xFFF9F9F9),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProductList(soldOut: false),
          _buildProductList(soldOut: true),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 55),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddProductScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[400],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(
              'Add New Product',
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductList({required bool soldOut}) {
    return StreamBuilder<QuerySnapshot>(
      stream: soldOut
          ? FirebaseFirestore.instance
              .collection('products')
              .where('sellerId', isEqualTo: sellerId)
              .snapshots()
          : FirebaseFirestore.instance
              .collection('products')
              .where('sellerId', isEqualTo: sellerId)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No products found.', style: GoogleFonts.dmSans()));
        }
        final products = snapshot.data!.docs
            .where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final stockMap = data['stock'] as Map<String, dynamic>? ?? {};
              final stockValues = stockMap.values.map((v) {
                if (v is int) return v;
                if (v is double) return v.toInt();
                return int.tryParse(v.toString()) ?? 0;
              }).toList();
              final allZero = stockValues.isEmpty || stockValues.every((v) => v == 0);
              return soldOut ? allZero : !allZero;
            })
            .toList();
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: products.length,
          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFD0E2FF)),
          itemBuilder: (context, index) {
            final data = products[index].data() as Map<String, dynamic>;
            return Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image(
                    image: (data['imageUrls'] != null && data['imageUrls'] is List && data['imageUrls'].isNotEmpty && data['imageUrls'][0] != null && data['imageUrls'][0].toString().isNotEmpty)
                        ? NetworkImage(data['imageUrls'][0])
                        : AssetImage('assets/default_image.png') as ImageProvider,
                    width: 70,
                    height: 70,
                    fit: BoxFit.cover,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data['name'] ?? '', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
                        Text('RM ${data['price'] != null ? double.tryParse(data['price'].toString())?.toStringAsFixed(2) ?? data['price'] : ''}',style: GoogleFonts.dmSans(),),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Stock:', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
                                  ...(data['stock'] as Map<String, dynamic>? ?? {})
                                      .entries
                                      .map<Widget>((entry) => Text(
                                            '${entry.key} : ${entry.value}',
                                            style: GoogleFonts.dmSans(fontSize: 13),
                                          ))
                                      ,
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('Sold: ${data['sold'] ?? 0}', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Text('Likes: ${data['likes'] ?? 0}', style: GoogleFonts.dmSans(fontSize: 13)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () async {
                      final docId = products[index].id;
                      final data = products[index].data() as Map<String, dynamic>;
                      final updated = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditProductScreen(productId: docId, productData: data),
                        ),
                      );
                      if (updated == true) {
                        setState(() {}); // Refresh after edit
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      side: BorderSide(color: Colors.grey[300]!),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 0),
                    ),
                    child: Text('Edit', style: GoogleFonts.dmSans()),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
} 