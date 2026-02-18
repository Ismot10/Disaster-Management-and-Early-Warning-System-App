import 'dart:async';
import 'package:firebase_database/firebase_database.dart';

/// Firebase structure (push IDs):
/// landslideData
///   -OlkPzc9i__Vr5bMeoCE
///     timestamp: "2026-02-18 17:04:08"
///     soil_moisture: 2416
///     pressure: 429
///     landslide_detected: 0
///     risk_level: "Low"

class LandslideRealtimeService {
  final DatabaseReference _ref =
  FirebaseDatabase.instance.ref("landslideData");

  // --------------------------------------------------
  // ✅ 1) Stream only latest reading (LIGHTWEIGHT)
  // --------------------------------------------------
  Stream<Map<String, dynamic>?> streamLatestReading() {
    final q = _ref.orderByKey().limitToLast(1);

    return q.onChildAdded.map((event) {
      final v = event.snapshot.value;
      if (v == null || v is! Map) return null;

      final data = Map<String, dynamic>.from(v);
      return _normalizeRecord(data, event.snapshot.key ?? "");
    });
  }

  // --------------------------------------------------
  // ✅ 2) Stream rolling last 15 records (AI input)
  // --------------------------------------------------
  Stream<List<Map<String, dynamic>>> streamLast15Window() {
    final q = _ref.orderByKey().limitToLast(15);

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

    controller.onCancel = () async {
      await subAdd.cancel();
      await subChange.cancel();
      await subRemove.cancel();
      await controller.close();
    };

    return controller.stream;
  }

  // --------------------------------------------------
  // Normalize Firebase record
  // --------------------------------------------------
  Map<String, dynamic> _normalizeRecord(
      Map<String, dynamic> data,
      String id,
      ) {
    final String ts = data['timestamp']?.toString() ?? '';

    DateTime parsed;
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

      "soil_moisture": _toDouble(data['soil_moisture']),
      "pressure": _toDouble(data['pressure']),
      "landslide_detected": _toInt(data['landslide_detected']),
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
