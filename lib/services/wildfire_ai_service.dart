import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:firebase_database/firebase_database.dart';

class WildfireAIService {
  late Interpreter _interpreter;
  bool _isModelLoaded = false;

  bool get isModelLoaded => _isModelLoaded;

  /// Firebase reference
  final DatabaseReference _dbRef =
  FirebaseDatabase.instance.ref('wildfireData');

  /// -------------------------------
  /// Min–Max scaling (same as Python)
  /// -------------------------------
  double _scale(double value, double min, double max) {
    if (max == min) return 0.0;
    return ((value - min) / (max - min)).clamp(0.0, 1.0);
  }

  /// --------------------------------
  /// Load TFLite model
  /// --------------------------------
  Future<void> loadModel() async {
    try {
      final options = InterpreterOptions();

      _interpreter = await Interpreter.fromAsset(
        'assets/models/wildfire_model.tflite',
        options: options,
      );

      _isModelLoaded = true;
      debugPrint("✅ Wildfire AI model loaded");
    } catch (e) {
      _isModelLoaded = false;
      debugPrint("❌ Failed to load wildfire model: $e");
    }
  }

  /// ---------------------------------------------------
  /// Fetch last 5 readings → rolling window
  /// Output shape: [5][4]
  /// ---------------------------------------------------
  Future<List<List<double>>> fetchLast5Readings() async {
    try {
      final snapshot = await _dbRef.orderByKey().limitToLast(5).get();

      if (!snapshot.exists) {
        throw Exception("No wildfire data found");
      }

      List<Map<String, dynamic>> rows = [];

      for (final child in snapshot.children) {
        final map = Map<String, dynamic>.from(child.value as Map);
        rows.add(map);
      }

      // Ensure chronological order
      rows.sort((a, b) => a['timestamp'].compareTo(b['timestamp']));

      final List<List<double>> window = rows.map((e) {
        final temp = _scale((e['temperature'] as num).toDouble(), 0, 60);
        final hum = _scale((e['humidity'] as num).toDouble(), 0, 100);
        final gas = _scale((e['gas_value'] as num).toDouble(), 0, 1000);
        final flame = _scale((e['flame_detected'] as num).toDouble(), 0, 1);

        return [temp, hum, gas, flame];
      }).toList();

      if (window.length != 5) {
        throw Exception("Expected 5 readings, got ${window.length}");
      }

      debugPrint("🔥 Wildfire input (scaled): ${window.last}");
      return window;
    } catch (e) {
      debugPrint("❌ Error fetching wildfire data: $e");

      // fallback safe window
      return List.generate(5, (_) => [0.0, 0.0, 0.0, 0.0]);
    }
  }

  /// ---------------------------------------------------
  /// Predict wildfire probability
  /// ---------------------------------------------------
  Future<double> predictWildfireRisk() async {
    if (!_isModelLoaded) {
      debugPrint("⚠️ Model not loaded");
      return 0.0;
    }

    try {
      final window = await fetchLast5Readings();

      // Flatten 5x4 → 20
      final flatInput = window.expand((e) => e).toList();

      // Model input shape: [1, 20]
      final input = [flatInput];

      // Output: [1,1]
      final output = List.filled(1, 0.0).reshape([1, 1]);

      _interpreter.run(input, output);

      final prediction = output[0][0];

      debugPrint("🔥 Wildfire probability: $prediction");

      return prediction;
    } catch (e) {
      debugPrint("❌ Inference error: $e");
      return 0.0;
    }
  }

  /// Close interpreter
  void close() {
    _interpreter.close();
  }
}

/// ------------------------------------
/// Helper reshape extension
/// ------------------------------------
extension ListReshape<T> on List<T> {
  List<List<T>> reshape(List<int> shape) {
    if (shape.length != 2) {
      throw Exception("Only 2D reshape supported");
    }

    int rows = shape[0];
    int cols = shape[1];

    if (rows * cols != length) {
      throw Exception("Cannot reshape list of length $length to $shape");
    }

    return List.generate(
      rows,
          (i) => List.generate(cols, (j) => this[i * cols + j]),
    );
  }
}
