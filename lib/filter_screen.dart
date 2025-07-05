import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FilterScreen extends StatefulWidget {
  final List<String> brands;
  final String? selectedBrand;
  final RangeValues? selectedPriceRange;
  final bool latestOnly;

  const FilterScreen({
    super.key,
    required this.brands,
    this.selectedBrand,
    this.selectedPriceRange,
    this.latestOnly = false,
  });

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  bool showBrands = false;
  bool showPrice = false;
  String? selectedBrand;
  RangeValues priceRange = const RangeValues(0, 1000);
  bool latestOnly = false;

  @override
  void initState() {
    super.initState();
    selectedBrand = widget.selectedBrand;
    priceRange = widget.selectedPriceRange ?? const RangeValues(0, 1000);
    latestOnly = widget.latestOnly;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Text('Filter', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 20)),
                ],
              ),
            ),
            Divider(height: 1),
            // Latest
            ListTile(
              title: Text('Latest', style: GoogleFonts.dmSans()),
              trailing: Checkbox(
                value: latestOnly,
                onChanged: (val) => setState(() => latestOnly = val ?? false),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              onTap: () => setState(() => latestOnly = !latestOnly),
            ),
            // Brands
            ExpansionTile(
              title: Text('Brands', style: GoogleFonts.dmSans()),
              initiallyExpanded: showBrands,
              onExpansionChanged: (expanded) => setState(() => showBrands = expanded),
              children: widget.brands.map((brand) => RadioListTile<String>(
                value: brand,
                groupValue: selectedBrand,
                onChanged: (val) => setState(() => selectedBrand = val),
                title: Text(brand, style: GoogleFonts.dmSans()),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              )).toList(),
            ),
            // Price Range
            ExpansionTile(
              title: Text('Price Range', style: GoogleFonts.dmSans()),
              initiallyExpanded: showPrice,
              onExpansionChanged: (expanded) => setState(() => showPrice = expanded),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: RangeSlider(
                    values: priceRange,
                    min: 0,
                    max: 1000,
                    divisions: 20,
                    labels: RangeLabels(
                      'RM${priceRange.start.toStringAsFixed(0)}',
                      'RM${priceRange.end.toStringAsFixed(0)}',
                    ),
                    onChanged: (values) => setState(() => priceRange = values),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, {
                      'latestOnly': latestOnly,
                      'brand': selectedBrand,
                      'priceRange': priceRange,
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[400],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    'Apply Filter',
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
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