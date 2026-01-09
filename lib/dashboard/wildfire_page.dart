import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../services/wildfire_ai_service.dart';
import '../services/wildfire_alert_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/notification_service.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:convert';
import '../services/wildfire_realtime_service.dart';
import 'dart:async';

import 'wildfire_drawer.dart';
import 'wildfire_alert_detail_page.dart';


/// ===================== WILDFIRE PAGE =====================

const String MAPTILER_KEY = "LvYR3jp1KitFbknow9TR";

class WildfirePage extends StatefulWidget {
  const WildfirePage({super.key});

  @override
  State<WildfirePage> createState() => _WildfirePageState();
}

class _WildfirePageState extends State<WildfirePage>
    with SingleTickerProviderStateMixin {
  // SERVICES
  final _ai = WildfireAIService();
  final _realtime = WildfireRealtimeService();
  final _alertService = WildfireAlertService();

  StreamSubscription? _subscription;

  // STATE
  double _risk = 0.0;
  String _riskLabel = "Low";

  DateTime? _lastAlertTime;
  final Duration alertCooldown = const Duration(minutes: 10);

  final List<Map<String, dynamic>> _alerts = [];

  // MAP
  final LatLng _center = const LatLng(23.8103, 90.4125);

  // MAP STYLE
  String _mapStyle = "streets";

  String get _mapTilerURL {
    switch (_mapStyle) {
      case "terrain":
        return "https://api.maptiler.com/maps/terrain/{z}/{x}/{y}.png?key=LvYR3jp1KitFbknow9TR";
      case "satellite":
        return "https://api.maptiler.com/maps/satellite/{z}/{x}/{y}.jpg?key=LvYR3jp1KitFbknow9TR";
      default:
        return "https://api.maptiler.com/maps/streets/{z}/{x}/{y}.png?key=LvYR3jp1KitFbknow9TR";
    }
  }

  // ANIMATION
  late AnimationController _pulseController;

  final Map<String, Color> _riskColors = {
    "Low": Colors.green,
    "Medium": Colors.orange,
    "High": Colors.deepOrange,
    "Critical": Colors.red,
  };

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )
      ..repeat(reverse: true);

    _init();
  }

  Future<void> _init() async {
    await _ai.loadModel();
    _listenRealtime();
  }

  // ================= REALTIME LISTENER =================
  void _listenRealtime() {
    _subscription = _realtime.streamWildfireData().listen((records) async {
      if (records.isEmpty) return;

      final risk = await _ai.predictWildfireRisk();
      final label = _riskLabelFromValue(risk);

      final sensorData = {
        "temperature": records.last['temperature'] ?? "--",
        "humidity": records.last['humidity'] ?? "--",
        "smoke": records.last['gas_value'] ?? "--",
        "flame": records.last['flame_detected'] ?? "--",
        "cause": label == "Critical"
            ? "Active Fire Detected"
            : label == "High"
            ? "High Heat & Smoke"
            : "Normal",
      };

      setState(() {
        _risk = risk;
        _riskLabel = label;
      });

      await _handleAlert(risk, label, sensorData);
    });
  }

  // ================= ALERT LOGIC =================
  Future<void> _handleAlert(double risk, String label,
      Map<String, dynamic> sensorData) async {
    if (risk < 0.3) return;

    final now = DateTime.now();
    if (_lastAlertTime != null &&
        now.difference(_lastAlertTime!) < alertCooldown) {
      return;
    }

    _lastAlertTime = now;

    await _alertService.pushAlert(
      level: label,
      message:
      "Wildfire risk detected: $label (${(risk * 100).toStringAsFixed(1)}%)",
    );

    NotificationService.showAlertNotification(
      "🔥 Wildfire Alert",
      "Risk level: $label",
    );

    _addAlert(label, sensorData);
  }

  void _addAlert(String level, Map<String, dynamic> sensorData) {
    final alert = {
      "type": "Wildfire",
      "level": level,
      "message": "Wildfire risk detected: $level",
      "timestamp": DateTime.now(),
      "location": "Sensor Area",
      "coords": _center,
      "sensorData": sensorData,
    };

    setState(() {
      _alerts.insert(0, alert);
    });
  }

  // ----------------------------------------------------
  // HELPERS
  // ----------------------------------------------------

  String _riskLabelFromValue(double v) {
    if (v >= 0.75) return "Critical";
    if (v >= 0.5) return "High";
    if (v >= 0.3) return "Medium";
    return "Low";
  }

  Color _riskColor(String level) => _riskColors[level] ?? Colors.grey;

  @override
  void dispose() {
    _subscription?.cancel();
    _pulseController.dispose();
    _ai.close();
    super.dispose();
  }

// ====================================================
// UI (FULLY MERGED — NOTHING REMOVED)
// ====================================================
  @override
  Widget build(BuildContext context) {
    final color = _riskColor(_riskLabel);

    return Scaffold(
      endDrawer: const WildfireDrawer(), // ✅ RIGHT drawer

      // ================= APP BAR =================
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Builder(
          builder: (context) =>
              AppBar(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                // ✅ text + icons white
                centerTitle: true,
                title: const Text(
                  "Wildfire Detection",
                  style: TextStyle(color: Colors.white),
                ),
                actions: [
                  // ===== MAP STYLE DROPDOWN =====
                  DropdownButtonHideUnderline(
                    child: DropdownButton2<String>(
                      value: _mapStyle,
                      customButton: const Icon(Icons.map, color: Colors.white),

                      dropdownStyleData: DropdownStyleData(
                        maxHeight: 200,
                        width: 180,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        offset: const Offset(-80, 10),
                      ),

                      menuItemStyleData: const MenuItemStyleData(
                        height: 45,
                        padding: EdgeInsets.symmetric(horizontal: 12),
                      ),

                      items: const [
                        DropdownMenuItem(
                            value: "streets", child: Text("Street")),
                        DropdownMenuItem(
                            value: "terrain", child: Text("Terrain")),
                        DropdownMenuItem(
                            value: "satellite", child: Text("Satellite")),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _mapStyle = val);
                        }
                      },
                    ),
                  ),

                  // ===== SETTINGS =====
                  IconButton(
                    icon: const Icon(Icons.settings, color: Colors.white),
                    onPressed: () => Scaffold.of(context).openEndDrawer(),
                  ),
                ],
              ),
        ),
      ),

      // ================= BODY =================
      body: Column(
        children: [
          // ================= MAP =================
          SizedBox(
            height: 250,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: _center,
                initialZoom: 7,
              ),
              children: [
                TileLayer(
                  urlTemplate: _mapTilerURL,
                  userAgentPackageName: 'com.example.app',
                ),

                // ===== FIRE MARKER =====
                MarkerLayer(
                  markers: _alerts.isEmpty
                      ? []
                      : [
                    Marker(
                      point: _center,
                      width: 70,
                      height: 70,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          ScaleTransition(
                            scale: Tween(begin: 1.0, end: 1.3)
                                .animate(_pulseController),
                            child: Container(
                              width: 45,
                              height: 45,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: color.withOpacity(0.3),
                              ),
                            ),
                          ),
                          Icon(
                            Icons.local_fire_department,
                            color: color,
                            size: 34,
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ],
            ),
          ),

          // ================= TAPPABLE RISK BANNER =================
          Padding(
            padding: const EdgeInsets.all(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _alerts.isEmpty
                  ? null
                  : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        WildfireAlertDetailPage(
                          alert: _alerts.first, // 🔥 latest alert
                        ),
                  ),
                );
              },
              child: Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [
                        color.withOpacity(0.9),
                        color.withOpacity(0.6),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.local_fire_department,
                          color: color,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Wildfire Risk: $_riskLabel",
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Probability: ${(100 * _risk).toStringAsFixed(
                                  1)}%",
                              style:
                              const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ================= RISK METER (RESTORED) =================
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Risk Level Meter",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: _risk.clamp(0.0, 1.0),
                  minHeight: 12,
                  backgroundColor: Colors.grey.shade300,
                  color: color,
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ================= ALERT LIST =================
          Expanded(
            child: _alerts.isEmpty
                ? const Center(child: Text("No Recent Alerts"))
                : ListView.builder(
              itemCount: _alerts.length,
              itemBuilder: (ctx, i) {
                final alert = _alerts[i];
                final lvl = alert['level'];
                final c = _riskColor(lvl);

                return Card(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: c,
                      child: const Icon(
                        Icons.local_fire_department,
                        color: Colors.white,
                      ),
                    ),
                    title: Text("Wildfire Risk: $lvl"),
                    subtitle: Text(
                      "Time: ${alert['timestamp']}",
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }


}