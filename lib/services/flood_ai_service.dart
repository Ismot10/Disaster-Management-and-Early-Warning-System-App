import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:firebase_database/firebase_database.dart';

class FloodAIService {
  late Interpreter _interpreter;
  bool _isModelLoaded = false;

  /// Public getter
  bool get isModelLoaded => _isModelLoaded;


  double _scale(double value, double min, double max) {
    if (max == min) return 0.0;
    return ((value - min) / (max - min)).clamp(0.0, 1.0);
  }


  /// Reference to Firebase Realtime Database
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref('floodData');

  /// Load the TFLite model from assets
  Future<void> loadModel() async {
    try {
      // ✅ Pure TFLite model, no FlexDelegate needed
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

  /// Fetch last 10 readings from Firebase and prepare input automatically
  Future<List<List<double>>> fetchLast10Readings() async {
    try {
      final snapshot = await _dbRef.orderByKey().limitToLast(10).get();

      if (!snapshot.exists) {
        throw Exception("No flood data available in Firebase");
      }

      // Convert Firebase data to List<List<double>> in order [water_level, rain_intensity, water_sensor]
      List<Map<String, dynamic>> sortedData = [];
      for (var child in snapshot.children) {
        final map = Map<String, dynamic>.from(child.value as Map);
        sortedData.add(map);
      }

      // Sort by timestamp if needed
      sortedData.sort((a, b) => a['timestamp'].compareTo(b['timestamp']));

      // Map to List<List<double>> [10,3] — SCALED (0–1)
      List<List<double>> last10 = sortedData.map((e) {
        final wl = _scale((e['water_level_cm'] as num).toDouble(), 0, 100);
        final rain = _scale((e['rain_intensity_percent'] as num).toDouble(), 0, 100);
        final water = _scale((e['water_sensor_percent'] as num).toDouble(), 0, 100);


        return [wl, rain, water];
      }).toList();

// 🔍 DEBUG — confirm scaling
      debugPrint("Scaled sample (last): ${last10.last}");

      if (last10.length != 10) {
        throw Exception("Insufficient data, expected 10 readings, got ${last10.length}");
      }

      return last10;
    } catch (e) {
      debugPrint("❌ Error fetching last 10 readings: $e");
      return List.generate(10, (_) => [0.0, 0.0, 0.0]);
    }
  }

  /// Predict future water level using last 10 readings from Firebase
  Future<double> predictFutureWaterLevel() async {
    if (!_isModelLoaded) {
      debugPrint("⚠ AI model not loaded, returning 0.0");
      return 0.0;
    }

    try {
      final last10Readings = await fetchLast10Readings();

      // Prepare 3D input for TFLite [1, 10, 3]
      final shapedInput = [last10Readings];

      // Output shape [1,1]
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

/// Extension to reshape List (2D)
extension ListReshape<T> on List<T> {
  List<List<T>> reshape(List<int> shape) {
    if (shape.length != 2) throw Exception("Only 2D reshape supported");
    int rows = shape[0];
    int cols = shape[1];
    if (rows * cols != length) throw Exception("Cannot reshape list of length $length to shape $shape");
    return List.generate(rows, (i) => List.generate(cols, (j) => this[i * cols + j]));
  }
}
