import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/landslide_voice_alert.dart';

const String MAPTILER_KEY = "LvYR3jp1KitFbknow9TR";

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

  // Method to determine if soil is wet or dry based on moisture value
  String getSoilStatus(int moisture) {
    if (moisture > 2000) {
      return "Dry";  // Soil is Dry if moisture > 2000
    } else {
      return "Wet";  // Soil is Wet if moisture <= 2000
    }
  }

  // Color based on soil status (wet or dry)
  Color getSoilStatusColor(String status) {
    if (status == "Wet") {
      return Color(0xFF00BFFF).withOpacity(0.5);  // Light Sky Blue for wet
    } else {
      return Colors.brown.withOpacity(0.6);  // Light brown for dry
    }
  }

  @override
  Widget build(BuildContext context) {
    final alert = widget.alert;
    final level = alert['level'] ?? "Low";
    final color = riskColor(level);

    final pressure = (alert['pressure'] ?? 0).toString();
    final moisture = (alert['moisture'] ?? 0).toInt(); // Converted to integer

    final LatLng coords =
        alert['coords'] ?? const LatLng(23.8103, 90.4125);

    DateTime time;

    final rawTime = alert['timestamp'];

    if (rawTime is DateTime) {
      time = rawTime;
    } else if (rawTime is String) {
      try {
        final fixed =
        rawTime.contains(' ') ? rawTime.replaceFirst(' ', 'T') : rawTime;
        time = DateTime.parse(fixed);
      } catch (_) {
        time = DateTime.now();
      }
    } else {
      time = DateTime.now();
    }

    // Get soil status (Wet or Dry)
    String soilStatus = getSoilStatus(moisture);
    Color soilColor = getSoilStatusColor(soilStatus); // Get the color based on wet/dry

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

          const SizedBox(height: 40),

          // ================= TIME + LOCATION =================
          Text("🕒 Time: ${formatDateTime(time)}"),
          Text("📍 Location: ${coords.latitude}, ${coords.longitude}"),

          const SizedBox(height: 32),

          // ================= MAP =================
          SizedBox(
            height: 200,
            child: FlutterMap(
              options: MapOptions(initialCenter: coords, initialZoom: 8),
              children: [
                TileLayer(
                  urlTemplate:
                  "https://api.maptiler.com/maps/streets/{z}/{x}/{y}.png?key=$MAPTILER_KEY",
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

          const SizedBox(height: 32),

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
            value: "$moisture",
            color: color,
          ),

          // ================= SOIL STATUS CARD =================
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            color: soilColor, // Dynamic color for wet or dry status
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white.withOpacity(0.15),
                    child: Icon(
                      Icons.water_damage, // Icon for water damage (wet/dry)
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Soil Status", style: const TextStyle(
                          color: Colors.white)),
                      const SizedBox(height: 4),
                      Text(
                        soilStatus, // Display "Wet" or "Dry"
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
        ]), // End of Column
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
