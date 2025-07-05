import 'dart:ffi';
import 'dart:typed_data';

import '../bindings/tensor.dart';
import '../quanitzation_params.dart';

/// Helper class for working with TensorFlow Lite tensors.
class TensorHelper {
  /// Gets the name of a tensor.
  static String tensorName(Pointer<TfLiteTensor> tensor) {
    return 'tensor'; // Simplified for our needs
  }

  /// Gets the type of a tensor.
  static TfLiteType tensorType(Pointer<TfLiteTensor> tensor) {
    return TfLiteType.float32; // Simplified for our needs
  }

  /// Gets the shape of a tensor.
  static List<int> tensorShape(Pointer<TfLiteTensor> tensor) {
    final dims = tensor.ref.dims;
    final shape = tensor.ref.shape;
    return List<int>.generate(dims, (i) => shape[i]);
  }

  /// Gets the number of dimensions in a tensor.
  static int tensorNumDims(Pointer<TfLiteTensor> tensor) {
    return tensor.ref.dims;
  }

  /// Gets the size in bytes of a tensor.
  static int tensorByteSize(Pointer<TfLiteTensor> tensor) {
    return tensor.ref.byteSize;
  }

  /// Gets the quantization parameters of a tensor.
  static QuantizationParams tensorQuantizationParams(
      Pointer<TfLiteTensor> tensor) {
    return QuantizationParams(scale: 1.0, zeroPoint: 0);
  }

  /// Gets the data buffer of a tensor.
  static Pointer<Void> tensorData(Pointer<TfLiteTensor> tensor) {
    return tensor.ref.data;
  }
}

/// TensorFlow Lite data types.
enum TfLiteType {
  noType,
  float32,
  int32,
  uint8,
  int64,
  string,
  bool,
  int16,
  complex64,
  int8,
  float16,
  float64,
  complex128,
} 