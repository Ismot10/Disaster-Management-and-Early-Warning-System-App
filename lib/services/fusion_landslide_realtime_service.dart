import 'dart:async';
import 'package:firebase_database/firebase_database.dart';

class FusionLandslideRealtimeService {
  final DatabaseReference _ref =
  FirebaseDatabase.instance.ref("fusion/landslide/current");

  Stream<Map<String, dynamic>?> streamCurrent() {
    final controller = StreamController<Map<String, dynamic>?>.broadcast();

    late final StreamSubscription<DatabaseEvent> sub;
    sub = _ref.onValue.listen((event) {
      final v = event.snapshot.value;
      if (v == null || v is! Map) {
        controller.add(null);
        return;
      }
      controller.add(Map<String, dynamic>.from(v));
    });

    controller.onCancel = () async {
      await sub.cancel();
      await controller.close();
    };

    return controller.stream;
  }
}