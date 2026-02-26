import 'dart:async';
import 'package:firebase_database/firebase_database.dart';

/// Firebase structure (push IDs):
/// stormData
///   -xxxx
///     timestamp: "2026-02-26 16:15:27"
///     wind_speed_mps: 0
///     cyclone_detected: 0
///     risk_level: "Normal"
///
/// fusionData
///   -xxxx
///     timestamp: "2026-02-26 16:15:29"
///     wind_speed_mps: 0
///     storm_risk: "Normal"
///     flood_risk: "Low"
///     rain_percent: 0
///     water_percent: 0
///     distance_cm: 0
///     fused_event: "Normal"
///     fused_risk: "Normal"

class StormRealtimeService {
  final DatabaseReference _stormRef =
  FirebaseDatabase.instance.ref("stormData");

  final DatabaseReference _fusionRef =
  FirebaseDatabase.instance.ref("fusionData");

  // --------------------------------------------------
  // ✅ 1) Stream only latest storm reading
  // --------------------------------------------------
  Stream<Map<String, dynamic>?> streamStormLatest() {
    final q = _stormRef.orderByKey().limitToLast(1);

    return q.onChildAdded.map((event) {
      final v = event.snapshot.value;
      if (v == null || v is! Map) return null;

      final data = Map<String, dynamic>.from(v);
      return _normalizeStormRecord(data, event.snapshot.key ?? "");
    });
  }

  // --------------------------------------------------
  // ✅ 2) Stream only latest fusion reading
  // --------------------------------------------------
  Stream<Map<String, dynamic>?> streamFusionLatest() {
    final q = _fusionRef.orderByKey().limitToLast(1);

    return q.onChildAdded.map((event) {
      final v = event.snapshot.value;
      if (v == null || v is! Map) return null;

      final data = Map<String, dynamic>.from(v);
      return _normalizeFusionRecord(data, event.snapshot.key ?? "");
    });
  }

  // --------------------------------------------------
  // ✅ 3) Stream rolling last 10 fusion records (AI input)
  // --------------------------------------------------
  Stream<List<Map<String, dynamic>>> streamFusionLast10Window() {
    final q = _fusionRef.orderByKey().limitToLast(10);

    final controller =
    StreamController<List<Map<String, dynamic>>>.broadcast();

    final Map<String, Map<String, dynamic>> buffer = {};

    void emitSorted() {
      final list = buffer.values.toList()
        ..sort((a, b) =>
            (a['timestamp_raw'] as DateTime)
                .compareTo(b['timestamp_raw'] as DateTime));
      controller.add(list);
    }

    late final StreamSubscription<DatabaseEvent> subAdd;
    late final StreamSubscription<DatabaseEvent> subChange;
    late final StreamSubscription<DatabaseEvent> subRemove;

    subAdd = q.onChildAdded.listen((event) {
      final v = event.snapshot.value;
      if (v == null || v is! Map) return;

      final key = event.snapshot.key ?? "";
      final data = Map<String, dynamic>.from(v);

      buffer[key] = _normalizeFusionRecord(data, key);
      emitSorted();
    });

    subChange = q.onChildChanged.listen((event) {
      final v = event.snapshot.value;
      if (v == null || v is! Map) return;

      final key = event.snapshot.key ?? "";
      final data = Map<String, dynamic>.from(v);

      buffer[key] = _normalizeFusionRecord(data, key);
      emitSorted();
    });

    subRemove = q.onChildRemoved.listen((event) {
      final key = event.snapshot.key ?? "";
      buffer.remove(key);
      emitSorted();
    });

    controller.onCancel = () async {
      await subAdd.cancel();
      await subChange.cancel();
      await subRemove.cancel();
      await controller.close();
    };

    return controller.stream;
  }

  // --------------------------------------------------
  // Normalize records
  // --------------------------------------------------
  Map<String, dynamic> _normalizeStormRecord(
      Map<String, dynamic> data,
      String id,
      ) {
    final ts = data['timestamp']?.toString() ?? '';
    final parsed = _parseTimestamp(ts);

    return {
      "id": id,
      "timestamp": ts,
      "timestamp_raw": parsed,

      "wind_speed_mps": _toDouble(data['wind_speed_mps']),
      "cyclone_detected": _toInt(data['cyclone_detected']),
      "risk_level": data['risk_level']?.toString() ?? "Unknown",
    };
  }

  Map<String, dynamic> _normalizeFusionRecord(
      Map<String, dynamic> data,
      String id,
      ) {
    final ts = data['timestamp']?.toString() ?? '';
    final parsed = _parseTimestamp(ts);

    return {
      "id": id,
      "timestamp": ts,
      "timestamp_raw": parsed,

      "wind_speed_mps": _toDouble(data['wind_speed_mps']),
      "storm_risk": data['storm_risk']?.toString() ?? "Unknown",

      "flood_risk": data['flood_risk']?.toString() ?? "Unknown",
      "rain_percent": _toInt(data['rain_percent']),
      "water_percent": _toInt(data['water_percent']),
      "distance_cm": _toDouble(data['distance_cm']),

      "fused_event": data['fused_event']?.toString() ?? "Unknown",
      "fused_risk": data['fused_risk']?.toString() ?? "Unknown",
    };
  }

  DateTime _parseTimestamp(String ts) {
    try {
      final fixed = ts.contains(' ') ? ts.replaceFirst(' ', 'T') : ts;
      return DateTime.parse(fixed);
    } catch (_) {
      return DateTime.now();
    }
  }

  // --------------------------------------------------
  // Safe converters
  // --------------------------------------------------
  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }
}