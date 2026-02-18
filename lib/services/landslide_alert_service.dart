import 'package:firebase_database/firebase_database.dart';

class LandslideAlertService {
  final DatabaseReference _alertsRef =
  FirebaseDatabase.instance.ref("landslideAlerts");

  /// --------------------------------------------------
  /// Push Landslide Alert
  /// --------------------------------------------------
  Future<void> pushLandslideAlert({
    required String riskLevel,
    required double soilMoisture,
    required double pressure,
    required bool landslideDetected,
  }) async {
    await _alertsRef.push().set({
      "risk_level": riskLevel, // Low / Medium / High / Critical
      "soil_moisture": soilMoisture,
      "pressure": pressure,
      "landslide_detected": landslideDetected ? 1 : 0,

      // Standardized timestamp
      "timestamp": DateTime.now().toIso8601String(),
      "timestamp_ms": ServerValue.timestamp,
    });
  }
}
