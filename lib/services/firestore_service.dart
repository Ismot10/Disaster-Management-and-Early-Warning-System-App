import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- USERS ---
  Future<DocumentReference> addUser({
    required String name,
    required String email,
    String? location,
    List<String>? savedLocations,
  }) {
    final data = {
      'name': name,
      'email': email,
      'location': location ?? '',
      'savedLocations': savedLocations ?? <String>[],
      'createdAt': FieldValue.serverTimestamp(),
    };
    return _db.collection('users').add(data);
  }

  Future<void> setUser(String userId, Map<String, dynamic> data) {
    data['updatedAt'] = FieldValue.serverTimestamp();
    return _db
        .collection('users')
        .doc(userId)
        .set(data, SetOptions(merge: true));
  }

  // --- SENSORS ---
  Future<DocumentReference> addSensor({
    required String type,
    required String location,
    required double lastReading,
  }) {
    final data = {
      'type': type,
      'location': location,
      'lastReading': lastReading,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    return _db.collection('sensors').add(data);
  }

  Future<void> updateSensorReading(String sensorId, double reading) {
    return _db.collection('sensors').doc(sensorId).update({
      'lastReading': reading,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // --- ALERTS ---
  Future<DocumentReference> addAlert({
    required String type,
    required String level,
    required String location,
    required String message,
    String? sensorId,
  }) {
    final data = {
      'type': type,
      'level': level,
      'location': location,
      'message': message,
      'sensorId': sensorId ?? '',
      'timestamp': FieldValue.serverTimestamp(),
    };
    return _db.collection('alerts').add(data);
  }

  // 🔹 Stream alerts by type
  Stream<QuerySnapshot<Map<String, dynamic>>> getAlerts(String type) {
    return _db
        .collection("alerts")
        .where("type", isEqualTo: type)
        .orderBy("timestamp", descending: true)
        .snapshots();
  }

  // 🔹 Stream all alerts (optional)
  Stream<QuerySnapshot<Map<String, dynamic>>> alertsStream() {
    return _db
        .collection("alerts")
        .orderBy("timestamp", descending: true)
        .snapshots();
  }

  // 🔹 Stream sensors (optional)
  Stream<QuerySnapshot<Map<String, dynamic>>> sensorsStream() {
    return _db
        .collection('sensors')
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }
}
