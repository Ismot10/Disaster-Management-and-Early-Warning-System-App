import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';


const String MAPTILER_KEY = "LvYR3jp1KitFbknow9TR";



/// ================= ALERT DETAIL =================
class WildfireAlertDetailPage extends StatelessWidget {
final Map<String, dynamic> alert;
const WildfireAlertDetailPage({super.key, required this.alert});

String formatDateTime(DateTime dt) {
return "${dt.hour}:${dt.minute.toString().padLeft(2, '0')} — ${dt.year}-${dt.month}-${dt.day}";
}

@override
Widget build(BuildContext context) {
final color = {
'Low': Colors.green,
'Medium': Colors.orange,
'High': Colors.deepOrange,
'Critical': Colors.red,
}[alert['level']] ?? Colors.grey;
final LatLng? coords = alert['coords'] as LatLng?;
final sensor = alert['sensorData'] ?? {};

final DateTime timestamp = alert['timestamp'] is DateTime
? alert['timestamp'] as DateTime
    : DateTime.now();

return Scaffold(
appBar: AppBar(
  backgroundColor: Colors.deepOrange,
title: const Text("Wildfire Alert Detail",
  style: TextStyle(color: Colors.white),)

),
body: SingleChildScrollView(
padding: const EdgeInsets.all(16),
child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
Text(alert['level'] as String? ?? 'Unknown',
style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 26)),
const SizedBox(height: 8),
Text(alert['message'] as String? ?? ''),
const SizedBox(height: 12),
Text("Location: ${alert['location'] ?? 'Unknown'}"),
Text("Time: ${formatDateTime(timestamp)}"),
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
additionalOptions: const {
'attribution': '© MapTiler © OpenStreetMap contributors',
},
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
const SizedBox(height: 20),
if (sensor.isNotEmpty) ...[
const Divider(),
const Text("📟 Sensor Data",
style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
const SizedBox(height: 8),
Text("Temperature: ${sensor['temperature']} °C"),
Text("Humidity: ${sensor['humidity']} %"),
Text("Smoke Level: ${sensor['smoke']}"),
Text("Flame: ${sensor['flame']}"),
Text("Cause: ${sensor['cause']}"),
] else
const Text(
"No sensor details available for this alert.",
style: TextStyle(fontStyle: FontStyle.italic),
),
]),
),
);
}
}
