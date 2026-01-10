import 'package:firebase_database/firebase_database.dart';

/// Model-like map keys used by ESP32
/// {
///   timestamp: "2025-12-28 00:06:27",
///   temperature: 23.4,
///   humidity: 73.7,
///   gas_value: 4095,
///   flame_detected: 0,
///   wildfire_detected: 1,
///   risk_level: "High"
/// }

class WildfireRealtimeService {
  /// Firebase node reference
  final DatabaseReference _ref =
  FirebaseDatabase.instance.ref("wildfireData");

  /// --------------------------------------------------
  /// Stream live wildfire updates (real-time listener)
  /// --------------------------------------------------
  Stream<List<Map<String, dynamic>>> streamWildfireData() {
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
      result.sort((a, b) =>
          b['timestamp_raw'].compareTo(a['timestamp_raw']));

      return result;
    });
  }

  /// --------------------------------------------------
  /// Fetch once (no realtime listener)
  /// --------------------------------------------------
  Future<List<Map<String, dynamic>>> getWildfireOnce() async {
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

      "temperature": _toDouble(data['temperature']),
      "humidity": _toDouble(data['humidity']),
      "gas_value": _toInt(data['gas_value']),

      "flame_detected": _toInt(data['flame_detected']),

      "wildfire_detected": _toInt(data['wildfire_detected']),

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
