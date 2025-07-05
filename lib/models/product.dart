class Product {
  final String id;
  final String brand;
  final String name;
  final String imageUrl;
  final double price;
  final String sellerId;
  final int sold;

  Product({
    required this.id,
    required this.brand,
    required this.name,
    required this.imageUrl,
    required this.price,
    required this.sellerId,
    required this.sold,
  });

  factory Product.fromFirestore(String id, Map<String, dynamic> data) {
    final imageUrls = data['imageUrls'];
    String firstImageUrl = '';

    if (imageUrls is List && imageUrls.isNotEmpty) {
      firstImageUrl = imageUrls.first as String? ?? '';
    }

    return Product(
      id: id,
      brand: data['brand'] ?? '',
      name: data['name'] ?? '',
      imageUrl: firstImageUrl,
      price: double.tryParse(data['price'].toString()) ?? 0.0,
      sellerId: data['sellerId'] ?? '',
      sold: data['sold'] ?? 0,
    );
  }
}
