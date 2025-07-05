// ignore: unused_import
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shoefit_application/user_profile_screen.dart';
import 'models/product.dart';
import '../widgets/bottom_nav_bar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'cart_screen.dart';
import 'favourite_screen.dart';
// import 'ar_cam_screen.dart';
import 'search_screen.dart';
import 'filter_screen.dart';
import '../widgets/home_product_card.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Product> shoes = [];
  List<Product> filteredShoes = [];
  List<Product> discoverProducts = [];
  List<Product> popularProducts = [];
  int _selectedIndex = 0;
  String? _selectedBrand;
  RangeValues? _selectedPriceRange;
  bool _latestOnly = false;
  String? username;

  @override
  void initState() {
    super.initState();
    fetchUsername();
    loadProducts();
  }

  Future<void> fetchUsername() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (mounted) {
        setState(() {
          username = doc.data()?['username'] ?? 'User';
        });
      }
    } else {
      if (mounted) {
        setState(() {
          username = 'User';
        });
      }
    }
  }

  Future<void> loadProducts() async {
    final QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('products').get();
    if (!mounted) return;
    setState(() {
      shoes = snapshot.docs.map((doc) => Product.fromFirestore(doc.id, doc.data() as Map<String, dynamic>)).toList();
      filteredShoes = List.from(shoes);
      _updateDisplayedProducts();
    });
  }

  void _applyFilters({bool fromFilterScreen = false}) {
    List<Product> result = List.from(shoes);
    if (_selectedBrand != null && _selectedBrand!.isNotEmpty) {
      result = result.where((p) => p.brand == _selectedBrand).toList();
    }
    if (_selectedPriceRange != null) {
      result = result.where((p) => p.price >= _selectedPriceRange!.start && p.price <= _selectedPriceRange!.end).toList();
    }
    if (_latestOnly) {
      result.sort((a, b) => b.id.compareTo(a.id)); // crude latest sort
    }
    setState(() {
      filteredShoes = result;
      _updateDisplayedProducts();
    });
  }

  void _updateDisplayedProducts() {
    discoverProducts = List.from(filteredShoes)..shuffle();
    popularProducts = List.from(filteredShoes)
      ..sort((a, b) => b.sold.compareTo(a.sold));
  }

  void _onTabTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 0) {
      // Already on Home
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
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const UserProfileScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: filteredShoes.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                Text(
                  'Hello ${username ?? 'User'}',
                  style: GoogleFonts.dmSans(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Find Your Best Shoes Here !',
                  style: GoogleFonts.dmSans(color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                _buildSearchBar(),
                const SizedBox(height: 24),
                Text('Discover', style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 220,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: discoverProducts.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 16),
                    itemBuilder: (context, index) => HomeProductCard(product: discoverProducts[index], isHorizontal: true),
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Popular Shoes', style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('See all', style: GoogleFonts.dmSans(color: Colors.blueAccent)),
                  ],
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  itemCount: popularProducts.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.75,
                  ),
                  itemBuilder: (context, index) => HomeProductCard(product: popularProducts[index]),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _onTabTapped,
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen()));
              },
              child: AbsorbPointer(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Looking for shoes',
                    border: InputBorder.none,
                  ),
                  style: GoogleFonts.dmSans(),
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () async {
              final brands = shoes.map((p) => p.brand).toSet().toList();
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FilterScreen(
                    brands: brands,
                    selectedBrand: _selectedBrand,
                    selectedPriceRange: _selectedPriceRange,
                    latestOnly: _latestOnly,
                  ),
                ),
              );
              if (result != null) {
                setState(() {
                  _latestOnly = result['latestOnly'] ?? false;
                  _selectedBrand = result['brand'];
                  _selectedPriceRange = result['priceRange'];
                });
                _applyFilters(fromFilterScreen: true);
              }
            },
            child: const Icon(Icons.tune, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
