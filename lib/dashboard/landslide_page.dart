import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/landslide_realtime_service.dart';
import '../services/landslide_alert_service.dart';
import '../services/landslide_voice_alert.dart';
import '../services/landslide_ai_service.dart';

import '../widgets/landslide_drawer.dart';
import 'landslide_alert_detail_page.dart';
import '../services/landslide_http_service.dart';

class LandslidePage extends StatefulWidget {
  const LandslidePage({super.key});

  @override
  State<LandslidePage> createState() => _LandslidePageState();
}

class _LandslidePageState extends State<LandslidePage>
    with SingleTickerProviderStateMixin {
  // ================= SERVICES =================
  final _realtime = LandslideRealtimeService();
  final _alertService = LandslideAlertService();
  final _aiService = LandslideAIService();
  final LandslideHttpService _httpService = LandslideHttpService();

  StreamSubscription<Map<String, dynamic>>? _realtimeSub;

  // ================= ALERT HISTORY =================
  final List<Map<String, dynamic>> _alerts = [];
  List<Map<String, dynamic>> _officialAlerts = [];

  // ================= LIVE STATE =================
  int _pressure = 0;
  int _moisture = 0;
  String _riskLabel = "Low";
  String _timestamp = "";

  // ================= AI CONTROL =================
  int _lastPredicted = -1;
  DateTime? _lastAlertTime;
  final Duration _alertCooldown = const Duration(minutes: 5);

  // ================= MAP =================
  final LatLng _center = const LatLng(23.8103, 90.4125);

  // ================= ANIMATION =================
  late AnimationController _pulseController;

  final Map<String, Color> _riskColors = {
    "Low": Colors.green,
    "Medium": Colors.orange,
    "High": Colors.deepOrange,
    "Critical": Colors.red,
  };

  Color _riskColor(String level) => _riskColors[level] ?? Colors.grey;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    LandslideVoiceAlert.init();
    _aiService.loadModel();

    _listenRealtime();
    fetchOfficialAlerts();
  }

  /// Fetch official alerts from HTTP service
  Future<void> fetchOfficialAlerts() async {
    final alerts = await _httpService.fetchLandslideData();
    if (!mounted) return;

    _officialAlerts = alerts.map((a) {
      a['isOfficial'] = true;
      a['location'] ??= "Unknown Location";
      a['message'] ??= "No message available";
      a['coords'] ??= _center;
      return a;
    }).toList();

    setState(() {
      _alerts.insertAll(0, _officialAlerts);
    });
  }

  // ================= REALTIME LISTENER =================
  void _listenRealtime() {
    // ✅ Listen to latest Firebase reading
    _realtimeSub = _realtime.streamLatestReading().listen((data) async {
      if (data == null) return;

      final int pressure = (data['pressure'] ?? 0);
      final int moisture = (data['soil_moisture'] ?? 0);
      final String risk = data['risk_level'] ?? "Low";
      final String time = data['timestamp'] ?? "";

      if (!mounted) return;

      // Update UI state
      setState(() {
        _pressure = pressure;
        _moisture = moisture;
        _riskLabel = risk;
        _timestamp = time;
      });

      // Add to alerts list
      _addLiveLog(risk, pressure, moisture, time);

      // ---------------- AI + ALERT LOGIC ----------------
      if (_aiService.isModelLoaded) {
        final predicted = await _aiService.predictLandslideRisk();
        final now = DateTime.now();
        final bool cooldownPassed =
            _lastAlertTime == null || now.difference(_lastAlertTime!) > _alertCooldown;

        if (predicted == 2 && predicted != _lastPredicted && cooldownPassed) {
          // Push new alert
          await _alertService.pushLandslideAlert(
            riskLevel: "High",
            soilMoisture: _moisture.toDouble(),
            pressure: _pressure.toDouble(),
            landslideDetected: true,
          );

          // Voice alert
          await LandslideVoiceAlert.speakLandslideAlert("High");
          _lastAlertTime = now;
        }
        _lastPredicted = predicted;
      }

      // Immediate voice alert for high/critical risk
      if (_riskLabel == "High" || _riskLabel == "Critical") {
        await LandslideVoiceAlert.speakLandslideAlert(_riskLabel);
      }
    }) as StreamSubscription<Map<String, dynamic>>?;
  }

  void _addLiveLog(String level, int pressure, int moisture, String time) {
    final alert = {
      "level": level,
      "pressure": pressure,
      "moisture": moisture,
      "timestamp": time,
      "coords": _center,
      "isOfficial": false,
    };

    if (!mounted) return;

    setState(() {
      _alerts.insert(0, alert);
      if (_alerts.length > 100) _alerts.removeLast();
    });
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _riskColor(_riskLabel);

    return Scaffold(
      endDrawer: const LandslideDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.lime.shade700,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text("Landslide Detection"),
      ),
      body: Column(
        children: [
          // ================= MAP =================
          SizedBox(
            height: 250,
            child: FlutterMap(

              options: MapOptions(
                onTap: (tapPos, latlng){}, // ✅ Correct: center instead of onTap
                maxZoom: 7,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                  "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: 'com.example.app',
                ),

                // Official alert markers
                MarkerLayer(
                  markers: _officialAlerts.map((alert) {
                    final LatLng point = alert['coords'] ?? _center;
                    return Marker(
                      point: point,
                      width: 40,
                      height: 40,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  LandslideAlertDetailPage(alert: alert),
                            ),
                          );
                        },
                        child: const Icon(
                          Icons.public,
                          color: Colors.blueAccent,
                          size: 28,
                        ),
                      ),
                    );
                  }).toList(),
                ),

                // Live sensor marker with pulse
                if (_riskLabel != "Low")
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _center,
                        width: 70,
                        height: 70,
                        child: GestureDetector(
                          onTap: () {
                            if (_alerts.isNotEmpty) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => LandslideAlertDetailPage(
                                      alert: _alerts.first),
                                ),
                              );
                            }
                          },
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              ScaleTransition(
                                scale: Tween(begin: 1.0, end: 1.4)
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
                                Icons.terrain,
                                color: color,
                                size: 34,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // ================= RISK CARD =================
          Padding(
            padding: const EdgeInsets.all(12),
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
                        Icons.warning,
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
                            "Risk Level: $_riskLabel",
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text("Pressure: $_pressure",
                              style: const TextStyle(color: Colors.white70)),
                          Text("Soil Moisture: $_moisture",
                              style: const TextStyle(color: Colors.white70)),
                          Text("Time: $_timestamp",
                              style: const TextStyle(color: Colors.white70)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ================= ALERT LIST =================
          Expanded(
            child: _alerts.isEmpty
                ? const Center(child: Text("No Recent Landslide Data"))
                : ListView.builder(
              itemCount: _alerts.length,
              itemBuilder: (ctx, i) {
                final alert = _alerts[i];
                final lvl = alert['level'];
                final isOfficial = alert['isOfficial'] == true;
                final c = isOfficial ? Colors.blueAccent : _riskColor(lvl);

                return Card(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: c,
                      child: Icon(
                        isOfficial ? Icons.public : Icons.terrain,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(isOfficial
                        ? "${alert['location']} (Official)"
                        : "Risk: $lvl"),
                    subtitle: Text(isOfficial
                        ? "${alert['message']}\nTime: ${alert['timestamp']}"
                        : "Pressure: ${alert['pressure']}  |  Moisture: ${alert['moisture']}\nTime: ${alert['timestamp']}"),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                LandslideAlertDetailPage(alert: alert)),
                      );
                    },
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
