import 'package:firebase_database/firebase_database.dart';

/// Model-like map keys used by ESP32
/// {
///   timestamp: "2026-01-28 20:49:41",
///   motion: 0.027,
///   vibration_detected: 0,
///   earthquake_detected: 0,
///   risk_level: "Low"
/// }

class EarthquakeRealtimeService {
  /// Firebase node reference
  final DatabaseReference _ref =
  FirebaseDatabase.instance.ref("earthquakeData");

  /// --------------------------------------------------
  /// Stream live earthquake updates (real-time listener)
  /// --------------------------------------------------
  Stream<List<Map<String, dynamic>>> streamEarthquakeData() {
    return _ref.onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        return <Map<String, dynamic>>[];
      }

      final raw = Map<String, dynamic>.from(
        event.snapshot.value as Map,
      );

      final List<Map<String, dynamic>> result = [];

      raw.forEach((key, value) {
        if (value is Map) {
          final data = Map<String, dynamic>.from(value);
          result.add(_normalizeRecord(data, key));
        }
      });

      // newest first
      result.sort(
            (a, b) => b['timestamp_raw'].compareTo(a['timestamp_raw']),
      );

      return result;
    });
  }

  /// --------------------------------------------------
  /// Fetch once (no realtime listener)
  /// --------------------------------------------------
  Future<List<Map<String, dynamic>>> getEarthquakeOnce() async {
    final snapshot = await _ref.get();

    if (!snapshot.exists || snapshot.value == null) {
      return [];
    }

    final raw = Map<String, dynamic>.from(snapshot.value as Map);

    final List<Map<String, dynamic>> list = [];

    raw.forEach((key, value) {
      if (value is Map) {
        list.add(_normalizeRecord(Map<String, dynamic>.from(value), key));
      }
    });

    list.sort(
          (a, b) => b['timestamp_raw'].compareTo(a['timestamp_raw']),
    );

    return list;
  }

  /// --------------------------------------------------
  /// Convert Firebase raw entry → safe Dart map
  /// --------------------------------------------------
  Map<String, dynamic> _normalizeRecord(
      Map<String, dynamic> data,
      String id,
      ) {
    final String timestampStr = data['timestamp']?.toString() ?? '';

    DateTime parsedTime;
    try {
      parsedTime = DateTime.parse(timestampStr);
    } catch (_) {
      parsedTime = DateTime.now();
    }

    return {
      "id": id,
      "timestamp": timestampStr,
      "timestamp_raw": parsedTime,

      "motion": _toDouble(data['motion']),

      "vibration_detected": _toInt(data['vibration_detected']),
      "earthquake_detected": _toInt(data['earthquake_detected']),

      "risk_level": data['risk_level']?.toString() ?? "Unknown",
    };
  }

  /// ------------------------------
  /// Safe converters
  /// ------------------------------
  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }
}
