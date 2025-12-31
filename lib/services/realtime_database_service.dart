import 'package:firebase_database/firebase_database.dart';

class RealtimeDatabaseService {
  /// Singleton instance
  static final RealtimeDatabaseService _instance =
  RealtimeDatabaseService._internal();

  factory RealtimeDatabaseService() => _instance;

  RealtimeDatabaseService._internal();

  /// Firebase Realtime Database reference
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  /// -----------------------------
  /// Push a new alert to /alerts
  /// -----------------------------
  Future<void> pushAlert({
    required String disasterType,
    required String severity,
    required String title,
    required String message,
    required double predictedDistance,
    required int predictedMinutes,
    required String location,
    String source = "flutter_ai",
    bool sendEmail = true,
  }) async {
    try {
      final alertRef = _db.child("alerts").push(); // Auto-ID
      await alertRef.set({
        "disaster_type": disasterType,
        "severity": severity,
        "title": title,
        "message": message,
        "predicted_distance": predictedDistance,
        "predicted_minutes": predictedMinutes,
        "location": location,
        "source": source,
        "send_email": sendEmail,
        "timestamp": DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // optional: log or handle error
      print("RealtimeDatabaseService: pushAlert error: $e");
    }
  }

  /// -----------------------------
  /// Stream all alerts (optional)
  /// -----------------------------
  Stream<DatabaseEvent> alertsStream() {
    return _db.child("alerts").onValue;
  }

  /// -----------------------------
  /// Fetch all alerts once
  /// -----------------------------
  Future<Map<String, dynamic>> getAlertsOnce() async {
    final snapshot = await _db.child("alerts").get();
    if (snapshot.exists && snapshot.value is Map) {
      return Map<String, dynamic>.from(snapshot.value as Map);
    } else {
      return {};
    }
  }

  /// -----------------------------
  /// Delete an alert by its ID
  /// -----------------------------
  Future<void> deleteAlert(String alertId) async {
    await _db.child("alerts/$alertId").remove();
  }
}
