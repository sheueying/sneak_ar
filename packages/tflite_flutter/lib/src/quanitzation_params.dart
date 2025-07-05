/// Parameters for asymmetric quantization.
class QuantizationParams {
  /// The scale factor used to quantize the tensor.
  final double scale;

  /// The zero point of the quantized tensor.
  final int zeroPoint;

  /// Creates a new instance of [QuantizationParams].
  const QuantizationParams({
    required this.scale,
    required this.zeroPoint,
  });
} 