import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui' as ui;


const String MAPTILER_KEY = "LvYR3jp1KitFbknow9TR";

/// ================= ALERT DETAIL =================
class WildfireAlertDetailPage extends StatelessWidget {
  final Map<String, dynamic> alert;
  const WildfireAlertDetailPage({super.key, required this.alert});

  String formatDateTime(DateTime dt) {
    return "${dt.hour}:${dt.minute.toString().padLeft(2, '0')} — ${dt.year}-${dt.month}-${dt.day}";
  }

  /// 🔥 Firestore rolling window (last N points)
  Stream<List<double>> _sensorStream(String field) {
    return FirebaseFirestore.instance
        .collection('wildfireData') // 🔴 CHANGE IF NEEDED
        .doc('sensor_area_1')                // 🔴 CHANGE IF NEEDED
        .collection('readings')
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) {
      final values = snapshot.docs
          .map((d) => (d[field] as num?)?.toDouble())
          .whereType<double>()
          .toList()
          .reversed
          .toList();

      return values.isEmpty ? [0] : values;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final color = {
      'Low': Colors.green,
      'Medium': Colors.orange,
      'High': Colors.deepOrange,
      'Critical': Colors.red,
    }[alert['level']] ?? Colors.grey;

    final LatLng? coords = alert['coords'] as LatLng?;
    final sensor = alert['sensorData'] ?? {};
    final flameValue = int.tryParse(sensor['flame']?.toString() ?? '0') ?? 0;

    final DateTime timestamp =
    alert['timestamp'] is DateTime ? alert['timestamp'] : DateTime.now();

    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        title: const Text("Wildfire Alert Detail"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            alert['level'] ?? 'Unknown',
            style: TextStyle(color: color, fontSize: 26, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),
          Text(alert['message'] ?? '', style: TextStyle(color: textColor)),

          const SizedBox(height: 12),
          Text("📍 Location: ${alert['location']}", style: TextStyle(color: textColor)),
          Text("🕒 Time: ${formatDateTime(timestamp)}", style: TextStyle(color: textColor)),

          const SizedBox(height: 16),

          if (coords != null)
            SizedBox(
              height: 200,
              child: FlutterMap(
                options: MapOptions(initialCenter: coords, initialZoom: 11),
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
                        width: 36,
                        height: 36,
                        child: Icon(Icons.location_on, color: color, size: 34),
                      )
                    ],
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),
          Divider(color: isDark ? Colors.white24 : Colors.black26),

          Text("📟 Sensor Data",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 4),

          _firestoreSensorCard(
            context,
            label: "Temperature",
            icon: Icons.thermostat,
            value: "${sensor['temperature']} °C",
            color: Colors.red,
            stream: _sensorStream('temperature'),
          ),

          _firestoreSensorCard(
            context,
            label: "Humidity",
            icon: Icons.water_drop,
            value: "${sensor['humidity']} %",
            color: Colors.blue,
            stream: _sensorStream('humidity'),
          ),

          _firestoreSensorCard(
            context,
            label: "Smoke",
            icon: Icons.smoking_rooms,
            value: "${sensor['smoke']}",
            color: Colors.grey,
            stream: _sensorStream('gas_value'),
          ),


    _firestoreSensorCard(
    context,
    label: "Flame",
    icon: Icons.local_fire_department,
    value: flameValue == 1 ? "🔥 Detected" : "✅ Normal",
    color: flameValue == 1 ? Colors.red : Colors.deepOrange,
    stream: _sensorStream('flame_detected'),
    ),

    ]),
      ),
    );
  }

  /// ================= SENSOR CARD (REAL FIRESTORE DATA) =================
  Widget _firestoreSensorCard(
      BuildContext context, {
        required String label,
        required IconData icon,
        required String value,
        required Color color,
        required Stream<List<double>> stream,
      }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      color: isDark ? Colors.grey.shade900 : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.15),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(label,
                        style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54)),
                    const SizedBox(height: 4),
                    Text(value,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black)),
                  ]),
                ),
              ],
            ),

            const SizedBox(height: 10),

            SizedBox(
              height: 45,
              child: StreamBuilder<List<double>>(
                stream: stream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: LinearProgressIndicator());
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
          ],
        ),
      ),
    );
  }
}

/// ================= MINI CHART PAINTER =================


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
      final double x = size.width * i / (data.length - 1);
      final double y =
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
