import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class DeepAREffectManager {
  static const List<String> _requiredEffects = [
    'nike_air_force_1.deepar',
    'airmax.deepar',
    'adidas_ultraboost.deepar',
    'adidas_yeezy_boost.deepar',
    'gazelle.deepar',
    'basic_face.deepar',
    'body_tracking.deepar',
    'object_placement.deepar',
  ];

  /// Check if all required effects are available
  static Future<Map<String, bool>> checkEffectsAvailability() async {
    final Map<String, bool> availability = {};
    
    for (final effect in _requiredEffects) {
      availability[effect] = await _isEffectAvailable(effect);
    }
    
    return availability;
  }

  /// Check if a specific effect is available
  static Future<bool> _isEffectAvailable(String effectName) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final effectPath = '${appDir.path}/effects/$effectName';
      return File(effectPath).exists();
    } catch (e) {
      if (kDebugMode) {
        print('Error checking effect availability: $e');
      }
      return false;
    }
  }

  /// Get list of missing effects
  static Future<List<String>> getMissingEffects() async {
    final availability = await checkEffectsAvailability();
    return availability.entries
        .where((entry) => !entry.value)
        .map((entry) => entry.key)
        .toList();
  }

  /// Get list of available effects
  static Future<List<String>> getAvailableEffects() async {
    final availability = await checkEffectsAvailability();
    return availability.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
  }

  /// Get effect path for a specific effect
  static Future<String?> getEffectPath(String effectName) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final effectPath = '${appDir.path}/effects/$effectName';
      
      if (await File(effectPath).exists()) {
        return effectPath;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting effect path: $e');
      }
      return null;
    }
  }

  /// Copy effect from assets to app documents
  static Future<bool> copyEffectFromAssets(String assetPath, String effectName) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final effectsDir = Directory('${appDir.path}/effects');
      
      if (!await effectsDir.exists()) {
        await effectsDir.create(recursive: true);
      }
      
      final sourceFile = File(assetPath);
      final targetFile = File('${effectsDir.path}/$effectName');
      
      if (await sourceFile.exists()) {
        await sourceFile.copy(targetFile.path);
        if (kDebugMode) {
          print('Effect copied: $effectName');
        }
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Error copying effect: $e');
      }
      return false;
    }
  }

  /// Get download instructions for missing effects
  static String getDownloadInstructions() {
    return '''
# DeepAR Effects Download Instructions

## 1. Free Filter Pack
Visit: https://docs.deepar.ai/deepar-sdk/filters
Download the free filter pack and extract the .deepar files.

## 2. DeepAR Asset Store
Visit: https://www.store.deepar.ai/
Browse professional shoe try-on effects.

## 3. Required Effects
Place these .deepar files in your assets/effects/ directory:
${_requiredEffects.map((effect) => '- $effect').join('\n')}

## 4. Testing
- Basic face filters work immediately
- Shoe effects require foot tracking
- Body tracking needs full body in frame
- Object placement works with any surface

## 5. Custom Effects
Use DeepAR Studio to create custom effects:
https://docs.deepar.ai/deepar-sdk/studio
''';
  }

  /// Validate effect file
  static Future<bool> validateEffect(String effectPath) async {
    try {
      final file = File(effectPath);
      if (!await file.exists()) {
        return false;
      }
      
      // Check if it's a .deepar file
      if (!effectPath.endsWith('.deepar')) {
        return false;
      }
      
      // Check file size (should be reasonable)
      final size = await file.length();
      if (size < 1024 || size > 100 * 1024 * 1024) { // 1KB to 100MB
        return false;
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error validating effect: $e');
      }
      return false;
    }
  }
} 