import 'dart:convert';
import 'package:http/http.dart' as http;

class EasyParcelService {
  // Replace with your real EasyParcel API key
  static const String apiKey = 'EP-Ew6UaCyN1';
  static const String demoAuthKey = 'tKFrsifHog';

  /// Get courier rates from EasyParcel
  static Future<List<EasyParcelRate>> getRates({
    required String fromPostcode,
    required String toPostcode,
    required double weightKg,
  }) async {
    final url = Uri.parse('https://connect.easyparcel.my/?ac=EPRateCheckingBulk');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'api': apiKey,
        'bulk': [
          {
            'pick_code': fromPostcode,
            'send_code': toPostcode,
            'weight': weightKg,
            'pick_country': 'MY', // Malaysia
            'send_country': 'MY', // Malaysia
          }
        ]
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List rates = data['result'][0]['rates'] ?? [];
      return rates.map((r) => EasyParcelRate.fromJson(r)).toList();
    } else {
      throw Exception('Failed to fetch rates');
    }
  }

  /// Mock/demo booking: returns fake tracking/order ID
  static Future<Map<String, dynamic>> bookShipment({
    required String fromPostcode,
    required String toPostcode,
    required double weightKg,
    required String courier,
  }) async {
    // In real use, call EasyParcel's booking API. Here, return mock data.
    await Future.delayed(const Duration(seconds: 1));
    return {
      'tracking_number': 'EPDEMO${DateTime.now().millisecondsSinceEpoch}',
      'order_id': 'DEMOORDER${DateTime.now().millisecondsSinceEpoch}',
    };
  }

  /// Helper to convert EasyParcelRate to Map for UI
  static Map<String, dynamic> rateToMap(EasyParcelRate rate) {
    return {
      'courier_id': rate.courier,
      'courier_name': rate.courier,
      'rate': rate.price,
      'service': rate.service,
      'delivery': rate.delivery,
    };
  }
}

class EasyParcelRate {
  final String courier;
  final String service;
  final double price;
  final String delivery;

  EasyParcelRate({
    required this.courier,
    required this.service,
    required this.price,
    required this.delivery,
  });

  factory EasyParcelRate.fromJson(Map<String, dynamic> json) {
    return EasyParcelRate(
      courier: json['courier_name'] ?? '',
      service: json['service_name'] ?? '',
      price: double.tryParse(json['price'].toString()) ?? 0.0,
      delivery: json['delivery'] ?? '',
    );
  }
} 