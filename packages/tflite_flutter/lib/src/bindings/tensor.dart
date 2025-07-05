import 'dart:ffi';

/// TensorFlow Lite tensor struct.
final class TfLiteTensor extends Struct {
  @Int32()
  external int type;

  external Pointer<Void> data;

  @Int32()
  external int dims;

  external Pointer<Int32> shape;

  @Int32()
  external int byteSize;

  @Int32()
  external int quantization;
} 