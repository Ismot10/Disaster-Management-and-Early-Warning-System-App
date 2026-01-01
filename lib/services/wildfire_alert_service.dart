import 'package:firebase_database/firebase_database.dart';

class WildfireAlertService {
  final DatabaseReference _ref =
  FirebaseDatabase.instance.ref("wildfireAlerts");

  Future<void> pushAlert({
    required String level,
    required String message,
  }) async {
    await _ref.push().set({
      "type": "Wildfire",
      "level": level,
      "message": message,
      "timestamp": DateTime.now().toIso8601String(),
    });
  }
}
