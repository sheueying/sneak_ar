import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class AddDeliveryAddressScreen extends StatefulWidget {
  const AddDeliveryAddressScreen({super.key});

  @override
  State<AddDeliveryAddressScreen> createState() => _AddDeliveryAddressScreenState();
}

class _AddDeliveryAddressScreenState extends State<AddDeliveryAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final _address1 = TextEditingController();
  final _postcode = TextEditingController();
  final _state = TextEditingController();
  final _country = TextEditingController();

  List<Map<String, dynamic>> _suggestions = [];
  final String _googleApiKey = "AIzaSyASkFODp_TCgNG8HsI_9R1NtdVz82uP_h8";

  @override
  void initState() {
    super.initState();
    _address1.addListener(_onAddressChanged);
  }

  void _onAddressChanged() async {
    final input = _address1.text;
    if (input.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${Uri.encodeComponent(input)}&types=address&components=country:MY&key=$_googleApiKey',
    );
    final response = await http.get(url);
    if (kDebugMode) {
      print('Google Places Autocomplete response: \\n${response.body}');
    }
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        _suggestions = (data['predictions'] as List)
            .map((p) => {
                  'description': p['description'],
                  'place_id': p['place_id'],
                })
            .toList();
      });
    } else {
      setState(() {
        _suggestions = [];
      });
    }
  }

  Future<void> _selectSuggestion(Map<String, dynamic> suggestion) async {
    setState(() => _suggestions = []);
    final placeId = suggestion['place_id'];
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=address_component,formatted_address,name&key=$_googleApiKey',
    );
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final result = data['result'];
      if (result != null) {
        setState(() {
          _address1.text = result['formatted_address'] ?? '';
          for (var c in (result['address_components'] ?? [])) {
            final types = (c['types'] as List).cast<String>();
            if (types.contains('postal_code')) _postcode.text = c['long_name'] ?? '';
            if (types.contains('administrative_area_level_1')) _state.text = c['long_name'] ?? '';
            if (types.contains('country')) _country.text = c['long_name'] ?? '';
          }
        });
      } else {
        if (kDebugMode) print('Google Places Details API returned no result: \\n${response.body}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not fetch address details. Please check your API key or try again.')),
          );
        }
      }
    }
  }

  void _save() async {
    if (_formKey.currentState!.validate()) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final address = '${_address1.text}, ${_postcode.text} ${_state.text}, ${_country.text}';
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('addresses')
            .add({'address': address});
        Navigator.pop(context, address);
      }
    }
  }

  Widget _buildTextField(TextEditingController controller, String label, {bool required = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.dmSans(fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: required ? (v) => v!.isEmpty ? 'Required' : null : null,
          style: GoogleFonts.dmSans(),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFE3F0FF),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Add Delivery Address', style: GoogleFonts.dmSans(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Address Line 1 with autocomplete
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Address', style: GoogleFonts.dmSans(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 6),
                      Stack(
                        children: [
                          TextFormField(
                            controller: _address1,
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                            style: GoogleFonts.dmSans(),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFFE3F0FF),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                          if (_suggestions.isNotEmpty)
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
                                itemCount: _suggestions.length,
                                itemBuilder: (context, index) {
                                  final s = _suggestions[index];
                                  return ListTile(
                                    title: Text(s['description'] ?? ''),
                                    onTap: () => _selectSuggestion(s),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(_postcode, 'Postcode', required: true),
                  const SizedBox(height: 12),
                  _buildTextField(_state, 'State', required: true),
                  const SizedBox(height: 12),
                  _buildTextField(_country, 'Country', required: true),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[400],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        'Add Delivery Address',
                        style: GoogleFonts.dmSans(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 