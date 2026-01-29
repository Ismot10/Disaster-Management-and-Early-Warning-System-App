import 'dart:async';
import 'package:firebase_database/firebase_database.dart';

/// Firebase structure (push IDs):
/// earthquakeData
///   -Ok7iCL33pE9s_ezc6zj
///     timestamp: "2026-01-29 13:47:35"
///     motion: 0.005
///     vibration_detected: 0
///     earthquake_detected: 0
///     risk_level: "Low"
class EarthquakeRealtimeService {
  final DatabaseReference _ref =
  FirebaseDatabase.instance.ref("earthquakeData");

  // --------------------------------------------------
  // ✅ 1) Stream only the latest record (VERY LIGHT)
  //     Best for: UI banner, live sensor display
  // --------------------------------------------------
  Stream<Map<String, dynamic>?> streamLatestReading() {
    final q = _ref.orderByKey().limitToLast(1);

    // onChildAdded will fire once for the latest existing
    // and again whenever a new child is added.
    return q.onChildAdded.map((event) {
      final v = event.snapshot.value;
      if (v == null || v is! Map) return null;

      final data = Map<String, dynamic>.from(v);
      return _normalizeRecord(data, event.snapshot.key ?? "");
    });
  }

  // --------------------------------------------------
  // ✅ 2) Stream rolling window of last 15 records
  //     Best for: AI input (15-step window)
  //
  // Why this design:
  // - Uses onChildAdded/Changed/Removed so it does NOT
  //   re-download your entire database on every update.
  // - Maintains a local buffer and emits sorted window.
  // --------------------------------------------------
  Stream<List<Map<String, dynamic>>> streamLast15Window() {
    final q = _ref.orderByKey().limitToLast(15);

    final controller =
    StreamController<List<Map<String, dynamic>>>.broadcast();

    // key -> normalized record
    final Map<String, Map<String, dynamic>> buffer = {};

    void emitSorted() {
      final list = buffer.values.toList()
        ..sort((a, b) =>
            (a['timestamp_raw'] as DateTime).compareTo(b['timestamp_raw'] as DateTime));
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

      buffer[key] = _normalizeRecord(data, key);
      emitSorted();
    });

    subChange = q.onChildChanged.listen((event) {
      final v = event.snapshot.value;
      if (v == null || v is! Map) return;

      final key = event.snapshot.key ?? "";
      final data = Map<String, dynamic>.from(v);

      buffer[key] = _normalizeRecord(data, key);
      emitSorted();
    });

    subRemove = q.onChildRemoved.listen((event) {
      final key = event.snapshot.key ?? "";
      buffer.remove(key);
      emitSorted();
    });

    // Clean up when no listeners remain
    controller.onCancel = () async {
      await subAdd.cancel();
      await subChange.cancel();
      await subRemove.cancel();
      await controller.close();
    };

    return controller.stream;
  }

  // --------------------------------------------------
  // Normalize raw firebase map -> safe record
  // --------------------------------------------------
  Map<String, dynamic> _normalizeRecord(
      Map<String, dynamic> data,
      String id,
      ) {
    final String ts = data['timestamp']?.toString() ?? '';

    DateTime parsed;
    // Your timestamp format is "2026-01-29 13:47:35"
    // DateTime.parse expects "2026-01-29T13:47:35"
    // So we patch it.
    try {
      final fixed = ts.contains(' ') ? ts.replaceFirst(' ', 'T') : ts;
      parsed = DateTime.parse(fixed);
    } catch (_) {
      parsed = DateTime.now();
    }

    return {
      "id": id,
      "timestamp": ts,
      "timestamp_raw": parsed,

      "motion": _toDouble(data['motion']),
      "vibration_detected": _toInt(data['vibration_detected']),
      "earthquake_detected": _toInt(data['earthquake_detected']),
      "risk_level": data['risk_level']?.toString() ?? "Unknown",
    };
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
