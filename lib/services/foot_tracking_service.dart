// import 'dart:typed_data';
// import 'dart:math';
// import 'package:flutter/foundation.dart';
// import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
// import 'package:camera/camera.dart';
// import 'package:image/image.dart' as img;
// import 'package:collection/collection.dart';
// import 'package:quiver/collection.dart';

// class FootTrackingService {
//   static tfl.Interpreter? _interpreter;
//   static bool _isInitialized = false;
  
//   // Model configurations
//   static const String modelPath = 'assets/models/foot_detection.tflite';
//   static const int inputSize = 256; // Input size for the model
//   static const double confidenceThreshold = 0.7;
  
//   // Foot landmarks (key points for shoe placement)
//   static const List<String> landmarks = [
//     'heel',
//     'ankle',
//     'toe_tip',
//     'ball_of_foot',
//     'arch',
//   ];

//   /// Initialize the foot tracking service
//   static Future<bool> initialize() async {
//     if (_isInitialized) return true;

//     try {
//       // Load TensorFlow Lite model
//       final options = tfl.InterpreterOptions()
//         ..threads = 4;

//       _interpreter = await tfl.Interpreter.fromAsset(
//         modelPath,
//         options: options,
//       );

//       if (kDebugMode) {
//         print('Foot tracking model loaded successfully');
//       }

//       _isInitialized = true;
//       return true;
//     } catch (e) {
//       if (kDebugMode) {
//         print('Failed to initialize foot tracking: $e');
//       }
//       return false;
//     }
//   }

//   /// Process camera frame for foot detection
//   static Future<Map<String, dynamic>?> processFrame(CameraImage image) async {
//     if (!_isInitialized || _interpreter == null) {
//       if (kDebugMode) {
//         print('Foot tracking not initialized');
//       }
//       return null;
//     }

//     try {
//       // Convert CameraImage to input tensor format
//       final inputArray = await _preprocessImage(image);
//       if (inputArray == null) return null;

//       // Get input and output shapes
//       final inputShape = _interpreter!.getInputTensor(0).shape;
//       final outputShape = _interpreter!.getOutputTensor(0).shape;
//       final outputSize = outputShape.reduce((a, b) => a * b);

//       // Create input tensor
//       final input = Float32List(inputSize * inputSize * 3);
//       for (var i = 0; i < inputArray.length; i++) {
//         input[i] = inputArray[i];
//       }

//       // Create output tensor
//       final output = Float32List(outputSize);

//       // Run inference
//       _interpreter!.run(
//         input.buffer.asFloat32List(),
//         output.buffer.asFloat32List(),
//       );

//       // Process results
//       final footData = _processOutput(output.toList());
      
//       if (footData != null && footData['confidence'] > confidenceThreshold) {
//         if (kDebugMode) {
//           print('Foot detected: ${footData['landmarks']}');
//         }
//         return footData;
//       }

//       return null;
//     } catch (e) {
//       if (kDebugMode) {
//         print('Error processing frame: $e');
//       }
//       return null;
//     }
//   }

//   /// Preprocess camera image for model input
//   static Future<List<double>?> _preprocessImage(CameraImage image) async {
//     try {
//       // Convert YUV to RGB
//       final img.Image? rgbImage = await _convertYUV420toRGB(image);
//       if (rgbImage == null) return null;

//       // Resize image to model input size
//       final resized = img.copyResize(
//         rgbImage,
//         width: inputSize,
//         height: inputSize,
//       );

//       // Convert to float array and normalize
//       final inputArray = List<double>.filled(inputSize * inputSize * 3, 0);
//       var index = 0;

//       for (var y = 0; y < inputSize; y++) {
//         for (var x = 0; x < inputSize; x++) {
//           final pixel = resized.getPixel(x, y);
//           inputArray[index++] = pixel.r / 255.0;
//           inputArray[index++] = pixel.g / 255.0;
//           inputArray[index++] = pixel.b / 255.0;
//         }
//       }

//       return inputArray;
//     } catch (e) {
//       if (kDebugMode) {
//         print('Error preprocessing image: $e');
//       }
//       return null;
//     }
//   }

//   /// Convert YUV420 format to RGB
//   static Future<img.Image?> _convertYUV420toRGB(CameraImage image) async {
//     try {
//       final int width = image.width;
//       final int height = image.height;
      
//       final int uvRowStride = image.planes[1].bytesPerRow;
//       final int uvPixelStride = image.planes[1].bytesPerPixel!;

//       // Create a copy of the bytes to avoid UnmodifiableUint8ListView
//       final yPlane = Uint8List.fromList(image.planes[0].bytes);
//       final uPlane = Uint8List.fromList(image.planes[1].bytes);
//       final vPlane = Uint8List.fromList(image.planes[2].bytes);

//       final rgbBytes = Uint8List(width * height * 3);

//       for (int x = 0; x < width; x++) {
//         for (int y = 0; y < height; y++) {
//           final int uvIndex = uvPixelStride * (x ~/ 2) +
//               uvRowStride * (y ~/ 2);
//           final int index = y * width + x;

//           final yp = yPlane[index];
//           final up = uPlane[uvIndex];
//           final vp = vPlane[uvIndex];

//           // Convert YUV to RGB
//           int r = (yp + vp * 1436 ~/ 1024 - 179).clamp(0, 255);
//           int g = (yp - up * 46549 ~/ 131072 + 44 - vp * 93604 ~/ 131072 + 91).clamp(0, 255);
//           int b = (yp + up * 1814 ~/ 1024 - 227).clamp(0, 255);

//           rgbBytes[index * 3] = r;
//           rgbBytes[index * 3 + 1] = g;
//           rgbBytes[index * 3 + 2] = b;
//         }
//       }

//       return img.Image.fromBytes(
//         width: width,
//         height: height,
//         bytes: rgbBytes.buffer,
//         order: img.ChannelOrder.rgb,
//       );
//     } catch (e) {
//       if (kDebugMode) {
//         print('Error converting YUV to RGB: $e');
//       }
//       return null;
//     }
//   }

//   /// Process model output to extract foot landmarks
//   static Map<String, dynamic>? _processOutput(List<double> output) {
//     try {
//       // Extract confidence scores and landmark coordinates
//       final List<Map<String, double>> landmarkList = [];
      
//       for (int i = 0; i < landmarks.length; i++) {
//         landmarkList.add({
//           'x': output[i * 3],
//           'y': output[i * 3 + 1],
//           'confidence': output[i * 3 + 2],
//         });
//       }

//       // Calculate overall confidence as average of landmark confidences
//       final avgConfidence = landmarkList
//           .map((l) => l['confidence']!)
//           .reduce((a, b) => a + b) / landmarks.length;

//       // Calculate foot size and orientation
//       final footSize = _calculateFootSize(landmarkList);
//       final orientation = _calculateOrientation(landmarkList);

//       return {
//         'landmarks': Map.fromIterables(
//           landmarks,
//           landmarkList,
//         ),
//         'confidence': avgConfidence,
//         'footSize': footSize,
//         'orientation': orientation,
//       };
//     } catch (e) {
//       if (kDebugMode) {
//         print('Error processing output: $e');
//       }
//       return null;
//     }
//   }

//   /// Calculate foot size based on landmarks
//   static Map<String, double> _calculateFootSize(List<Map<String, double>> landmarks) {
//     try {
//       // Get heel and toe tip points
//       final heel = landmarks[landmarks.length - 1];
//       final toeTip = landmarks[2];

//       // Calculate foot length (distance between heel and toe)
//       final footLength = _calculateDistance(
//         heel['x']!,
//         heel['y']!,
//         toeTip['x']!,
//         toeTip['y']!,
//       );

//       // Calculate foot width (distance between widest points)
//       double maxWidth = 0;
//       for (int i = 0; i < landmarks.length; i++) {
//         for (int j = i + 1; j < landmarks.length; j++) {
//           final width = _calculateDistance(
//             landmarks[i]['x']!,
//             landmarks[i]['y']!,
//             landmarks[j]['x']!,
//             landmarks[j]['y']!,
//           );
//           if (width > maxWidth) maxWidth = width;
//         }
//       }

//       return {
//         'length': footLength,
//         'width': maxWidth,
//       };
//     } catch (e) {
//       if (kDebugMode) {
//         print('Error calculating foot size: $e');
//       }
//       return {'length': 0, 'width': 0};
//     }
//   }

//   /// Calculate foot orientation based on landmarks
//   static double _calculateOrientation(List<Map<String, double>> landmarks) {
//     try {
//       // Get heel and toe tip points
//       final heel = landmarks[0];
//       final toeTip = landmarks[2];

//       // Calculate angle between heel-toe line and vertical
//       return _calculateAngle(
//         heel['x']!,
//         heel['y']!,
//         toeTip['x']!,
//         toeTip['y']!,
//       );
//     } catch (e) {
//       if (kDebugMode) {
//         print('Error calculating orientation: $e');
//       }
//       return 0;
//     }
//   }

//   /// Calculate distance between two points
//   static double _calculateDistance(double x1, double y1, double x2, double y2) {
//     return sqrt(pow(x2 - x1, 2) + pow(y2 - y1, 2));
//   }

//   /// Calculate angle between two points (relative to vertical)
//   static double _calculateAngle(double x1, double y1, double x2, double y2) {
//     return atan2(x2 - x1, y2 - y1);
//   }

//   /// Clean up resources
//   static void dispose() {
//     _interpreter?.close();
//     _interpreter = null;
//     _isInitialized = false;
//   }
// } 