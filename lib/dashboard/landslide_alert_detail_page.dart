import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/landslide_voice_alert.dart';

/// ================= LANDSLIDE ALERT DETAIL =================
class LandslideAlertDetailPage extends StatefulWidget {
  final Map<String, dynamic> alert;
  const LandslideAlertDetailPage({super.key, required this.alert});

  @override
  State<LandslideAlertDetailPage> createState() =>
      _LandslideAlertDetailPageState();
}

class _LandslideAlertDetailPageState extends State<LandslideAlertDetailPage> {
  @override
  void initState() {
    super.initState();
    _initVoice();
  }

  Future<void> _initVoice() async {
    await LandslideVoiceAlert.init();
    final level = widget.alert['level'];
    if (level == "High" || level == "Critical") {
      await LandslideVoiceAlert.speakLandslideAlert(level);
    }
  }

  Color riskColor(String level) {
    switch (level) {
      case "Critical":
        return Colors.red;
      case "High":
        return Colors.deepOrange;
      case "Medium":
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  String actionText(String level) {
    switch (level) {
      case "Critical":
        return "Evacuate immediately!";
      case "High":
        return "Move to higher ground";
      case "Medium":
        return "Stay alert for signs of landslide";
      default:
        return "No immediate action required";
    }
  }

  String formatDateTime(DateTime dt) {
    return "${dt.hour}:${dt.minute.toString().padLeft(2, '0')} — ${dt.year}-${dt.month}-${dt.day}";
  }

  @override
  Widget build(BuildContext context) {
    final alert = widget.alert;
    final level = alert['level'] ?? "Low";
    final color = riskColor(level);

    final pressure = (alert['pressure'] ?? 0).toString();
    final moisture = (alert['moisture'] ?? 0).toString();

    final LatLng coords = alert['coords'] ?? const LatLng(23.8103, 90.4125);
    final DateTime time = alert['timestamp'] ?? DateTime.now();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: color,
        foregroundColor: Colors.white,
        title: const Text("Landslide Alert Detail"),
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
                  level,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  actionText(level),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ================= TIME + LOCATION =================
          Text("🕒 Time: ${formatDateTime(time)}"),
          Text("📍 Location: ${coords.latitude}, ${coords.longitude}"),

          const SizedBox(height: 16),

          // ================= MAP =================
          SizedBox(
            height: 200,
            child: FlutterMap(
              options: MapOptions(initialCenter: coords, initialZoom: 8),
              children: [
                TileLayer(
                  urlTemplate:
                  "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: 'com.example.app',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: coords,
                      width: 50,
                      height: 50,
                      child: Icon(Icons.terrain, color: color, size: 36),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ================= KEY METRICS =================
          Text(
            "📊 Key Metrics",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          _metricCard(
            icon: Icons.speed,
            label: "Pressure",
            value: "$pressure hPa",
            color: color,
          ),

          _metricCard(
            icon: Icons.opacity,
            label: "Soil Moisture",
            value: "$moisture %",
            color: color,
          ),
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
