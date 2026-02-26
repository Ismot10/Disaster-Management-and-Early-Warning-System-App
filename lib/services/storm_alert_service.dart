import 'package:firebase_database/firebase_database.dart';

/// Writes alerts into Realtime Database:
/// stormAlerts
/// stormFusionAlerts
///
/// You can listen to these in Flutter later if you want.
class StormAlertService {
  final DatabaseReference _stormAlertsRef =
  FirebaseDatabase.instance.ref("stormAlerts");

  final DatabaseReference _stormFusionAlertsRef =
  FirebaseDatabase.instance.ref("stormFusionAlerts");

  /// --------------------------------------------------
  /// ✅ Push Storm Alert (only storm node info)
  /// --------------------------------------------------
  Future<void> pushStormAlert({
    required String riskLevel, // Normal / Storm / Cyclone
    required double windSpeedMps,
    required bool cycloneDetected,
  }) async {
    await _stormAlertsRef.push().set({
      "risk_level": riskLevel,
      "wind_speed_mps": windSpeedMps,
      "cyclone_detected": cycloneDetected ? 1 : 0,

      // Standardized timestamps
      "timestamp": DateTime.now().toIso8601String(),
      "timestamp_ms": ServerValue.timestamp,
    });
  }

  /// --------------------------------------------------
  /// ✅ Push Storm + Fusion Alert (fusionData + storm risk)
  /// --------------------------------------------------
  Future<void> pushStormFusionAlert({
    required String fusedEvent, // Normal / Cyclone+Flood / FloodLikely / ...
    required String fusedRisk,  // Normal / Storm / Cyclone / HighRisk / Extreme
    required double wind,
    required int rainPercent,
    required int waterPercent,
    required double distanceCm,
    required String stormRisk,  // Normal / Storm / Cyclone
    required String floodRisk,  // Low / Medium / High / Critical
  }) async {
    await _stormFusionAlertsRef.push().set({
      // Fusion outputs
      "fused_event": fusedEvent,
      "fused_risk": fusedRisk,

      // Inputs used for fusion / AI
      "wind_speed_mps": wind,
      "rain_percent": rainPercent,
      "water_percent": waterPercent,
      "distance_cm": distanceCm,

      // Extra labels
      "storm_risk": stormRisk,
      "flood_risk": floodRisk,

      // Standardized timestamps
      "timestamp": DateTime.now().toIso8601String(),
      "timestamp_ms": ServerValue.timestamp,
    });
  }
}