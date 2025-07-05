import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class DeepARService {
  static const MethodChannel _channel = MethodChannel('deepar_channel');
  
  // DeepAR License Key
  static const String _licenseKey = 'a3397d589f6c7372ad3cf316fdfd9d7802fb9f3fad9167d1dcc9c1898d5ae3927f0ba47bfdd8fc76';
  
  // Available shoes data
  static const List<Map<String, dynamic>> availableShoes = [
    {
      'id': 'nike_air_force_1',
      'name': 'Nike Air Force 1',
      'image': 'assets/nikeairforce.jpg',
      'effectPath': 'effects/nike_air_force_1.deepar',
    },
    {
      'id': 'nike_airmax',
      'name': 'Nike Air Max',
      'image': 'assets/nikeairforce.jpg', // You can add a specific airmax image later
      'effectPath': 'effects/airmax.deepar',
    },
    {
      'id': 'adidas_ultraboost',
      'name': 'Adidas Ultraboost',
      'image': 'assets/adidasultraboost.jpg',
      'effectPath': 'effects/adidas_ultraboost.deepar',
    },
    {
      'id': 'adidas_yeezy_boost',
      'name': 'Adidas Yeezy Boost',
      'image': 'assets/adidasyeezyboost.jpg',
      'effectPath': 'effects/adidas_yeezy_boost.deepar',
    },
    {
      'id': 'gazelle',
      'name': 'Gazelle',
      'image': 'assets/gazelle.avif',
      'effectPath': 'effects/gazelle.deepar',
    },
  ];
  
  /// Initialize DeepAR SDK
  static Future<bool> initialize() async {
    try {
      final bool result = await _channel.invokeMethod('initialize', {
        'licenseKey': _licenseKey,
      });
      return result;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('Failed to initialize DeepAR: ${e.message}');
      }
      return false;
    }
  }
  
  /// Start AR session
  static Future<bool> startARSession() async {
    try {
      final bool result = await _channel.invokeMethod('startARSession');
      return result;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('Failed to start AR session: ${e.message}');
      }
      return false;
    }
  }
  
  /// Stop AR session
  static Future<bool> stopARSession() async {
    try {
      final bool result = await _channel.invokeMethod('stopARSession');
      return result;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('Failed to stop AR session: ${e.message}');
      }
      return false;
    }
  }
  
  /// Switch AR effect/filter
  static Future<bool> switchEffect(String effectPath) async {
    try {
      if (kDebugMode) {
        print('Switching to effect: $effectPath');
      }
      
      final bool result = await _channel.invokeMethod('switchEffect', {
        'effectPath': effectPath,
      });
      
      if (kDebugMode) {
        print('Effect switch result: $result');
      }
      
      return result;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('Failed to switch effect: ${e.message}');
      }
      return false;
    }
  }
  
  /// Take screenshot
  static Future<String?> takeScreenshot() async {
    try {
      final String? result = await _channel.invokeMethod('takeScreenshot');
      return result;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('Failed to take screenshot: ${e.message}');
      }
      return null;
    }
  }
  
  /// Record video
  static Future<bool> startRecording() async {
    try {
      final bool result = await _channel.invokeMethod('startRecording');
      return result;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('Failed to start recording: ${e.message}');
      }
      return false;
    }
  }
  
  /// Stop recording
  static Future<String?> stopRecording() async {
    try {
      final String? result = await _channel.invokeMethod('stopRecording');
      return result;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('Failed to stop recording: ${e.message}');
      }
      return null;
    }
  }
  
  /// Check if DeepAR is available
  static Future<bool> isAvailable() async {
    try {
      final bool result = await _channel.invokeMethod('isAvailable');
      return result;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('DeepAR availability check failed: ${e.message}');
      }
      return false;
    }
  }
  
  /// Get available effects
  static Future<List<String>> getAvailableEffects() async {
    try {
      final List<dynamic> result = await _channel.invokeMethod('getAvailableEffects');
      return result.cast<String>();
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('Failed to get available effects: ${e.message}');
      }
      return [];
    }
  }
  
  /// Check if DeepAR is available (alias for isAvailable)
  static Future<bool> isDeepARAvailable() async {
    return await isAvailable();
  }
  
  /// Get shoe info by ID
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
  
  /// Launch shoe try-on with DeepAR
  static Future<bool> launchShoeTryOn(String shoeId) async {
    try {
      final shoeInfo = getShoeInfo(shoeId);
      if (shoeInfo == null) {
        if (kDebugMode) {
          print('Shoe info not found for ID: $shoeId');
        }
        return false;
      }
      
      // Initialize DeepAR if not already done
      final initialized = await initialize();
      if (!initialized) {
        if (kDebugMode) {
          print('Failed to initialize DeepAR');
        }
        return false;
      }
      
      // Start AR session
      final sessionStarted = await startARSession();
      if (!sessionStarted) {
        if (kDebugMode) {
          print('Failed to start AR session');
        }
        return false;
      }
      
      // Switch to the shoe effect
      final effectPath = shoeInfo['effectPath'] as String;
      final effectSwitched = await switchEffect(effectPath);
      if (!effectSwitched) {
        if (kDebugMode) {
          print('Failed to switch to effect: $effectPath');
        }
        return false;
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Failed to launch DeepAR shoe try-on: $e');
      }
      return false;
    }
  }
} 