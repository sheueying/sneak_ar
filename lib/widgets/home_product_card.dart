import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shoefit_application/models/product.dart';
import 'package:shoefit_application/product_detail_screen.dart';

class HomeProductCard extends StatelessWidget {
  final Product product;
  final bool isHorizontal;

  const HomeProductCard({
    super.key,
    required this.product,
    this.isHorizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(productId: product.id),
          ),
        );
      },
      child: Container(
        width: isHorizontal ? 160 : null,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.2,
              child: Image.network(product.imageUrl, fit: BoxFit.contain),
            ),
            const SizedBox(height: 8),
            Text(
              product.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(fontWeight: FontWeight.bold),
            ),
            Text(
              'RM ${product.price.toStringAsFixed(2)}',
              style: GoogleFonts.dmSans(),
            ),
          ],
        ),
      ),
    );
  }
} 