import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// ------------------------------------------------------------
/// Storm AI Service (Fusion Event Classification)
///
/// Model: CNN1D + GRU (TFLite)
/// Input:  [1, 10, 4]  -> 10 timesteps, 4 features
/// Output: [1, num_classes] -> fused_event class probabilities
///
/// Reads Firebase:
///   fusionData (push IDs)
///     wind_speed_mps
///     rain_percent
///     water_percent
///     distance_cm
///     fused_event (label exists in dataset but not needed at runtime)
/// ------------------------------------------------------------
class StormAIService {
  late Interpreter _interpreter;
  bool _isModelLoaded = false;

  bool get isModelLoaded => _isModelLoaded;

  final DatabaseReference _fusionRef =
  FirebaseDatabase.instance.ref('fusionData');

  // ===== From your storm_model_meta.json =====
  // feature order must match training
  // :contentReference[oaicite:1]{index=1}
  static const List<String> _features = [
    "wind_speed_mps",
    "rain_percent",
    "water_percent",
    "distance_cm",
  ];

  // MinMaxScaler uses: scaled = x * scale_ + min_
  // :contentReference[oaicite:2]{index=2}
  static const List<double> _scalerMin = [
    0.0,
    0.0,
    0.0,
    -0.025641025641025644,
  ];

  static const List<double> _scalerScale = [
    0.03125976867771179,
    0.01,
    0.01,
    0.008547008547008548,
  ];

  static const List<String> _classNames = [
    "Cyclone+Flood",
    "CycloneOnly",
    "FloodLikely",
    "Normal",
    "StormOnly",
  ];

  static const int _sequenceLength = 10;

  // Optional: you can also load meta from asset JSON (safe).
  // If asset loading fails, it will still use the constants above.
  bool _metaLoadedFromAsset = false;

  // ------------------------------------------------------------
  // Load TFLite model
  // ------------------------------------------------------------
  Future<void> loadModel() async {
    try {
      // Load meta (optional but good practice)
      await _tryLoadMetaFromAsset();

      final options = InterpreterOptions()..threads = 2;

      _interpreter = await Interpreter.fromAsset(
        'assets/models/storm_fusion_event_model.tflite',
        options: options,
      );

      _isModelLoaded = true;
      debugPrint("✅ Storm AI model loaded");
    } catch (e) {
      _isModelLoaded = false;
      debugPrint("❌ Failed to load Storm model: $e");
    }
  }

  Future<void> _tryLoadMetaFromAsset() async {
    try {
      final raw = await rootBundle.loadString('assets/models/storm_model_meta.json');
      final m = jsonDecode(raw);

      // We keep constants anyway, but this confirms asset is correct.
      final seq = (m["sequence_length"] as num?)?.toInt() ?? _sequenceLength;
      final classes = (m["class_names"] is List) ? (m["class_names"] as List).length : _classNames.length;

      debugPrint("✅ Storm meta loaded from asset (seq=$seq, classes=$classes)");
      _metaLoadedFromAsset = true;
    } catch (_) {
      _metaLoadedFromAsset = false;
      debugPrint("ℹ️ Storm meta asset not loaded, using built-in constants");
    }
  }

  // ------------------------------------------------------------
  // Fetch last 10 fusion records from Firebase
  // Builds window [[wind, rain, water, dist] x 10]
  // ------------------------------------------------------------
  Future<List<List<double>>> fetchLast10FusionWindow() async {
    try {
      final snap = await _fusionRef.orderByKey().limitToLast(_sequenceLength).get();
      if (!snap.exists) throw Exception("No fusionData found");

      final List<Map<String, dynamic>> rows = [];

      for (final child in snap.children) {
        final v = child.value;
        if (v == null || v is! Map) continue;
        rows.add(Map<String, dynamic>.from(v));
      }

      // Sort by timestamp if possible (your timestamps are "YYYY-MM-DD HH:mm:ss")
      rows.sort((a, b) {
        final ta = _parseTs(a["timestamp"]?.toString());
        final tb = _parseTs(b["timestamp"]?.toString());
        return ta.compareTo(tb);
      });

      // Ensure exactly last 10
      final last = rows.length > _sequenceLength
          ? rows.sublist(rows.length - _sequenceLength)
          : rows;

      final window = last.map((r) {
        final wind = _toDouble(r["wind_speed_mps"]);
        final rain = _toDouble(r["rain_percent"]);
        final water = _toDouble(r["water_percent"]);
        final dist = _toDouble(r["distance_cm"]);

        // MUST match training feature order
        return [wind, rain, water, dist];
      }).toList(growable: false);

      if (window.length < _sequenceLength) {
        debugPrint("⚠️ Not enough fusion records yet (${window.length}/$_sequenceLength)");
      }

      return window;
    } catch (e) {
      debugPrint("❌ Error fetching fusion window: $e");
      // Return safe default window (all zeros)
      return List.generate(_sequenceLength, (_) => [0.0, 0.0, 0.0, 0.0]);
    }
  }

  // ------------------------------------------------------------
  // Scale one row using MinMaxScaler params
  // scaled = x * scale_ + min_
  // ------------------------------------------------------------
  List<double> _scaleRow(List<double> row) {
    if (row.length != 4) return [0, 0, 0, 0];

    final out = <double>[];
    for (int i = 0; i < 4; i++) {
      final s = row[i] * _scalerScale[i] + _scalerMin[i];
      out.add(s.clamp(0.0, 1.0));
    }
    return out;
  }

  // ------------------------------------------------------------
  // Predict from Firebase last-10 (easy mode)
  // Returns: {"event": "...", "confidence": 0.92, "index": 3}
  // ------------------------------------------------------------
  Future<Map<String, dynamic>?> predictFromFirebaseWindow() async {
    final window = await fetchLast10FusionWindow();
    if (window.length < _sequenceLength) return null;
    return predictEventFromWindow(window);
  }

  // ------------------------------------------------------------
  // Predict from a window YOU already built in StormPage
  // window shape: [10][4] (wind,rain,water,dist)
  // ------------------------------------------------------------
  Future<Map<String, dynamic>?> predictEventFromWindow(
      List<List<double>> window,
      ) async {
    if (!_isModelLoaded) {
      debugPrint("⚠️ Storm model not loaded");
      return null;
    }

    try {
      if (window.length != _sequenceLength) {
        debugPrint("⚠️ Window must be exactly $_sequenceLength rows");
        return null;
      }

      // scale each row
      final scaledWindow = window.map(_scaleRow).toList(growable: false);

      // input shape: [1, 10, 4]
      final input = [scaledWindow];

      // output shape: [1, num_classes]
      final output = List.filled(_classNames.length, 0.0).reshape2D([1, _classNames.length]);

      _interpreter.run(input, output);

      final probs = output[0];

      int bestIdx = 0;
      double best = probs[0];
      for (int i = 1; i < probs.length; i++) {
        if (probs[i] > best) {
          best = probs[i];
          bestIdx = i;
        }
      }

      final event = _classNames[bestIdx];
      final confidence = best;

      debugPrint("🌪️ Storm AI => event=$event  conf=${(confidence * 100).toStringAsFixed(1)}%"
          "  (metaLoaded=$_metaLoadedFromAsset)");

      // Optional: print all probs
      for (int i = 0; i < probs.length; i++) {
        debugPrint("   • ${_classNames[i]}: ${probs[i].toStringAsFixed(3)}");
      }

      return {
        "event": event,
        "confidence": confidence,
        "index": bestIdx,
      };
    } catch (e) {
      debugPrint("❌ Storm inference error: $e");
      return null;
    }
  }

  void close() {
    if (_isModelLoaded) {
      _interpreter.close();
    }
    _isModelLoaded = false;
  }

  // ------------------------------------------------------------
  // Helpers
  // ------------------------------------------------------------
  DateTime _parseTs(String? ts) {
    if (ts == null || ts.isEmpty) return DateTime.now();
    try {
      final fixed = ts.contains(' ') ? ts.replaceFirst(' ', 'T') : ts;
      return DateTime.parse(fixed);
    } catch (_) {
      return DateTime.now();
    }
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
}

/// Helper reshape extension (2D)
extension ListReshape2D<T> on List<T> {
  List<List<T>> reshape2D(List<int> shape) {
    if (shape.length != 2) throw Exception("Only 2D reshape supported");

    final rows = shape[0];
    final cols = shape[1];

    if (rows * cols != length) {
      throw Exception("Cannot reshape list of length $length to $shape");
    }

    return List.generate(
      rows,
          (i) => List.generate(cols, (j) => this[i * cols + j]),
    );
  }
}