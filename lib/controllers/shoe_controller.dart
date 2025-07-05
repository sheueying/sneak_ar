import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product.dart';

class ProductController {
  Future<List<Product>> loadProducts() async {
    final QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('products').get();
    return snapshot.docs
        .map((doc) => Product.fromFirestore(doc.id, doc.data() as Map<String, dynamic>))
        .toList();
  }
}
