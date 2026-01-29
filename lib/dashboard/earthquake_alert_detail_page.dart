import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_database/firebase_database.dart';

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

class _EarthquakeAlertDetailPageState extends State<EarthquakeAlertDetailPage> {
  // ================= TREND FLASH SETTINGS =================
  // Adjust this threshold to match your device behavior
  static const double MOTION_SPIKE_THRESHOLD = 0.08;
  static const Duration FLASH_DURATION = Duration(milliseconds: 200);

  bool _flashTrend = false;
  DateTime _lastFlashAt = DateTime.fromMillisecondsSinceEpoch(0);

  void _triggerFlashIfNeeded(List<double> data) {
    if (data.isEmpty) return;

    final latest = data.last;
    if (latest < MOTION_SPIKE_THRESHOLD) return;

    final now = DateTime.now();
    // throttle flashes
    if (now.difference(_lastFlashAt) < const Duration(milliseconds: 350)) return;

    _lastFlashAt = now;

    if (!_flashTrend) {
      setState(() => _flashTrend = true);
      Future.delayed(FLASH_DURATION, () {
        if (mounted) setState(() => _flashTrend = false);
      });
    }
  }

  // ================= SENSOR STREAM =================
  Stream<List<double>> _motionStream() {
    final ref = FirebaseDatabase.instance.ref("earthquakeData");

    return ref.orderByKey().limitToLast(20).onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        return <double>[0.0];
      }

      final rawAny = event.snapshot.value;
      if (rawAny is! Map) return <double>[0.0];

      // Firebase often returns Map<dynamic, dynamic>
      final raw = Map<dynamic, dynamic>.from(rawAny);

      final List<Map<String, dynamic>> values = [];

      for (final entry in raw.entries) {
        final v = entry.value;
        if (v is Map) {
          final m = Map<dynamic, dynamic>.from(v);
          values.add(m.map((k, val) => MapEntry(k.toString(), val)));
        }
      }

      // Sort by timestamp string (ESP32 format "YYYY-MM-DD HH:MM:SS")
      values.sort((a, b) => (a['timestamp'] ?? '')
          .toString()
          .compareTo((b['timestamp'] ?? '').toString()));

      final motions = values.map((e) {
        final m = e['motion'];
        if (m is num) return m.toDouble();
        return double.tryParse(m.toString()) ?? 0.0;
      }).toList();

      return motions.isEmpty ? <double>[0.0] : motions;
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
    alert['timestamp'] is DateTime ? alert['timestamp'] : DateTime.now();

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
          Text(
            "📊 Key Metrics",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
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
          Text(
            "📉 Ground Motion Trend",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          SizedBox(
            height: 60,
            child: StreamBuilder<List<double>>(
              stream: _motionStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const LinearProgressIndicator();
                }

                final data = snapshot.data ?? <double>[0.0];
                if (data.isEmpty) {
                  return const Center(child: Text("No motion data"));
                }

                // trigger flash after frame (no setState inside build)
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _triggerFlashIfNeeded(data);
                });

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOut,
                  decoration: BoxDecoration(
                    color: _flashTrend
                        ? Colors.red.withOpacity(0.18)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: CustomPaint(
                    painter: _MiniChartPainter(
                      data: data,
                      color: color,
                      spikeThreshold: MOTION_SPIKE_THRESHOLD,
                    ),
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

/// ================= MINI CHART =================
class _MiniChartPainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final double spikeThreshold;

  _MiniChartPainter({
    required this.data,
    required this.color,
    required this.spikeThreshold,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final normalPaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    final spikePaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2.6
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    final minVal = data.reduce(min);
    final maxVal = data.reduce(max);

    // keep range non-zero so it always draws
    final range = (maxVal - minVal) == 0 ? 1.0 : (maxVal - minVal);

    final int n = data.length;

    // If only one point, draw a dot
    if (n < 2) {
      final y = size.height / 2;
      final dotPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;
      canvas.drawCircle(Offset(2, y), 2.8, dotPaint);
      return;
    }

    // draw line segments (red if spike)
    for (int i = 1; i < n; i++) {
      final x1 = size.width * (i - 1) / (n - 1);
      final x2 = size.width * i / (n - 1);

      final y1 = (size.height - 2) -
          ((data[i - 1] - minVal) / range) * (size.height - 4);
      final y2 = (size.height - 2) -
          ((data[i] - minVal) / range) * (size.height - 4);

      final isSpike = data[i] >= spikeThreshold || data[i - 1] >= spikeThreshold;

      canvas.drawLine(
        Offset(x1, y1),
        Offset(x2, y2),
        isSpike ? spikePaint : normalPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MiniChartPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.color != color ||
        oldDelegate.spikeThreshold != spikeThreshold;
  }
}
