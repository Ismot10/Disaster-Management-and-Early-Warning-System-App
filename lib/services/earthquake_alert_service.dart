import 'package:firebase_database/firebase_database.dart';

class EarthquakeAlertService {
  final DatabaseReference _ref =
  FirebaseDatabase.instance.ref("earthquakeData");

  Future<void> pushEarthquakeAlert({
    required String riskLevel,
    required double motion,
    required bool vibrationDetected,
    required bool earthquakeDetected,
  }) async {
    await _ref.push().set({
      "risk_level": riskLevel,                // Low / Medium / High / Critical
      "motion": motion,                       // ground motion (g)
      "vibration_detected": vibrationDetected ? 1 : 0,
      "earthquake_detected": earthquakeDetected ? 1 : 0,
      "timestamp": DateTime.now().toString(), // same format as ESP32
    });
  }
}
