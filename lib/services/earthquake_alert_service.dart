import 'package:firebase_database/firebase_database.dart';

class EarthquakeAlertService {
  final DatabaseReference _alertsRef =
  FirebaseDatabase.instance.ref("earthquakeAlerts");

  Future<void> pushEarthquakeAlert({
    required String riskLevel,
    required double motion,
    required bool vibrationDetected,
    required bool earthquakeDetected,
  }) async {
    await _alertsRef.push().set({
      "risk_level": riskLevel, // Low / Medium / High / Critical
      "motion": motion,
      "vibration_detected": vibrationDetected ? 1 : 0,
      "earthquake_detected": earthquakeDetected ? 1 : 0,

      // Use a consistent parseable timestamp
      "timestamp": DateTime.now().toIso8601String(),
      "timestamp_ms": ServerValue.timestamp,
    });
  }
}
