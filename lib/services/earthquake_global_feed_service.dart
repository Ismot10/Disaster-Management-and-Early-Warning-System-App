import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class EarthquakeGlobalFeedService {
  Timer? _timer;
  String? _lastEventId;

  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get stream => _controller.stream;

  static const String _url =
      "https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_hour.geojson";

  void start({Duration interval = const Duration(seconds: 30)}) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => _poll());
    _poll(); // immediate
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _poll() async {
    try {
      final res = await http.get(Uri.parse(_url));
      if (res.statusCode != 200) return;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final features = (data['features'] as List).cast<Map<String, dynamic>>();
      if (features.isEmpty) return;

      final latest = features.first;
      final id = latest['id']?.toString();
      if (id == null) return;

      // First run: set baseline (avoid spamming old quakes)
      if (_lastEventId == null) {
        _lastEventId = id;
        return;
      }

      if (id == _lastEventId) return;
      _lastEventId = id;

      final props = (latest['properties'] as Map).cast<String, dynamic>();
      final geom = (latest['geometry'] as Map).cast<String, dynamic>();
      final coords = (geom['coordinates'] as List).cast<num>(); // [lon, lat, depth]

      final lon = coords[0].toDouble();
      final lat = coords[1].toDouble();
      final depthKm = coords.length > 2 ? coords[2].toDouble() : 0.0;

      _controller.add({
        "source": "USGS",
        "eventId": id,
        "mag": (props['mag'] as num?)?.toDouble() ?? 0.0,
        "place": props['place']?.toString() ?? "Unknown",
        "time": DateTime.fromMillisecondsSinceEpoch(
          (props['time'] as num?)?.toInt() ??
              DateTime.now().millisecondsSinceEpoch,
          isUtc: true,
        ).toLocal(),
        "coords": LatLng(lat, lon),
        "depthKm": depthKm,
        "url": props['url']?.toString(),
      });
    } catch (_) {
      // ignore errors (feed must not crash UI)
    }
  }

  void dispose() {
    stop();
    _controller.close();
  }
}
