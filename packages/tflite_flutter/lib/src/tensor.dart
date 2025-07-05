import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:quiver/check.dart';

import 'bindings/tensor.dart';
import 'ffi/helper.dart';
import 'interpreter.dart';
import 'quanitzation_params.dart';

/// TensorFlowLite tensor.
class Tensor {
  final Pointer<TfLiteTensor> _tensor;
  final Interpreter _interpreter;

  Tensor(this._tensor, this._interpreter);

  /// Name of the tensor.
  String get name => TensorHelper.tensorName(_tensor);

  /// Data type of the tensor.
  TfLiteType get type => TensorHelper.tensorType(_tensor);

  /// Shape of the tensor.
  List<int> get shape => TensorHelper.tensorShape(_tensor);

  /// Number of dimensions in the tensor.
  int get numDimensions => TensorHelper.tensorNumDims(_tensor);

  /// Number of bytes required to store the tensor.
  int get numBytes => TensorHelper.tensorByteSize(_tensor);

  /// Quantization parameters for the tensor.
  QuantizationParams get quantizationParams =>
      TensorHelper.tensorQuantizationParams(_tensor);

  /// Gets the tensor's data as a list of bytes.
  Uint8List get data {
    final data = TensorHelper.tensorData(_tensor);
    return data.cast<Uint8>().asTypedList(numBytes);
  }

  /// Sets the tensor's data from a list of bytes.
  set data(Uint8List bytes) {
    checkArgument(bytes.length == numBytes,
        message: 'Byte array length ${bytes.length} does not match tensor byte size $numBytes');
    final data = TensorHelper.tensorData(_tensor);
    data.cast<Uint8>().asTypedList(numBytes).setAll(0, bytes);
  }

  /// Gets the tensor's data as a list of 32-bit floats.
  Float32List get float32Data {
    checkState(type == TfLiteType.float32,
        message: 'Tensor type is not float32');
    final data = TensorHelper.tensorData(_tensor);
    return data.cast<Float>().asTypedList(numBytes ~/ 4);
  }

  /// Sets the tensor's data from a list of 32-bit floats.
  set float32Data(Float32List floats) {
    checkState(type == TfLiteType.float32,
        message: 'Tensor type is not float32');
    checkArgument(floats.length * 4 == numBytes,
        message: 'Float array length ${floats.length} does not match tensor float count ${numBytes ~/ 4}');
    final data = TensorHelper.tensorData(_tensor);
    data.cast<Float>().asTypedList(numBytes ~/ 4).setAll(0, floats);
  }

  /// Gets the tensor's data as a list of 64-bit integers.
  Int64List get int64Data {
    checkState(type == TfLiteType.int64,
        message: 'Tensor type is not int64');
    final data = TensorHelper.tensorData(_tensor);
    return data.cast<Int64>().asTypedList(numBytes ~/ 8);
  }

  /// Sets the tensor's data from a list of 64-bit integers.
  set int64Data(Int64List ints) {
    checkState(type == TfLiteType.int64,
        message: 'Tensor type is not int64');
    checkArgument(ints.length * 8 == numBytes,
        message: 'Int array length ${ints.length} does not match tensor int count ${numBytes ~/ 8}');
    final data = TensorHelper.tensorData(_tensor);
    data.cast<Int64>().asTypedList(numBytes ~/ 8).setAll(0, ints);
  }

  /// Gets the tensor's data as a list of 32-bit integers.
  Int32List get int32Data {
    checkState(type == TfLiteType.int32,
        message: 'Tensor type is not int32');
    final data = TensorHelper.tensorData(_tensor);
    return data.cast<Int32>().asTypedList(numBytes ~/ 4);
  }

  /// Sets the tensor's data from a list of 32-bit integers.
  set int32Data(Int32List ints) {
    checkState(type == TfLiteType.int32,
        message: 'Tensor type is not int32');
    checkArgument(ints.length * 4 == numBytes,
        message: 'Int array length ${ints.length} does not match tensor int count ${numBytes ~/ 4}');
    final data = TensorHelper.tensorData(_tensor);
    data.cast<Int32>().asTypedList(numBytes ~/ 4).setAll(0, ints);
  }

  /// Gets the tensor's data as a list of 8-bit integers.
  Int8List get int8Data {
    checkState(type == TfLiteType.int8,
        message: 'Tensor type is not int8');
    final data = TensorHelper.tensorData(_tensor);
    return data.cast<Int8>().asTypedList(numBytes);
  }

  /// Sets the tensor's data from a list of 8-bit integers.
  set int8Data(Int8List ints) {
    checkState(type == TfLiteType.int8,
        message: 'Tensor type is not int8');
    checkArgument(ints.length == numBytes,
        message: 'Int array length ${ints.length} does not match tensor byte size $numBytes');
    final data = TensorHelper.tensorData(_tensor);
    data.cast<Int8>().asTypedList(numBytes).setAll(0, ints);
  }

  /// Gets the tensor's data as a list of 16-bit integers.
  Int16List get int16Data {
    checkState(type == TfLiteType.int16,
        message: 'Tensor type is not int16');
    final data = TensorHelper.tensorData(_tensor);
    return data.cast<Int16>().asTypedList(numBytes ~/ 2);
  }

  /// Sets the tensor's data from a list of 16-bit integers.
  set int16Data(Int16List ints) {
    checkState(type == TfLiteType.int16,
        message: 'Tensor type is not int16');
    checkArgument(ints.length * 2 == numBytes,
        message: 'Int array length ${ints.length} does not match tensor int count ${numBytes ~/ 2}');
    final data = TensorHelper.tensorData(_tensor);
    data.cast<Int16>().asTypedList(numBytes ~/ 2).setAll(0, ints);
  }

  /// Gets the tensor's data as a list of booleans.
  List<bool> get boolData {
    checkState(type == TfLiteType.bool,
        message: 'Tensor type is not bool');
    final data = TensorHelper.tensorData(_tensor);
    return data.cast<Uint8>().asTypedList(numBytes).map((b) => b != 0).toList();
  }

  /// Sets the tensor's data from a list of booleans.
  set boolData(List<bool> bools) {
    checkState(type == TfLiteType.bool,
        message: 'Tensor type is not bool');
    checkArgument(bools.length == numBytes,
        message: 'Bool array length ${bools.length} does not match tensor byte size $numBytes');
    final data = TensorHelper.tensorData(_tensor);
    data.cast<Uint8>().asTypedList(numBytes).setAll(
        0, bools.map((b) => b ? 1 : 0));
  }

  /// Copies data from [src] to this tensor.
  void copyFrom(Tensor src) {
    checkArgument(src.numBytes == numBytes,
        message: 'Tensors have different sizes. Source tensor size: ${src.numBytes}, destination tensor size: $numBytes');
    checkArgument(src.type == type,
        message: 'Tensors have different types. Source tensor type: ${src.type}, destination tensor type: $type');

    final srcData = TensorHelper.tensorData(src._tensor);
    final dstData = TensorHelper.tensorData(_tensor);
    dstData.cast<Uint8>().asTypedList(numBytes).setAll(0, srcData.cast<Uint8>().asTypedList(numBytes));
  }
} 