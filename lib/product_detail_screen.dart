import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import 'package:shoefit_application/ar_cam_screen.dart';
import 'package:shoefit_application/favourite_screen.dart';
import 'package:shoefit_application/home_screen.dart';
import 'cart_screen.dart';
import 'widgets/bottom_nav_bar.dart';
import 'user_profile_screen.dart';
import 'seller_shop_screen.dart';
import 'dart:core';

class ProductDetailScreen extends StatefulWidget {
  final String productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> with TickerProviderStateMixin {
  int _selectedSizeIndex = -1;
  Map<String, dynamic>? _productData;
  bool _isLoading = true;
  bool _showAddedToCart = false;
  bool _isAddingToCart = false;
  int _selectedIndex = 0;
  bool _isFavourite = false;
  bool _isLoadingFavourite = false;
  // Seller info
  String? _sellerName;
  String? _sellerProfileImageUrl;
  String? _sellerId;

  // Product reviews
  List<Map<String, dynamic>> _reviews = [];
  Map<String, String> _usernames = {}; // userId -> username
  bool _isLoadingReviews = true;

  @override
  void initState() {
    super.initState();
    _fetchProduct();
    _checkIfFavourite();
    _addToRecentViews();
    _fetchReviews();
  }

  Future<void> _addToRecentViews() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('recent_views')
        .doc(widget.productId)
        .set({
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _fetchProduct() async {
    final doc = await FirebaseFirestore.instance.collection('products').doc(widget.productId).get();
    if (!mounted) return;
    if (doc.exists) {
      setState(() {
        _productData = doc.data() as Map<String, dynamic>;
        _isLoading = false;
        _sellerId = _productData?['sellerId'];
      });
      if (_sellerId != null && _sellerId!.isNotEmpty) {
        _fetchSellerInfo(_sellerId!);
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchSellerInfo(String sellerId) async {
    setState(() { });
    final doc = await FirebaseFirestore.instance.collection('sellers').doc(sellerId).get();
    if (!mounted) return;
    if (doc.exists) {
      setState(() {
        _sellerName = doc.data()?['storeName'] ?? 'Shop';
        _sellerProfileImageUrl = doc.data()?['profileImageUrl'];
      });
    } else {
      setState(() { });
    }
  }

  Future<void> _checkIfFavourite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _isLoadingFavourite = true);
    final favRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('favourites')
        .doc(widget.productId);
    final favDoc = await favRef.get();
    setState(() {
      _isFavourite = favDoc.exists;
      _isLoadingFavourite = false;
    });
  }

  Future<void> _addToCart() async {
    if (_isAddingToCart) return;
    if (!mounted) return;
    setState(() => _isAddingToCart = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final data = _productData;
    if (data == null) return;
    final List imageUrls = (data['imageUrls'] as List?) ?? [];
    final Map<String, dynamic> stockMap = data['stock'] as Map<String, dynamic>? ?? {};
    // Improved size sorting: standard sizes, then numeric, then alpha
    final List<String> sizeOrder = [
      "XS", "S", "M", "L", "XL", "XXL", "XXXL"
    ];
    final List<String> sizes = stockMap.keys.toList()
      ..sort((a, b) {
        // Improved UK size pattern: handles 'UK4', 'UK 4', 'UK-4', 'UK4.5', 'UK 4.5', etc.
        final ukReg = RegExp(r'^UK\s*-?\s*(\d+(?:\.\d+)?)$', caseSensitive: false);
        final matchA = ukReg.firstMatch(a.trim());
        final matchB = ukReg.firstMatch(b.trim());
        if (matchA != null && matchB != null) {
          final numA = double.parse(matchA.group(1)!);
          final numB = double.parse(matchB.group(1)!);
          return numA.compareTo(numB);
        }
        // Fallback to previous logic (standard sizes, numeric, alpha)
        final numA = num.tryParse(a);
        final numB = num.tryParse(b);
        if (numA != null && numB != null) {
          return numA.compareTo(numB);
        }
        final idxA = sizeOrder.indexOf(a.toUpperCase());
        final idxB = sizeOrder.indexOf(b.toUpperCase());
        if (idxA != -1 && idxB != -1) {
          return idxA.compareTo(idxB);
        }
        if (idxA != -1) return -1;
        if (idxB != -1) return 1;
        return a.compareTo(b);
      });
    if (_selectedSizeIndex < 0 || _selectedSizeIndex >= sizes.length) {
      setState(() => _isAddingToCart = false);
      return;
    }
    final size = sizes[_selectedSizeIndex];
    final cartItemRef = FirebaseFirestore.instance
        .collection('carts')
        .doc(user.uid)
        .collection('items')
        .doc('${widget.productId}_$size');
    final cartItem = await cartItemRef.get();
    if (!mounted) return;
    if (cartItem.exists) {
      await cartItemRef.update({
        'quantity': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await cartItemRef.set({
        'productId': widget.productId,
        'name': data['name'],
        'price': data['price'],
        'quantity': 1,
        'image': imageUrls.isNotEmpty ? imageUrls[0] : '',
        'sellerId': data['sellerId'],
        'size': size,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    if (!mounted) return;
    setState(() {
      _showAddedToCart = true;
      _isAddingToCart = false;
    });
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => _showAddedToCart = false);
    }
  }

  Future<void> _toggleFavourite(String name, double price, List imageUrls) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final favRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('favourites')
        .doc(widget.productId);
    setState(() => _isLoadingFavourite = true);
    if (_isFavourite) {
      await favRef.delete();
      if (mounted) {
        setState(() {
          _isFavourite = false;
          _isLoadingFavourite = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Removed from favourites', style: GoogleFonts.dmSans())),
        );
      }
    } else {
      await favRef.set({
        'productId': widget.productId,
        'name': name,
        'price': price,
        'image': imageUrls.isNotEmpty ? imageUrls[0] : '',
      });
      if (mounted) {
        setState(() {
          _isFavourite = true;
          _isLoadingFavourite = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added to favourites', style: GoogleFonts.dmSans())),
        );
      }
    }
  }

  Future<void> _fetchReviews() async {
    setState(() { _isLoadingReviews = true; });
    final ratingsSnap = await FirebaseFirestore.instance
        .collection('products')
        .doc(widget.productId)
        .collection('ratings')
        .orderBy('timestamp', descending: true)
        .get();
    final reviews = <Map<String, dynamic>>[];
    final userIds = <String>{};
    for (var doc in ratingsSnap.docs) {
      final data = doc.data();
      final userId = doc.id;
      userIds.add(userId);
      reviews.add({
        'userId': userId,
        'rating': (data['rating'] ?? 0).toDouble(),
        'review': data['review'] ?? '',
        'timestamp': data['timestamp'],
      });
    }
    // Fetch usernames
    final usernames = <String, String>{};
    for (final userId in userIds) {
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
    if (mounted) {
      setState(() {
        _reviews = reviews;
        _usernames = usernames;
        _isLoadingReviews = false;
      });
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('', style: TextStyle(color: Colors.black)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _productData == null
                  ? const Center(child: Text('Product not found'))
                  : _buildProductDetail(_productData!),
          if (_showAddedToCart)
            Container(
              color: Colors.black.withAlpha((0.6 * 255).toInt()),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Item Added To Cart !', style: GoogleFonts.dmSans(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    const Icon(Icons.check_circle, color: Colors.white, size: 64),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _onTabTapped,
      ),
    );
  }

  Widget _buildProductDetail(Map<String, dynamic> data) {
    final List imageUrls = (data['imageUrls'] as List?) ?? [];
    final String name = data['name'] ?? '';
    final String description = data['description'] ?? '';
    final double price = double.tryParse(data['price'].toString()) ?? 0.0;
    final Map<String, dynamic> stockMap = data['stock'] as Map<String, dynamic>? ?? {};
    // Improved size sorting: standard sizes, then numeric, then alpha
    final List<String> sizeOrder = [
      "XS", "S", "M", "L", "XL", "XXL", "XXXL"
    ];
    final List<String> sizes = stockMap.keys.toList()
      ..sort((a, b) {
        // Improved UK size pattern: handles 'UK4', 'UK 4', 'UK-4', 'UK4.5', 'UK 4.5', etc.
        final ukReg = RegExp(r'^UK\s*-?\s*(\d+(?:\.\d+)?)$', caseSensitive: false);
        final matchA = ukReg.firstMatch(a.trim());
        final matchB = ukReg.firstMatch(b.trim());
        if (matchA != null && matchB != null) {
          final numA = double.parse(matchA.group(1)!);
          final numB = double.parse(matchB.group(1)!);
          return numA.compareTo(numB);
        }
        // Fallback to previous logic (standard sizes, numeric, alpha)
        final numA = num.tryParse(a);
        final numB = num.tryParse(b);
        if (numA != null && numB != null) {
          return numA.compareTo(numB);
        }
        final idxA = sizeOrder.indexOf(a.toUpperCase());
        final idxB = sizeOrder.indexOf(b.toUpperCase());
        if (idxA != -1 && idxB != -1) {
          return idxA.compareTo(idxB);
        }
        if (idxA != -1) return -1;
        if (idxB != -1) return 1;
        return a.compareTo(b);
      });
    if (_selectedSizeIndex >= 0 && _selectedSizeIndex < sizes.length) {
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image carousel
          SizedBox(
            height: 220,
            child: PageView.builder(
              itemCount: imageUrls.length,
              itemBuilder: (context, index) => Image.network(
                imageUrls[index],
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.bold)),
                Text('RM ${price.toStringAsFixed(2)}', style: GoogleFonts.dmSans(fontSize: 18, color: Colors.grey[700])),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text('Select Size', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
                    ),
                    TextButton(
                      onPressed: () => _showSizeGuide(),
                      child: Text('Size Guide', style: GoogleFonts.dmSans()),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  children: List.generate(sizes.length, (i) {
                    final size = sizes[i];
                    final stock = stockMap[size] ?? 0;
                    final isSelected = _selectedSizeIndex == i;
                    return ChoiceChip(
                      label: Text(size),
                      selected: isSelected,
                      onSelected: stock > 0
                          ? (selected) {
                              setState(() {
                                _selectedSizeIndex = selected ? i : -1;
                              });
                            }
                          : null,
                      selectedColor: Colors.blue[400],
                      backgroundColor: Colors.grey[200],
                      labelStyle: GoogleFonts.dmSans(
                        color: isSelected ? Colors.white : Colors.black,
                      ),
                      disabledColor: Colors.grey[300],
                    );
                  }),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _selectedSizeIndex != -1 && !_isAddingToCart ? _addToCart : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[400],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text('Add to Cart', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _isLoadingFavourite
                        ? null
                        : () => _toggleFavourite(name, price, imageUrls),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      side: BorderSide(color: Colors.blue[400]!),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _isFavourite ? 'Favourited' : 'Favourite',
                          style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue[400]),
                        ),
                        const SizedBox(width: 8),
                        Icon(_isFavourite ? Icons.favorite : Icons.favorite_border, color: Colors.blue),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Product Description section
                ExpansionTile(
                  title: Text('Product Description', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
                  tilePadding: EdgeInsets.zero,
                  initiallyExpanded: false,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 8.0),
                      child: Text(description, style: GoogleFonts.dmSans()),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Product Reviews section
                _buildReviewSection(),
                const SizedBox(height: 32),
                // Seller Profile Section
                if (_sellerName != null)
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SellerShopScreen(
                            sellerId: _sellerId!,
                            shopName: _sellerName,
                            profileImageUrl: _sellerProfileImageUrl,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(top: 8, bottom: 24),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F0FF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundImage: (_sellerProfileImageUrl != null && _sellerProfileImageUrl!.isNotEmpty)
                                ? NetworkImage(_sellerProfileImageUrl!)
                                : const AssetImage('assets/default_profile.png') as ImageProvider,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_sellerName!, style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 2),
                                Text('View Shop', style: GoogleFonts.dmSans(color: Colors.blueAccent, fontSize: 13)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.blueAccent),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewSection() {
    return ExpansionTile(
      title: Text('Product Reviews', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
      tilePadding: EdgeInsets.zero,
      initiallyExpanded: false,
      children: [
        if (_isLoadingReviews)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_reviews.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('No reviews yet.', style: GoogleFonts.dmSans(color: Colors.grey[600])),
          )
        else
          ..._reviews.map((r) => _buildReviewTile(r)),
      ],
    );
  }

  Widget _buildReviewTile(Map<String, dynamic> r) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: Colors.blue[50],
              child: Icon(Icons.person, color: Colors.blue[400]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _usernames[r['userId']] ?? 'User', 
                          style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, color: Colors.blue[900]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.star, color: Colors.amber, size: 18),
                      const SizedBox(width: 4),
                      Text(r['rating'].toString(), style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, color: Colors.blue[900])),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(r['review'] ?? '', style: GoogleFonts.dmSans(color: Colors.black87)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSizeGuide() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blue[400],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.straighten, color: Colors.white, size: 24),
                      const SizedBox(width: 12),
                      Text(
                        'Size Guide',
                        style: GoogleFonts.dmSans(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Instructions
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'How to measure your foot:',
                                style: GoogleFonts.dmSans(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '1. Place your foot on a piece of paper\n'
                                '2. Mark the longest point from heel to toe\n'
                                '3. Measure the length in centimeters\n'
                                '4. Use the chart below to find your size',
                                style: GoogleFonts.dmSans(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Men's Size Chart
                        _buildSizeChart('Men\'s Shoes', _getMensSizeChart()),
                        const SizedBox(height: 20),
                        // Women's Size Chart
                        _buildSizeChart('Women\'s Shoes', _getWomensSizeChart()),
                        const SizedBox(height: 20),
                        // Tips
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.amber[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tips for the perfect fit:',
                                style: GoogleFonts.dmSans(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.amber[800],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '• Measure both feet and use the larger size\n'
                                '• Measure in the afternoon when feet are largest\n'
                                '• Consider the type of socks you\'ll wear\n'
                                '• Different brands may fit differently',
                                style: GoogleFonts.dmSans(
                                  fontSize: 14,
                                  color: Colors.amber[800],
                                ),
                              ),
                            ],
                          ),
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
    );
  }

  Widget _buildSizeChart(String title, List<Map<String, String>> chartData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[400]!, width: 1.5),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 0,
              dataRowHeight: 45,
              headingRowHeight: 55,
              border: TableBorder(
                top: BorderSide(color: Colors.grey[400]!, width: 1.5),
                bottom: BorderSide(color: Colors.grey[400]!, width: 1.5),
                left: BorderSide(color: Colors.grey[400]!, width: 1.5),
                right: BorderSide(color: Colors.grey[400]!, width: 1.5),
                horizontalInside: BorderSide(color: Colors.grey[300]!, width: 0.5),
                verticalInside: BorderSide(color: Colors.grey[300]!, width: 0.5),
              ),
              headingTextStyle: GoogleFonts.dmSans(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.white,
              ),
              dataTextStyle: GoogleFonts.dmSans(
                fontSize: 13,
                color: Colors.black87,
              ),
              headingRowColor: WidgetStateProperty.all(Colors.blue[600]),
              dataRowColor: WidgetStateProperty.resolveWith<Color?>(
                (Set<WidgetState> states) {
                  // Alternate row colors
                  final index = states.contains(WidgetState.selected) ? 1 : 0;
                  return index % 2 == 0 ? Colors.white : Colors.grey[50];
                },
              ),
              columns: [
                DataColumn(
                  label: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text('UK'),
                  ),
                ),
                DataColumn(
                  label: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text('US'),
                  ),
                ),
                DataColumn(
                  label: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text('EU'),
                  ),
                ),
                DataColumn(
                  label: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text('CM'),
                  ),
                ),
              ],
              rows: chartData.asMap().entries.map((entry) {
                final index = entry.key;
                final row = entry.value;
                return DataRow(
                  color: WidgetStateProperty.all(
                    index % 2 == 0 ? Colors.white : Colors.grey[50],
                  ),
                  cells: [
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text(
                          row['UK'] ?? '',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text(
                          row['US'] ?? '',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text(
                          row['EU'] ?? '',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text(
                          row['CM'] ?? '',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  List<Map<String, String>> _getMensSizeChart() {
    return [
      {'UK': '3', 'US': '3.5', 'EU': '36', 'CM': '22.5'},
      {'UK': '3.5', 'US': '4', 'EU': '36.5', 'CM': '23'},
      {'UK': '4', 'US': '4.5', 'EU': '37', 'CM': '23.5'},
      {'UK': '4.5', 'US': '5', 'EU': '37.5', 'CM': '24'},
      {'UK': '5', 'US': '5.5', 'EU': '38', 'CM': '24.5'},
      {'UK': '5.5', 'US': '6', 'EU': '38.5', 'CM': '25'},
      {'UK': '6', 'US': '6.5', 'EU': '39', 'CM': '25.5'},
      {'UK': '6.5', 'US': '7', 'EU': '39.5', 'CM': '26'},
      {'UK': '7', 'US': '7.5', 'EU': '40', 'CM': '26.5'},
      {'UK': '7.5', 'US': '8', 'EU': '40.5', 'CM': '27'},
      {'UK': '8', 'US': '8.5', 'EU': '41', 'CM': '27.5'},
      {'UK': '8.5', 'US': '9', 'EU': '41.5', 'CM': '28'},
      {'UK': '9', 'US': '9.5', 'EU': '42', 'CM': '28.5'},
      {'UK': '9.5', 'US': '10', 'EU': '42.5', 'CM': '29'},
      {'UK': '10', 'US': '10.5', 'EU': '43', 'CM': '29.5'},
      {'UK': '10.5', 'US': '11', 'EU': '43.5', 'CM': '30'},
      {'UK': '11', 'US': '11.5', 'EU': '44', 'CM': '30.5'},
      {'UK': '11.5', 'US': '12', 'EU': '44.5', 'CM': '31'},
      {'UK': '12', 'US': '12.5', 'EU': '45', 'CM': '31.5'},
      {'UK': '12.5', 'US': '13', 'EU': '45.5', 'CM': '32'},
      {'UK': '13', 'US': '13.5', 'EU': '46', 'CM': '32.5'},
    ];
  }

  List<Map<String, String>> _getWomensSizeChart() {
    return [
      {'UK': '2', 'US': '4', 'EU': '35', 'CM': '21.5'},
      {'UK': '2.5', 'US': '4.5', 'EU': '35.5', 'CM': '22'},
      {'UK': '3', 'US': '5', 'EU': '36', 'CM': '22.5'},
      {'UK': '3.5', 'US': '5.5', 'EU': '36.5', 'CM': '23'},
      {'UK': '4', 'US': '6', 'EU': '37', 'CM': '23.5'},
      {'UK': '4.5', 'US': '6.5', 'EU': '37.5', 'CM': '24'},
      {'UK': '5', 'US': '7', 'EU': '38', 'CM': '24.5'},
      {'UK': '5.5', 'US': '7.5', 'EU': '38.5', 'CM': '25'},
      {'UK': '6', 'US': '8', 'EU': '39', 'CM': '25.5'},
      {'UK': '6.5', 'US': '8.5', 'EU': '39.5', 'CM': '26'},
      {'UK': '7', 'US': '9', 'EU': '40', 'CM': '26.5'},
      {'UK': '7.5', 'US': '9.5', 'EU': '40.5', 'CM': '27'},
      {'UK': '8', 'US': '10', 'EU': '41', 'CM': '27.5'},
      {'UK': '8.5', 'US': '10.5', 'EU': '41.5', 'CM': '28'},
      {'UK': '9', 'US': '11', 'EU': '42', 'CM': '28.5'},
      {'UK': '9.5', 'US': '11.5', 'EU': '42.5', 'CM': '29'},
      {'UK': '10', 'US': '12', 'EU': '43', 'CM': '29.5'},
    ];
  }
} 