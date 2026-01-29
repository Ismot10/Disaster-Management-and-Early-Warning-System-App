import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class EarthquakeGlobalFeedService {
  Timer? _timer;

  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get stream => _controller.stream;

  // ✅ More active feed (shows real activity)
  static const String _url =
      "https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_day.geojson";

  // ✅ Track what we've already emitted (prevents duplicates across polls)
  final Set<String> _seenEventIds = <String>{};

  // Optional: avoid flooding UI on first run
  bool _initialized = false;

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

      // USGS usually returns newest first
      // We'll emit "new" events we haven't seen yet.
      int emitted = 0;

      for (final f in features) {
        final id = f['id']?.toString();
        if (id == null || id.isEmpty) continue;

        // If already seen, skip
        if (_seenEventIds.contains(id)) continue;

        // On very first run, we don't want to dump 100+ old quakes.
        // So we "learn" the current feed and only start emitting from next poll.
        if (!_initialized) {
          _seenEventIds.add(id);
          continue;
        }

        final props = (f['properties'] as Map).cast<String, dynamic>();
        final geom = (f['geometry'] as Map).cast<String, dynamic>();
        final coords = (geom['coordinates'] as List).cast<num>(); // [lon, lat, depth]

        final lon = coords[0].toDouble();
        final lat = coords[1].toDouble();
        final depthKm = coords.length > 2 ? coords[2].toDouble() : 0.0;

        final event = {
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
        };

        _seenEventIds.add(id);
        _controller.add(event);
        emitted++;

        // ✅ Safety: don't flood UI if many events arrived at once
        if (emitted >= 10) break;
      }

      // Mark initialized after first poll completes
      if (!_initialized) {
        _initialized = true;
      }

      // Keep memory bounded
      if (_seenEventIds.length > 3000) {
        _seenEventIds.clear();
        // next poll will treat everything as "new", but EarthquakePage also dedupes.
        // If you don't like that behavior, tell me and I'll prune smarter.
      }
    } catch (_) {
      // ignore errors (feed must not crash UI)
    }
  }

  void dispose() {
    stop();
    _controller.close();
  }
}
