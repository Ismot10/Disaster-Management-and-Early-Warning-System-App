import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// ✅ IMPORTANT: update this path to match YOUR file name/location
// Example if you save it as: lib/services/storm_voice_alert_service.dart
import 'storm_voice_alert.dart';


const String MAPTILER_KEY = "LvYR3jp1KitFbknow9TR";

/// ================= STORM ALERT DETAIL =================
/// Supports alerts created in StormPage:
/// type: "Fusion" | "AI" | "Live"
class StormAlertDetailPage extends StatefulWidget {
  final Map<String, dynamic> alert;
  const StormAlertDetailPage({super.key, required this.alert});

  @override
  State<StormAlertDetailPage> createState() => _StormAlertDetailPageState();
}

class _StormAlertDetailPageState extends State<StormAlertDetailPage> {
  @override
  void initState() {
    super.initState();
    _initVoice();
  }

  Future<void> _initVoice() async {
    // init (safe to call multiple times due to your _initialized flag)
    await StormVoiceAlertService.init();

    final type = _asString(widget.alert["type"], "Live");
    final level = _asString(widget.alert["level"], "Normal");

    // Speak only for danger
    final important =
        level == "Cyclone" || level == "HighRisk" || level == "Extreme" || level == "Storm";
    if (!important) return;

    // For Fusion: speak fusion message
    if (type == "Fusion") {
      final event = _asString(widget.alert["event"], "Normal");
      await StormVoiceAlertService.speakStormFusionAlert(level, event);
      return;
    }

    // For Live: speak storm-only message (Storm/Cyclone)
    final stormRisk = _asString(widget.alert["stormRisk"], level);
    await StormVoiceAlertService.speakStormRiskAlert(stormRisk);
  }

  // ---------------- SAFE HELPERS ----------------
  String _asString(dynamic v, [String fallback = ""]) {
    if (v == null) return fallback;
    return v.toString();
  }

  double _asDouble(dynamic v, [double fallback = 0.0]) {
    if (v == null) return fallback;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? fallback;
  }

  int _asInt(dynamic v, [int fallback = 0]) {
    if (v == null) return fallback;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? fallback;
  }

  DateTime _asDateTime(dynamic raw) {
    if (raw is DateTime) return raw;
    if (raw is String) {
      try {
        final fixed = raw.contains(' ') ? raw.replaceFirst(' ', 'T') : raw;
        return DateTime.parse(fixed);
      } catch (_) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  // ---------------- UI LOGIC ----------------
  Color riskColor(String level) {
    switch (level) {
      case "Extreme":
        return Colors.red;
      case "HighRisk":
        return Colors.deepOrange;

    // storm labels
      case "Cyclone":
        return Colors.red;
      case "Storm":
        return Colors.orange;

    // AI
      case "AI":
        return Colors.indigo;

      default:
        return Colors.green;
    }
  }

  String actionText(String type, String level, String event, String stormRisk) {
    // Fusion risk prioritized
    if (type == "Fusion") {
      if (level == "Extreme" || event == "Cyclone+Flood") {
        return "Extreme danger! Move to a safe place and avoid low-lying areas.";
      }
      if (level == "HighRisk") {
        return "High risk! Secure valuables, prepare essentials, and stay alert.";
      }
      return "Monitor conditions and follow official updates.";
    }

    // Storm-only
    if (stormRisk == "Cyclone") {
      return "Cyclone risk detected. Take shelter and follow official warnings.";
    }
    if (stormRisk == "Storm") {
      return "Strong storm conditions. Stay indoors and avoid unnecessary travel.";
    }

    // AI or Live normal
    if (type == "AI") return "AI forecast only. Keep monitoring for confirmation.";
    return "No immediate action required.";
  }

  String formatDateTime(DateTime dt) {
    return "${dt.hour}:${dt.minute.toString().padLeft(2, '0')} — ${dt.year}-${dt.month}-${dt.day}";
  }

  Color _floodRiskColor(String level) {
    switch (level) {
      case "Critical":
        return Colors.red.withOpacity(0.85);
      case "High":
        return Colors.deepOrange.withOpacity(0.85);
      case "Medium":
        return Colors.orange.withOpacity(0.85);
      default:
        return Colors.green.withOpacity(0.75);
    }
  }

  @override
  Widget build(BuildContext context) {
    final alert = widget.alert;

    final type = _asString(alert["type"], "Live");
    final level = _asString(alert["level"], "Normal");

    final color = riskColor(level);

    final LatLng coords = (alert["coords"] is LatLng)
        ? alert["coords"] as LatLng
        : const LatLng(23.8103, 90.4125);

    final time = _asDateTime(alert["timestamp"]);

    // Common
    final wind = _asDouble(alert["wind"], 0.0);
    final stormRisk = _asString(alert["stormRisk"], level);

    // Fusion
    final event = _asString(alert["event"], "Normal");
    final rain = _asInt(alert["rain"], 0);
    final water = _asInt(alert["water"], 0);
    final dist = _asDouble(alert["dist"], 0.0);
    final floodRisk = _asString(alert["floodRisk"], "Low");

    // AI
    final confidence = _asDouble(alert["confidence"], 0.0);

    final action = actionText(type, level, event, stormRisk);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: color,
        foregroundColor: Colors.white,
        title: const Text("Storm Alert Detail"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ================= RISK + ACTION =================
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type == "Fusion"
                      ? "Fusion Risk: $level"
                      : type == "AI"
                      ? "AI Prediction"
                      : "Storm Risk: $stormRisk",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 8),
                if (type == "Fusion") ...[
                  Text(
                    "Event: $event",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                Text(
                  action,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ================= TIME + LOCATION =================
          Text("🕒 Time: ${formatDateTime(time)}"),
          Text("📍 Location: ${coords.latitude}, ${coords.longitude}"),

          const SizedBox(height: 24),

          // ================= MAP =================
          SizedBox(
            height: 200,
            child: FlutterMap(
              options: MapOptions(initialCenter: coords, initialZoom: 8),
              children: [
                TileLayer(
                  urlTemplate:
                  "https://api.maptiler.com/maps/streets/{z}/{x}/{y}.png?key=$MAPTILER_KEY",
                  userAgentPackageName: 'com.earlywarning.app',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: coords,
                      width: 50,
                      height: 50,
                      child: Icon(Icons.warning_amber, color: color, size: 36),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ================= KEY METRICS =================
          Text(
            "📊 Key Metrics",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          _metricCard(
            icon: Icons.air,
            label: "Wind Speed",
            value: "${wind.toStringAsFixed(2)} m/s",
            color: color,
          ),

          if (type != "Fusion")
            _metricCard(
              icon: Icons.cloud,
              label: "Storm Risk",
              value: stormRisk,
              color: color,
            ),

          if (type == "Fusion") ...[
            _metricCard(
              icon: Icons.merge_type,
              label: "Fused Event",
              value: event,
              color: color,
            ),
            _metricCard(
              icon: Icons.umbrella,
              label: "Rain",
              value: "$rain%",
              color: color,
            ),
            _metricCard(
              icon: Icons.water,
              label: "Water",
              value: "$water%",
              color: color,
            ),
            _metricCard(
              icon: Icons.straighten,
              label: "Distance",
              value: "${dist.toStringAsFixed(1)} cm",
              color: color,
            ),

            // Flood status card
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              color: _floodRiskColor(floodRisk),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white.withOpacity(0.15),
                      child: const Icon(Icons.flood, color: Colors.white),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Flood Risk",
                            style: TextStyle(color: Colors.white)),
                        const SizedBox(height: 4),
                        Text(
                          floodRisk,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],

          if (type == "AI") ...[
            _metricCard(
              icon: Icons.psychology,
              label: "Predicted Event",
              value: _asString(alert["event"], "Unknown"),
              color: color,
            ),
            _metricCard(
              icon: Icons.percent,
              label: "Confidence",
              value: "${(confidence * 100).toStringAsFixed(1)}%",
              color: color,
            ),
          ],
        ]),
      ),
    );
  }

  // ================= METRIC CARD =================
  Widget _metricCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 4),
              Text(
                value,
                style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}