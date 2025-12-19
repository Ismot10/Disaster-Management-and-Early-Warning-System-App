import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class FloodAIService {
  late Interpreter _interpreter;
  bool _isModelLoaded = false;

  /// Load the TFLite model from assets
  Future<void> loadModel() async {
    try {
      // Interpreter options without FlexDelegate
      final options = InterpreterOptions();
      _interpreter = await Interpreter.fromAsset(
        'assets/models/flood_lstm_model.tflite',
        options: options,
      );

      _isModelLoaded = true;
      debugPrint("✅ Flood AI model loaded successfully");
    } catch (e) {
      _isModelLoaded = false;
      debugPrint("❌ Failed to load AI model: $e");
    }
  }

  /// Predict future water level
  /// `last10Readings` should be a list of lists: [[r1], [r2], ..., [r10]]
  double predictFutureWaterLevel(List<List<double>> last10Readings) {
    if (!_isModelLoaded) {
      debugPrint("⚠ AI model not loaded, returning 0.0");
      return 0.0;
    }

    try {
      // Convert input to Float32List for TFLite
      final input = Float32List(last10Readings.length * last10Readings[0].length);
      for (int i = 0; i < last10Readings.length; i++) {
        for (int j = 0; j < last10Readings[i].length; j++) {
          input[i * last10Readings[i].length + j] = last10Readings[i][j].toDouble();
        }
      }

      // Reshape input as [1, timesteps, features]
      final shapedInput = input.reshape([1, last10Readings.length, last10Readings[0].length]);

      // Prepare output (assume single value prediction)
      final output = List.filled(1, 0.0).reshape([1, 1]);

      // Run inference
      _interpreter.run(shapedInput, output);

      return output[0][0];
    } catch (e) {
      debugPrint("❌ Error running AI model: $e");
      return 0.0;
    }
  }

  /// Close interpreter when done
  void close() {
    _interpreter.close();
  }
}

/// Extension method to reshape List/Float32List easily
extension ListReshape<T> on List<T> {
  List reshape(List<int> shape) {
    if (shape.length == 2) {
      int rows = shape[0];
      int cols = shape[1];
      if (rows * cols != this.length) {
        throw Exception("Cannot reshape list of length ${this.length} to shape $shape");
      }
      List<List<T>> reshaped = List.generate(rows, (i) => List.generate(cols, (j) => this[i * cols + j]));
      return reshaped as List<T>;
    } else {
      throw Exception("Only 2D reshape supported");
    }
  }
}
