import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'lib/earthquake_voice_alert.dart';

const String MAPTILER_KEY = "LvYR3jp1KitFbknow9TR";

/// ================= EARTHQUAKE ALERT DETAIL =================
class EarthquakeAlertDetailPage extends StatefulWidget {
  final Map<String, dynamic> alert;
  const EarthquakeAlertDetailPage({super.key, required this.alert});

  @override
  State<EarthquakeAlertDetailPage> createState() =>
      _EarthquakeAlertDetailPageState();
}

class _EarthquakeAlertDetailPageState
    extends State<EarthquakeAlertDetailPage> {

  // ================= SENSOR STREAM =================
  Stream<List<double>> _motionStream() {
    return FirebaseFirestore.instance
        .collection('earthquakeData')
        .doc('sensor_area_1')
        .collection('readings')
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) {
      final values = snapshot.docs.map((d) {
        final raw = d['motion'];
        if (raw is num) return raw.toDouble();
        return 0.0;
      }).toList().reversed.toList();

      return values.isEmpty ? [0.0] : values;
    });
  }

  // ================= HELPERS =================
  String formatDateTime(DateTime dt) {
    return "${dt.hour}:${dt.minute.toString().padLeft(2, '0')} "
        "— ${dt.year}-${dt.month}-${dt.day}";
  }

  String actionText(String level) {
    switch (level) {
      case "Critical":
        return "DROP, COVER, AND HOLD ON IMMEDIATELY";
      case "High":
        return "Stay alert and move to a safe area";
      case "Medium":
        return "Remain cautious";
      default:
        return "No immediate action required";
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

  // ================= INIT =================
  @override
  void initState() {
    super.initState();
    _initVoice();
  }

  Future<void> _initVoice() async {
    await VoiceAlertService.init();
    final level = widget.alert['level'];
    if (level == "High" || level == "Critical") {
      await VoiceAlertService.speakEarthquakeAlert(level);
    }
  }

  @override
  Widget build(BuildContext context) {
    final alert = widget.alert;
    final level = alert['level'] ?? "Unknown";
    final color = riskColor(level);

    final motion = (alert['motion'] ?? 0.0).toDouble();
    final vibration = alert['vibration'] == true;
    final LatLng coords =
        alert['coords'] ?? const LatLng(23.8103, 90.4125);

    final DateTime time =
    alert['timestamp'] is DateTime
        ? alert['timestamp']
        : DateTime.now();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: color,
        foregroundColor: Colors.white,
        title: const Text("Earthquake Alert Detail"),
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
                  "https://api.maptiler.com/maps/streets/{z}/{x}/{y}.png?key=$MAPTILER_KEY",
                  userAgentPackageName: 'com.example.app',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: coords,
                      width: 50,
                      height: 50,
                      child: Icon(Icons.warning, color: color, size: 36),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ================= KEY METRICS =================
          Text("📊 Key Metrics",
              style:
              const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          _metricCard(
            icon: Icons.show_chart,
            label: "Ground Motion",
            value: "${motion.toStringAsFixed(3)} g",
            color: color,
          ),

          _metricCard(
            icon: Icons.vibration,
            label: "Vibration",
            value: vibration ? "DETECTED" : "NOT DETECTED",
            color: vibration ? Colors.red : Colors.green,
          ),

          const SizedBox(height: 24),

          // ================= SENSOR TREND =================
          Text("📉 Ground Motion Trend",
              style:
              const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          SizedBox(
            height: 60,
            child: StreamBuilder<List<double>>(
              stream: _motionStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const LinearProgressIndicator();
                }
                return CustomPaint(
                  painter: _MiniChartPainter(
                    data: snapshot.data!,
                    color: color,
                  ),
                );
              },
            ),
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
              Text(label,
                  style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 4),
              Text(value,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ]),
          ],
        ),
      ),
    );
  }
}

/// ================= MINI CHART =================
class _MiniChartPainter extends CustomPainter {
  final List<double> data;
  final Color color;

  _MiniChartPainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    final ui.Path path = ui.Path();

    final minVal = data.reduce(min);
    final maxVal = data.reduce(max);
    final range = (maxVal - minVal) == 0 ? 1 : (maxVal - minVal);

    for (int i = 0; i < data.length; i++) {
      final x = size.width * i / (data.length - 1);
      final y =
          size.height - ((data[i] - minVal) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}
