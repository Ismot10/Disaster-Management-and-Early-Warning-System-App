import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:firebase_database/firebase_database.dart';

class EarthquakeAIService {
  late Interpreter _interpreter;
  bool _isModelLoaded = false;

  bool get isModelLoaded => _isModelLoaded;

  /// Firebase reference
  final DatabaseReference _dbRef =
  FirebaseDatabase.instance.ref('earthquakeData');

  /// -------------------------------
  /// Min–Max scaling (same as Python)
  /// motion     → assumed range: 0–1
  /// vibration  → 0 or 1
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
        'assets/models/earthquake_intensity_lstm_model.tflite',
        options: options,
      );

      _isModelLoaded = true;
      debugPrint("✅ Earthquake AI model loaded");
    } catch (e) {
      _isModelLoaded = false;
      debugPrint("❌ Failed to load earthquake model: $e");
    }
  }

  /// ---------------------------------------------------
  /// Fetch last 15 readings → rolling window
  /// Output shape: [15][2]
  /// ---------------------------------------------------
  Future<List<List<double>>> fetchLast15Readings() async {
    try {
      final snapshot =
      await _dbRef.orderByKey().limitToLast(15).get();

      if (!snapshot.exists) {
        throw Exception("No earthquake data found");
      }

      List<Map<String, dynamic>> rows = [];

      for (final child in snapshot.children) {
        final map = Map<String, dynamic>.from(child.value as Map);
        rows.add(map);
      }

      // Ensure chronological order
      rows.sort((a, b) => a['timestamp'].compareTo(b['timestamp']));

      final List<List<double>> window = rows.map((e) {
        final motion =
        _scale((e['motion'] ?? 0).toDouble(), 0, 1);
        final vibration =
        _scale((e['vibration_detected'] as num).toDouble(), 0, 1);

        return [motion, vibration];
      }).toList();

      if (window.length != 15) {
        throw Exception("Expected 15 readings, got ${window.length}");
      }

      debugPrint("🌎 Earthquake input (scaled): ${window.last}");
      return window;
    } catch (e) {
      debugPrint("❌ Error fetching earthquake data: $e");

      // Safe fallback
      return List.generate(15, (_) => [0.0, 0.0]);
    }
  }

  /// ---------------------------------------------------
  /// Predict earthquake intensity
  /// Output classes:
  /// 0 → Low
  /// 1 → Medium
  /// 2 → High
  /// ---------------------------------------------------
  Future<int> predictEarthquakeIntensity() async {
    if (!_isModelLoaded) {
      debugPrint("⚠️ Model not loaded");
      return 0;
    }

    try {
      final window = await fetchLast15Readings();

      // Input shape: [1, 15, 2]
      final input = [window];

      // Output shape: [1, 3]
      final output = List.filled(3, 0.0).reshape([1, 3]);

      _interpreter.run(input, output);

      final probabilities = output[0];

      final predictedClass =
      probabilities.indexOf(probabilities.reduce((a, b) => a > b ? a : b));

      debugPrint(
          "🌎 Earthquake probs → Low:${probabilities[0].toStringAsFixed(2)} "
              "Medium:${probabilities[1].toStringAsFixed(2)} "
              "High:${probabilities[2].toStringAsFixed(2)}");

      return predictedClass;
    } catch (e) {
      debugPrint("❌ Inference error: $e");
      return 0;
    }
  }

  // ✅ ADD THIS METHOD HERE (INSIDE THE CLASS)
  Future<int> predictFromWindow(List<List<double>> window) async {
    if (!_isModelLoaded) return 0;

    try {
      final input = [window]; // [1,15,2]
      final output = List.filled(3, 0.0).reshape([1, 3]);

      _interpreter.run(input, output);

      final probs = output[0];
      return probs.indexOf(probs.reduce((a, b) => a > b ? a : b));
    } catch (e) {
      debugPrint("❌ Inference error: $e");
      return 0;
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
