import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shoefit_application/delivery_address_screen.dart';
import 'package:shoefit_application/personal_details_screen.dart';
import 'package:shoefit_application/home_screen.dart';
import 'services/easyparcel_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class CheckoutScreen extends StatefulWidget {
  final List<String> selectedItemIds;
  final List<Map<String, dynamic>>? directItems;
  final String? sourceOrderId;

  const CheckoutScreen({
    super.key,
    this.selectedItemIds = const [],
    this.directItems,
    this.sourceOrderId,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  int _selectedPayment = 0; // 0: Card, 1: FPX, 2: E-Wallet
  final TextEditingController _voucherController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cardNameController = TextEditingController();
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _cardExpiryController = TextEditingController();
  final TextEditingController _cardCvvController = TextEditingController();
  final TextEditingController _postcodeController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _billingAddressController = TextEditingController();
  final TextEditingController _billingPostcodeController = TextEditingController();
  final TextEditingController _billingStateController = TextEditingController();
  final TextEditingController _billingCountryController = TextEditingController();
  bool _billingMatches = false;

  bool _isLoading = true;
  List<Map<String, dynamic>> _cartItems = [];
  double _cartTotal = 0.0;
  bool _showSuccess = false;

  // Voucher state
  Map<String, dynamic>? _appliedVoucher;
  double _voucherDiscount = 0.0;
  String? _voucherError;

  double? _shippingFee;
  bool _isFetchingShipping = false;

  // Google Places API key
  final String _googleApiKey = "AIzaSyASkFODp_TCgNG8HsI_9R1NtdVz82uP_h8";
  // Suggestions for billing address
  List<Map<String, dynamic>> _billingSuggestions = [];

  @override
  void initState() {
    super.initState();
    _fetchCheckoutData();
    _billingAddressController.addListener(_onBillingAddressChanged);
  }

  void _onBillingAddressChanged() async {
    if (kDebugMode) print('Billing address changed: \\${_billingAddressController.text}');
    final input = _billingAddressController.text;
    if (input.isEmpty) {
      setState(() => _billingSuggestions = []);
      return;
    }
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${Uri.encodeComponent(input)}&types=address&components=country:MY&key=$_googleApiKey',
    );
    final response = await http.get(url);
    if (kDebugMode) {
      print('Billing Google Places Autocomplete response: \n${response.body}');
    } // Debug print
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        _billingSuggestions = (data['predictions'] as List)
            .map((p) => {
                  'description': p['description'],
                  'place_id': p['place_id'],
                })
            .toList();
      });
    } else {
      setState(() {
        _billingSuggestions = [];
      });
      if (kDebugMode) {
        print('Billing Google Places API error: status ${response.statusCode}');
      }
    }
  }

  Future<void> _selectBillingSuggestion(Map<String, dynamic> suggestion) async {
    setState(() => _billingSuggestions = []);
    _billingAddressController.removeListener(_onBillingAddressChanged);
    final placeId = suggestion['place_id'];
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=address_component,formatted_address,name&key=$_googleApiKey',
    );
    final response = await http.get(url);
    if (kDebugMode) {
      print('Billing Google Places Details response: \n${response.body}');
    } // Debug print
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final result = data['result'];
      if (result != null) {
        setState(() {
          _billingAddressController.text = result['formatted_address'] ?? '';
          for (var c in (result['address_components'] ?? [])) {
            final types = (c['types'] as List).cast<String>();
            if (types.contains('postal_code')) _billingPostcodeController.text = c['long_name'] ?? '';
            if (types.contains('administrative_area_level_1')) _billingStateController.text = c['long_name'] ?? '';
            if (types.contains('country')) _billingCountryController.text = c['long_name'] ?? '';
          }
        });
      }
      else {
        if (kDebugMode) {
          print('Billing Google Places Details API returned no result: \n${response.body}');
        }
      }
    }
    else {
      if (kDebugMode) {
        print('Billing Google Places Details API error: status ${response.statusCode}');
      }
    }
    _billingAddressController.addListener(_onBillingAddressChanged);
  }

  Future<void> _fetchCheckoutData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }
    // Fetch user details
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final userData = userDoc.data();
    if (userData != null) {
      _nameController.text = userData['username'] ?? '';
      _emailController.text = userData['email'] ?? '';
      _phoneController.text = userData['phone'] ?? '';
      _addressController.text = userData['address'] ?? '';
      // Auto-extract postcode, state, country from address on initial load
      if (_addressController.text.isNotEmpty) {
        final extracted = extractPostcode(_addressController.text);
        _postcodeController.text = extracted;
        _stateController.text = extractState(_addressController.text);
        _countryController.text = extractCountry(_addressController.text);
      }
    }
    
    // Determine the source of items and fetch accordingly
    if (widget.directItems != null && widget.directItems!.isNotEmpty) {
      _cartItems = widget.directItems!;
    } else if (widget.selectedItemIds.isNotEmpty) {
      _cartItems = [];
      for (final id in widget.selectedItemIds) {
        final doc = await FirebaseFirestore.instance
            .collection('carts')
            .doc(user.uid)
            .collection('items')
            .doc(id)
            .get();
        if (doc.exists) {
          final data = doc.data()!;
          _cartItems.add({
            ...data,
            'cartItemId': doc.id,
          });
        }
      }
    }

    _cartTotal = _cartItems.fold(
      0.0,
      (sum, item) =>
          sum +
          ((double.tryParse(item['price'].toString()) ?? 0) *
           (int.tryParse(item['quantity'].toString()) ?? 1)),
    );

    // Now, after both address and cart items are loaded, call _fetchShippingFee()
    if (_addressController.text.isNotEmpty && _postcodeController.text.isNotEmpty && _cartItems.isNotEmpty) {
      await _fetchShippingFee();
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _fetchShippingFee() async {
    setState(() { _isFetchingShipping = true; });
    String sellerPostcode = '50450'; // fallback static seller postcode
    // Get sellerId from first cart item
    if (_cartItems.isNotEmpty && _cartItems[0]['sellerId'] != null && _cartItems[0]['sellerId'].toString().isNotEmpty) {
      final sellerId = _cartItems[0]['sellerId'];
      try {
        final sellerDoc = await FirebaseFirestore.instance.collection('sellers').doc(sellerId).get();
        final sellerData = sellerDoc.data();
        if (sellerData != null && sellerData['pickupAddress'] != null) {
          final pickupAddress = sellerData['pickupAddress'] as String;
          final extracted = extractPostcode(pickupAddress);
          if (extracted.isNotEmpty) sellerPostcode = extracted;
        }
      } catch (e) {
        // fallback to static postcode
      }
    }
    final buyerPostcode = _postcodeController.text.trim();
    final weight = 1.0; // static weight
    try {
      final rates = await EasyParcelService.getRates(
        fromPostcode: sellerPostcode,
        toPostcode: buyerPostcode,
        weightKg: weight,
      );
      // Debug print the API response for troubleshooting
      if (rates.isNotEmpty) {
        final cheapest = rates.reduce((a, b) => a.price < b.price ? a : b);
        setState(() { _shippingFee = cheapest.price; });
      } else {
        setState(() { _shippingFee = null; });
      }
    } catch (e) {
      setState(() { _shippingFee = null; });
    } finally {
      setState(() { _isFetchingShipping = false; });
    }
  }

  @override
  void dispose() {
    _voucherController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cardNameController.dispose();
    _cardNumberController.dispose();
    _cardExpiryController.dispose();
    _cardCvvController.dispose();
    _postcodeController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    _billingAddressController.dispose();
    _billingPostcodeController.dispose();
    _billingStateController.dispose();
    _billingCountryController.dispose();
    super.dispose();
  }

  Future<void> _applyVoucher() async {
    setState(() {
      _voucherError = null;
      _appliedVoucher = null;
      _voucherDiscount = 0.0;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final code = _voucherController.text.trim();
    if (code.isEmpty) {
      setState(() => _voucherError = 'Please enter a voucher code.');
      return;
    }

    final voucherSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('vouchers')
        .where('code', isEqualTo: code)
        .where('used', isEqualTo: false)
        .get();

    if (voucherSnap.docs.isEmpty) {
      setState(() => _voucherError = 'Voucher not found or already used.');
      return;
    }

    final voucher = voucherSnap.docs.first.data();
    final now = DateTime.now();
    final validFrom = (voucher['validFrom'] as Timestamp?)?.toDate() ?? DateTime(2000);
    final validTo = (voucher['validTo'] as Timestamp?)?.toDate() ?? DateTime(2100);

    if (!(voucher['isActive'] == true &&
          now.isAfter(validFrom) &&
          now.isBefore(validTo) &&
          (voucher['minOrderAmount'] == null || _cartTotal >= (voucher['minOrderAmount'] as num).toDouble()))) {
      setState(() => _voucherError = 'Voucher is not valid for this order.');
      return;
    }

    double discount = 0.0;
    if (voucher['discountType'] == 'flat') {
      discount = (voucher['discountValue'] as num).toDouble();
    } else if (voucher['discountType'] == 'percent') {
      discount = _cartTotal * ((voucher['discountValue'] as num).toDouble() / 100.0);
      if (voucher['maxDiscount'] != null) {
        discount = discount > (voucher['maxDiscount'] as num).toDouble()
            ? (voucher['maxDiscount'] as num).toDouble()
            : discount;
      }
    }

    setState(() {
      _appliedVoucher = voucher;
      _voucherDiscount = discount > _cartTotal ? _cartTotal : discount;
      _voucherError = null;
    });
  }

  Future<void> _createOrder({required String status}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    final orderItems = _cartItems
        .map((item) => {
              'productId': item['productId'] ?? '',
              'name': item['name'] ?? '',
              'price': double.tryParse(item['price'].toString()) ?? 0.0,
              'quantity': int.tryParse(item['quantity'].toString()) ?? 1,
              'image': item['image'] ?? '',
              'sellerId': item['sellerId'] ?? '',
              'size': item['size'] ?? '',
            })
        .toList();

    if (orderItems.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final sellerIds = orderItems.map((item) => item['sellerId'] as String).where((id) => id.isNotEmpty).toSet().toList();

    // Prepare billing info
    Map<String, dynamic> billingInfo;
    if (_billingMatches) {
      billingInfo = {
        'name': _nameController.text,
        'address': _addressController.text,
        'phone': _phoneController.text,
        'postcode': _postcodeController.text,
        'state': _stateController.text,
        'country': _countryController.text,
      };
    } else {
      billingInfo = {
        'name': _nameController.text,
        'address': _billingAddressController.text,
        'phone': _phoneController.text,
        'postcode': _billingPostcodeController.text,
        'state': _billingStateController.text,
        'country': _billingCountryController.text,
      };
    }

    final orderData = {
      'userId': user.uid,
      'sellerIds': sellerIds,
      'status': status,
      'totalAmount': _cartTotal - _voucherDiscount + (_shippingFee ?? 0),
      'timestamp': FieldValue.serverTimestamp(),
      'shippingInfo': {
        'name': _nameController.text,
        'address': _addressController.text,
        'phone': _phoneController.text,
        'postcode': _postcodeController.text,
        'state': _stateController.text,
        'country': _countryController.text,
      },
      'billingInfo': billingInfo,
      'shippingFee': _shippingFee ?? 0,
      'items': orderItems,
      if (_appliedVoucher != null) 'voucher': _appliedVoucher,
      if (_appliedVoucher != null) 'voucherDiscount': _voucherDiscount,
    };

    // --- Inventory Management ---
    if (status == 'to_ship') {
      for (final item in orderItems) {
        final productId = item['productId'] as String;
        final quantitySold = item['quantity'] as int;
        final size = item['size'] as String;

        if (productId.isNotEmpty && size.isNotEmpty) {
          final productRef = FirebaseFirestore.instance.collection('products').doc(productId);

          // Get the current product data
          final productSnap = await productRef.get();
          final data = productSnap.data();
          Map<String, dynamic> stockMap = {};
          if (data != null && data['stock'] is Map<String, dynamic>) {
            stockMap = Map<String, dynamic>.from(data['stock']);
          }

          // Decrement the size stock
          int sizeStock = (stockMap[size]?.toInt() ?? 0) - quantitySold;
          if (sizeStock < 0) sizeStock = 0;
          stockMap[size] = sizeStock;

          // Calculate the new total quantity as the sum of all size stocks
          int newQuantity = stockMap.values.fold(0, (sum, val) => sum + (val is int ? val : int.tryParse(val.toString()) ?? 0));

          // Update the product
          await productRef.update({
            'quantity': newQuantity,
            'sold': FieldValue.increment(quantitySold),
            'stock': stockMap,
          });
        }
      }
    }
    // --- End Inventory Management ---

    // Create the new order
    await FirebaseFirestore.instance.collection('orders').add(orderData);
    
    // Conditionally delete items based on the flow's source
    if (widget.sourceOrderId != null) {
      // If we came from "Pay Now", delete the old "to_pay" order
      await FirebaseFirestore.instance.collection('orders').doc(widget.sourceOrderId).delete();
    } else {
      // If we came from the cart, delete items from the cart
      for (final item in _cartItems) {
        if (item['cartItemId'] != null) {
          await FirebaseFirestore.instance.collection('carts').doc(user.uid).collection('items').doc(item['cartItemId']).delete();
        }
      }
    }

    // Mark voucher as used if applied
    if (_appliedVoucher != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('vouchers')
          .where('code', isEqualTo: _appliedVoucher!['code'])
          .get()
          .then((snap) async {
            for (var doc in snap.docs) {
              await doc.reference.update({'used': true});
            }
          });
    }

    // This navigation/UI update part only happens for a fully successful payment.
    if (status == 'to_ship') {
      if (!mounted) return;
      setState(() {
        _showSuccess = true;
        _isLoading = false;
      });
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    }
  }

  Future<bool> _onWillPop() async {
    // --- Flow from "Pay Now" (re-attempting payment) ---
    if (widget.sourceOrderId != null) {
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Leave Page?'),
          content: const Text("You can cancel this order or leave it in 'To Pay' for later."),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop('cancel_order'),
              child: const Text('Cancel Order', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop('decide_later'),
              child: const Text('Decide Later'),
            ),
          ],
        ),
      );

      if (result == 'cancel_order') {
        await FirebaseFirestore.instance.collection('orders').doc(widget.sourceOrderId).delete();
      }

      // For both "cancel_order" and "decide_later", we pop the screen.
      // If the dialog was dismissed, result is null and we do nothing.
      if (result == 'cancel_order' || result == 'decide_later') {
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
      
      return false; // We have handled all navigation, so prevent the default pop.
    } 
    // --- Original flow from Cart ---
    else {
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Leave Checkout?'),
          content: const Text("Save this order to 'To Pay' to complete it later?"),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop('give_up'),
              child: const Text('Give Up'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop('pay_later'),
              child: const Text('Pay Later'),
            ),
          ],
        ),
      );

      if (result == 'pay_later') {
        await _createOrder(status: 'to_pay');
        if (mounted) Navigator.of(context).pop();
        return false; // Navigation handled
      }
      
      return result == 'give_up'; // Pop if "Give Up" is pressed
    }
  }

  // Add this function to validate all required fields
  bool _validateCheckout() {
    if (_billingMatches) {
      if (kDebugMode) {
        print('name: \\${_nameController.text}');
        print('email: \\${_emailController.text}');
        print('phone: \\${_phoneController.text}');
        print('address: \\${_addressController.text}');
        print('postcode: \\${_postcodeController.text}');
        print('state: \\${_stateController.text}');
        print('country: \\${_countryController.text}');
        print('shippingFee: \\$_shippingFee');
        print('cartItems: \\${_cartItems.length}');
        print('selectedPayment: \\$_selectedPayment');
        print('cardName: \\${_cardNameController.text}');
        print('cardNumber: \\${_cardNumberController.text}');
        print('cardExpiry: \\${_cardExpiryController.text}');
        print('cardCvv: \\${_cardCvvController.text}');
      }
      return _nameController.text.trim().isNotEmpty &&
          _emailController.text.trim().isNotEmpty &&
          _phoneController.text.trim().isNotEmpty &&
          _addressController.text.trim().isNotEmpty &&
          _postcodeController.text.trim().isNotEmpty &&
          _stateController.text.trim().isNotEmpty &&
          _countryController.text.trim().isNotEmpty &&
          _shippingFee != null &&
          _cartItems.isNotEmpty &&
          (_selectedPayment == 0 || _selectedPayment == 1 || _selectedPayment == 2)
          && (_selectedPayment != 0 || (
            _cardNameController.text.trim().isNotEmpty &&
            _cardNumberController.text.trim().isNotEmpty &&
            _cardExpiryController.text.trim().isNotEmpty &&
            _cardCvvController.text.trim().isNotEmpty
          ));
    } else {
      if (kDebugMode) {
        print('name: \\${_nameController.text}');
        print('email: \\${_emailController.text}');
        print('phone: \\${_phoneController.text}');
        print('billingAddress: \\${_billingAddressController.text}');
        print('billingPostcode: \\${_billingPostcodeController.text}');
        print('billingState: \\${_billingStateController.text}');
        print('billingCountry: \\${_billingCountryController.text}');
        print('shippingFee: \\$_shippingFee');
        print('cartItems: \\${_cartItems.length}');
        print('selectedPayment: \\$_selectedPayment');
        print('cardName: \\${_cardNameController.text}');
        print('cardNumber: \\${_cardNumberController.text}');
        print('cardExpiry: \\${_cardExpiryController.text}');
        print('cardCvv: \\${_cardCvvController.text}');
      }
      return _nameController.text.trim().isNotEmpty &&
          _emailController.text.trim().isNotEmpty &&
          _phoneController.text.trim().isNotEmpty &&
          _billingAddressController.text.trim().isNotEmpty &&
          _billingPostcodeController.text.trim().isNotEmpty &&
          _billingStateController.text.trim().isNotEmpty &&
          _billingCountryController.text.trim().isNotEmpty &&
          _shippingFee != null &&
          _cartItems.isNotEmpty &&
          (_selectedPayment == 0 || _selectedPayment == 1 || _selectedPayment == 2)
          && (_selectedPayment != 0 || (
            _cardNameController.text.trim().isNotEmpty &&
            _cardNumberController.text.trim().isNotEmpty &&
            _cardExpiryController.text.trim().isNotEmpty &&
            _cardCvvController.text.trim().isNotEmpty
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && !_showSuccess) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: const Color(0xFFF9F9F9),
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () async {
                  final shouldPop = await _onWillPop();
                  if (shouldPop) {
                    Navigator.of(context).pop();
                  }
                },
              ),
              title: Text('Checkout', style: GoogleFonts.dmSans(color: Colors.black, fontWeight: FontWeight.bold)),
              centerTitle: true,
              iconTheme: const IconThemeData(color: Colors.black),
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Order Summary', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  ..._cartItems.map((item) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withAlpha((0.08 * 255).toInt()),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: item['image'] != null && item['image'].toString().isNotEmpty
                              ? Image.network(item['image'], width: 70, height: 70, fit: BoxFit.cover)
                              : Container(width: 70, height: 70, color: Colors.grey[200]),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item['name'] ?? '', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
                              if (item['size'] != null) Text('Size: ${item['size']}', style: GoogleFonts.dmSans()),
                              Text(
                                'RM ${(double.tryParse(item['price'].toString())?.toStringAsFixed(2) ?? '0.00')}',
                                style: GoogleFonts.dmSans(),
                              ),
                              Text('Qty: ${item['quantity'] ?? 1}', style: GoogleFonts.dmSans()),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Shipping Fee', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
                      _isFetchingShipping
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_shippingFee != null ? 'RM ${_shippingFee!.toStringAsFixed(2)}' : '-', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Personal Details', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        onPressed: () async {
                          final updated = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PersonalDetailsScreen(
                                name: _nameController.text,
                                email: _emailController.text,
                                phone: _phoneController.text,
                              ),
                            ),
                          );
                          if (updated != null) {
                            setState(() {
                              _nameController.text = updated['name'];
                              _emailController.text = updated['email'];
                              _phoneController.text = updated['phone'];
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  TextField(
                    controller: _nameController,
                    style: GoogleFonts.dmSans(),
                    readOnly: true,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  TextField(
                    controller: _emailController,
                    style: GoogleFonts.dmSans(),
                    readOnly: true,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  TextField(
                    controller: _phoneController,
                    style: GoogleFonts.dmSans(),
                    readOnly: true,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Delivery Address', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        onPressed: () async {
                          final updated = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DeliveryAddressScreen(selectedAddress: _addressController.text),
                            ),
                          );
                          if (updated != null) {
                            setState(() {
                              _addressController.text = updated;
                              final extracted = extractPostcode(updated);
                              _postcodeController.text = extracted;
                              _stateController.text = extractState(updated);
                              _countryController.text = extractCountry(updated);
                            });
                            await _fetchShippingFee();
                          }
                        },
                      ),
                    ],
                  ),
                  TextField(
                    controller: _addressController,
                    style: GoogleFonts.dmSans(),
                    maxLines: 2,
                    readOnly: true,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  Row(
                    children: [
                      Checkbox(
                        value: _billingMatches,
                        onChanged: (val) {
                          setState(() => _billingMatches = val ?? false);
                        },
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      Text('Billing Matches Delivery Address', style: GoogleFonts.dmSans(fontSize: 13)),
                    ],
                  ),
                  if (!_billingMatches) ...[
                    const SizedBox(height: 10),
                    Text('Billing Address', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Stack(
                      children: [
                        TextField(
                          controller: _billingAddressController,
                          style: GoogleFonts.dmSans(),
                          maxLines: 2,
                          decoration: InputDecoration(
                            hintText: 'Enter billing address',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        if (_billingSuggestions.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 56),
                            constraints: BoxConstraints(maxHeight: 200),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                            ),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: _billingSuggestions.length,
                              itemBuilder: (context, index) {
                                final s = _billingSuggestions[index];
                                return ListTile(
                                  title: Text(s['description'] ?? ''),
                                  onTap: () => _selectBillingSuggestion(s),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _billingPostcodeController,
                            style: GoogleFonts.dmSans(),
                            decoration: InputDecoration(
                              hintText: 'Postcode',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _billingStateController,
                            style: GoogleFonts.dmSans(),
                            decoration: InputDecoration(
                              hintText: 'State',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _billingCountryController,
                      style: GoogleFonts.dmSans(),
                      decoration: InputDecoration(
                        hintText: 'Country',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text('Vouchers', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _voucherController,
                          style: GoogleFonts.dmSans(),
                          decoration: InputDecoration(
                            hintText: 'Enter Voucher Code',
                            hintStyle: GoogleFonts.dmSans(),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            errorText: _voucherError,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _appliedVoucher == null ? _applyVoucher : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _appliedVoucher == null ? Colors.blue[400] : Colors.grey[300],
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(_appliedVoucher == null ? 'Apply' : 'Applied', style: GoogleFonts.dmSans()),
                      ),
                    ],
                  ),
                  if (_appliedVoucher != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green, size: 18),
                          const SizedBox(width: 6),
                          Text('Voucher applied: -RM ${_voucherDiscount.toStringAsFixed(2)}', style: GoogleFonts.dmSans(color: Colors.green)),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _appliedVoucher = null;
                                _voucherDiscount = 0.0;
                                _voucherController.clear();
                              });
                            },
                            child: Text('Remove', style: GoogleFonts.dmSans(color: Colors.red)),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 18),
                  Text('Choose A Payment Method', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  _buildPaymentOption(0, Icons.credit_card, 'Credit or Debit Card'),
                  const SizedBox(height: 8),
                  _buildPaymentOption(1, null, 'FPX  Pay with Online Banking', asset: 'assets/fpx_logo.png'),
                  const SizedBox(height: 8),
                  _buildPaymentOption(2, null, 'E-Wallet', asset: 'assets/tng_logo.png'),
                  const SizedBox(height: 18),
                  if (_selectedPayment == 0) ...[
                    Text('Enter your payment details:', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _cardNameController,
                      style: GoogleFonts.dmSans(),
                      decoration: InputDecoration(
                        hintText: 'Name on card',
                        hintStyle: GoogleFonts.dmSans(),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _cardNumberController,
                      style: GoogleFonts.dmSans(),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Card number',
                        hintStyle: GoogleFonts.dmSans(),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _cardExpiryController,
                            style: GoogleFonts.dmSans(),
                            keyboardType: TextInputType.datetime,
                            decoration: InputDecoration(
                              hintText: 'MM/YY',
                              hintStyle: GoogleFonts.dmSans(),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _cardCvvController,
                            style: GoogleFonts.dmSans(),
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: 'CVV',
                              hintStyle: GoogleFonts.dmSans(),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total ${_cartItems.length} item(s)', style: GoogleFonts.dmSans()),
                      Text('RM ${(_cartTotal - _voucherDiscount + (_shippingFee ?? 0)).toStringAsFixed(2)}', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _validateCheckout()
                          ? () => _createOrder(status: 'to_ship')
                          : () {
                              String msg = 'Please fill in all required fields and select a payment method.';
                              if (!_billingMatches &&
                                  (_billingAddressController.text.trim().isEmpty ||
                                   _billingPostcodeController.text.trim().isEmpty ||
                                   _billingStateController.text.trim().isEmpty ||
                                   _billingCountryController.text.trim().isEmpty)) {
                                msg = 'Please enter your full billing address.';
                              } else if (_selectedPayment == 0 && (
                                  _cardNameController.text.trim().isEmpty ||
                                  _cardNumberController.text.trim().isEmpty ||
                                  _cardExpiryController.text.trim().isEmpty ||
                                  _cardCvvController.text.trim().isEmpty)) {
                                msg = 'Please fill in all card payment details.';
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(msg)),
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[400],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text('Place Order', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          if (_showSuccess)
            Container(
              color: Colors.black.withOpacity(0.8),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Successfully Placed Order!',
                      style: GoogleFonts.dmSans(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        decoration: TextDecoration.none,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    const Icon(Icons.check_circle, color: Colors.white, size: 80),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption(int value, IconData? icon, String label, {String? asset}) {
    return InkWell(
      onTap: () => setState(() => _selectedPayment = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _selectedPayment == value ? Colors.blue[400]! : Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            if (icon != null) Icon(icon, color: Colors.blue[400]),
            if (asset != null) ...[
              Image.asset(asset, width: 32, height: 32),
              const SizedBox(width: 8),
            ],
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: GoogleFonts.dmSans(fontWeight: FontWeight.w500))),
            if (_selectedPayment == value)
              const Icon(Icons.check_circle, color: Colors.blue),
          ],
        ),
      ),
    );
  }

  // Add this function to extract postcode from address
  String extractPostcode(String address) {
    final match = RegExp(r'\b(\d{5})\b').firstMatch(address);
    return match?.group(1) ?? '';
  }

  String extractState(String address) {
    // List of Malaysian states and federal territories
    final states = [
      'Selangor', 'Kuala Lumpur', 'Penang', 'Pulau Pinang', 'Sabah', 'Sarawak', 'Johor', 'Perak',
      'Pahang', 'Negeri Sembilan', 'Melaka', 'Kelantan', 'Terengganu', 'Perlis', 'Kedah', 'Labuan', 'Putrajaya'
    ];
    for (final state in states) {
      if (address.toLowerCase().contains(state.toLowerCase())) return state;
    }
    return '';
  }

  String extractCountry(String address) {
    if (address.toLowerCase().contains('malaysia')) return 'Malaysia';
    return '';
  }
} 