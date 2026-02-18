import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:firebase_database/firebase_database.dart';

class LandslideAIService {
  late Interpreter _interpreter;
  bool _isModelLoaded = false;

  bool get isModelLoaded => _isModelLoaded;

  final DatabaseReference _dbRef =
  FirebaseDatabase.instance.ref('landslideData');

  /// --------------------------------
  /// IMPORTANT:
  /// These min/max values MUST match
  /// your training dataset ranges.
  /// Replace with real values if needed.
  /// --------------------------------
  static const double soilMin = 0;
  static const double soilMax = 4000;

  static const double pressureMin = 300;
  static const double pressureMax = 500;

  double _scale(double value, double min, double max) {
    if (max == min) return 0.0;
    return ((value - min) / (max - min)).clamp(0.0, 1.0);
  }

  /// --------------------------------
  /// Load TFLite model
  /// --------------------------------
  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/models/landslide_detection_model.tflite',
      );

      _isModelLoaded = true;
      debugPrint("✅ Landslide AI model loaded");
    } catch (e) {
      _isModelLoaded = false;
      debugPrint("❌ Failed to load landslide model: $e");
    }
  }

  /// --------------------------------
  /// Fetch latest reading
  /// --------------------------------
  Future<List<double>> fetchLatestReading() async {
    try {
      final snapshot =
      await _dbRef.orderByKey().limitToLast(1).get();

      if (!snapshot.exists) {
        throw Exception("No landslide data found");
      }

      final child = snapshot.children.first;
      final map = Map<String, dynamic>.from(child.value as Map);

      final soil =
      _scale((map['soil_moisture'] as num).toDouble(), soilMin, soilMax);

      final pressure =
      _scale((map['pressure'] as num).toDouble(), pressureMin, pressureMax);

      debugPrint("🌧 Landslide input (scaled): Soil=$soil Pressure=$pressure");

      return [pressure, soil];  // ORDER MUST MATCH TRAINING
    } catch (e) {
      debugPrint("❌ Error fetching landslide data: $e");
      return [0.0, 0.0];
    }
  }

  /// --------------------------------
  /// Predict Landslide Risk
  /// 0 → Low
  /// 1 → Medium
  /// 2 → High
  /// --------------------------------
  Future<int> predictLandslideRisk() async {
    if (!_isModelLoaded) {
      debugPrint("⚠️ Model not loaded");
      return 0;
    }

    try {
      final inputData = await fetchLatestReading();

      // Input shape: [1, 2]
      final input = [inputData];

      // Output shape: [1, 3]
      final output = List.filled(3, 0.0).reshape([1, 3]);

      _interpreter.run(input, output);

      final probabilities = output[0];

      final predictedClass =
      probabilities.indexOf(probabilities.reduce((a, b) => a > b ? a : b));

      debugPrint(
          "🌧 Landslide probs → Low:${probabilities[0].toStringAsFixed(2)} "
              "Medium:${probabilities[1].toStringAsFixed(2)} "
              "High:${probabilities[2].toStringAsFixed(2)}");

      return predictedClass;
    } catch (e) {
      debugPrint("❌ Inference error: $e");
      return 0;
    }
  }

  void close() {
    _interpreter.close();
  }
}

/// Helper reshape extension
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
