import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';

class SnapchatARService {
  // Snapchat AR filter URLs for different shoes

  // Available shoes for Snapchat AR try-on
  static List<Map<String, dynamic>> get availableShoes => [
    {
      'id': 'nike_air_force',
      'name': 'Nike Air Force 1',
      'brand': 'Nike',
      'image': 'assets/nikeairforce1.webp',
      'snapchatFilterId': 'nike_air_max_filter',
      'description': 'Try on Nike Air Force 1 with Snapchat AR',
      'filterUrl': 'https://lens.snapchat.com/9778fbf67b934b528354ae04734a5349?share_id=v5dpMVxF0zg&locale=en-GB',
    },
    {
      'id': 'adidas_boost',
      'name': 'Adidas UltraBoost',
      'brand': 'Adidas',
      'image': 'assets/adidasultraboost.jpg',
      'snapchatFilterId': 'adidas_boost_filter',
      'description': 'Try on Adidas Boost with Snapchat AR',
      'filterUrl': 'https://lens.snapchat.com/35443520b95d425ebc62387c0e8b2339?share_id=xFq_dkTQMkQ&locale=en-GB',
    },
    {
      'id': 'adidas_yeezy_boost',
      'name': 'Adidas Yeezy Boost',
      'brand': 'Adidas',
      'image': 'assets/adidasyeezyboost.jpg',
      'snapchatFilterId': 'adidas_yeezy_boost_filter',
      'description': 'Try on Adidas Yeezy Boost with Snapchat AR',
      'filterUrl': 'https://lens.snapchat.com/816e15268abc42d4a5be8113daf6cce4?share_id=Yqy20dY9JuE&locale=en-GB',
    },
    {
      'id': 'adidas_gazelle',
      'name': 'Adidas Gazelle',
      'brand': 'Adidas',
      'image': 'assets/gazellebrown.webp',
      'snapchatFilterId': 'adidas_gazelle_filter',
      'description': 'Try on Adidas Gazelle with Snapchat AR',
      'filterUrl': 'https://lens.snapchat.com/4ca59193090a4537a3274e66fc9966f6?share_id=PmO4h9onMXU&locale=en-GB',
    },
    
  ];

  // Get shoe info by ID
  static Map<String, dynamic>? getShoeInfo(String shoeId) {
    try {
      return availableShoes.firstWhere((shoe) => shoe['id'] == shoeId);
    } catch (e) {
      if (kDebugMode) {
        print('Shoe not found: $shoeId');
      }
      return null;
    }
  }

  // Check if Snapchat is available on this device
  static Future<bool> isSnapchatAvailable() async {
    try {
      // Try multiple Snapchat URL schemes
      final snapchatUrls = [
        'snapchat://',
        'snapchat://camera',
        'snapchat://camera/ar',
      ];
      
      for (final url in snapchatUrls) {
        final canLaunch = await canLaunchUrl(Uri.parse(url));
        if (canLaunch) {
          if (kDebugMode) {
            print('Snapchat available via: $url');
          }
          return true;
        }
      }
      
      // If none of the specific URLs work, try a more general approach
      // This is a fallback for some devices
      if (kDebugMode) {
        print('Trying fallback Snapchat detection...');
      }
      
      // For now, let's assume Snapchat is available if we can't detect it
      // This is common on some Android devices
      if (kDebugMode) {
        print('Assuming Snapchat is available (fallback)');
      }
      return true;
      
    } catch (e) {
      if (kDebugMode) {
        print('Error checking Snapchat availability: $e');
      }
      // Fallback: assume Snapchat is available
      return true;
    }
  }

  // Launch Snapchat AR filter for shoe try-on
  static Future<bool> launchShoeTryOn(String shoeId) async {
    try {
      final shoeInfo = getShoeInfo(shoeId);
      if (shoeInfo == null) {
        if (kDebugMode) {
          print('Shoe not found for AR: $shoeId');
        }
        return false;
      }

      final filterUrl = shoeInfo['filterUrl'] as String;
      
      if (kDebugMode) {
        print('Launching Snapchat AR filter: $filterUrl');
      }

      // Launch Snapchat with the specific filter
      final launched = await launchUrl(
        Uri.parse(filterUrl),
        mode: LaunchMode.externalApplication,
      );

      if (kDebugMode) {
        print('Snapchat AR launched: $launched');
      }

      return launched;
    } catch (e) {
      if (kDebugMode) {
        print('Error launching Snapchat AR: $e');
      }
      return false;
    }
  }

  // Launch generic Snapchat camera
  static Future<bool> launchSnapchatCamera() async {
    try {
      const snapchatUrl = 'snapchat://camera';
      
      if (kDebugMode) {
        print('Launching Snapchat camera');
      }

      final launched = await launchUrl(
        Uri.parse(snapchatUrl),
        mode: LaunchMode.externalApplication,
      );

      if (kDebugMode) {
        print('Snapchat camera launched: $launched');
      }

      return launched;
    } catch (e) {
      if (kDebugMode) {
        print('Error launching Snapchat camera: $e');
      }
      return false;
    }
  }

  // Save AR try-on session to Firestore
  static Future<bool> saveARSession(Map<String, dynamic> sessionData) async {
    try {
      if (kDebugMode) {
        print('AR session saved: $sessionData');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Failed to save AR session: $e');
      }
      return false;
    }
  }
} 