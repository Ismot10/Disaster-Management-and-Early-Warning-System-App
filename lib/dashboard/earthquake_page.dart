import 'dart:async';

import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/earthquake_realtime_service.dart';
import '../services/earthquake_alert_service.dart';
import '../utils/notification_service.dart';
import 'lib/earthquake_voice_alert.dart';

import '../services/earthquake_ai_service.dart';

import 'earthquake_drawer.dart';
import 'earthquake_alert_detail_page.dart';

/// ===================== EARTHQUAKE PAGE =====================

const String MAPTILER_KEY = "LvYR3jp1KitFbknow9TR";

class EarthquakePage extends StatefulWidget {
  const EarthquakePage({super.key});

  @override
  State<EarthquakePage> createState() => _EarthquakePageState();
}

class _EarthquakePageState extends State<EarthquakePage>
    with SingleTickerProviderStateMixin {
  // ================= SERVICES =================
  final _realtime = EarthquakeRealtimeService();
  final _alertService = EarthquakeAlertService();
  final _ai = EarthquakeAIService();

  // ✅ Split subscriptions (keeps your features, fixes lag)
  StreamSubscription? _latestSub;
  StreamSubscription? _windowSub;

  // ================= REALTIME STATE (ALWAYS UPDATES) =================
  double _motion = 0.0;
  bool _vibration = false;
  String _riskLabel = "Low";

  // ================= ALERT CONTROL (NEVER CONTROLS UI) =================
  DateTime? _lastAlertTime;
  final Duration alertCooldown = const Duration(minutes: 5);

  // ================= ALERT HISTORY =================
  final List<Map<String, dynamic>> _alerts = [];

  // ✅ Live feed throttle (so list looks alive but not spammy)
  DateTime _lastLiveLogTime = DateTime.fromMillisecondsSinceEpoch(0);

  // ✅ Prevent overlapping AI calls (removes delay)
  bool _aiBusy = false;

  // ================= MAP =================
  final LatLng _center = const LatLng(23.8103, 90.4125);

  String _mapStyle = "streets";

  String get _mapTilerURL {
    switch (_mapStyle) {
      case "terrain":
        return "https://api.maptiler.com/maps/terrain/{z}/{x}/{y}.png?key=$MAPTILER_KEY";
      case "satellite":
        return "https://api.maptiler.com/maps/satellite/{z}/{x}/{y}.jpg?key=$MAPTILER_KEY";
      default:
        return "https://api.maptiler.com/maps/streets/{z}/{x}/{y}.png?key=$MAPTILER_KEY";
    }
  }

  // ================= ANIMATION =================
  late AnimationController _pulseController;

  final Map<String, Color> _riskColors = {
    "Low": Colors.green,
    "Medium": Colors.orange,
    "High": Colors.deepOrange,
    "Critical": Colors.red,
  };

  // ================= INIT =================
  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    VoiceAlertService.init();
    _ai.loadModel(); // ✅ keep your AI

    // ✅ Live sensor streaming (instant)
    _listenLatestSensor();

    // ✅ AI + alert streaming based on last-15 window (no Firebase get inside loop)
    _listenWindowForAI();
  }

  // ================= LIVE SENSOR LISTENER (NO AI, NO DELAY) =================
  void _listenLatestSensor() {
    _latestSub = _realtime.streamLatestReading().listen((latest) {
      if (latest == null) return;

      final double motion = (latest['motion'] ?? 0.0).toDouble();
      final bool vibration = (latest['vibration_detected'] ?? 0) == 1;

      if (!mounted) return;
      setState(() {
        _motion = motion;
        _vibration = vibration;
        // ❗ risk remains controlled by AI stream below (keeps your design)
      });
    });
  }

  // ================= AI + ALERT LISTENER (NO BLOCKING STREAM) =================
  void _listenWindowForAI() {
    _windowSub = _realtime.streamLast15Window().listen((window) async {
      if (window.length < 15) return;
      if (_aiBusy) return;
      if (!_ai.isModelLoaded) return;

      _aiBusy = true;

      // Build model input [15][2] from streamed window
      final inputWindow = window.map((e) {
        final m =
        ((e['motion'] ?? 0.0) as num).toDouble().clamp(0.0, 1.0);
        final vib =
        ((e['vibration_detected'] ?? 0) as int) == 1 ? 1.0 : 0.0;
        return [m, vib];
      }).toList(growable: false);

      // ✅ IMPORTANT:
      // This must be a method that does NOT call Firebase .get()
      // Add this method in EarthquakeAIService: predictFromWindow(...)
      final int aiClass = await _ai.predictFromWindow(inputWindow);

      final String risk = switch (aiClass) {
        2 => "High",
        1 => "Medium",
        _ => "Low",
      };

      // latest record info from window
      final last = window.last;
      final double motion = (last['motion'] ?? 0.0).toDouble();
      final bool vibration = (last['vibration_detected'] ?? 0) == 1;
      final bool quake = (last['earthquake_detected'] ?? 0) == 1;

      // ✅ Update risk label (your banner, marker, colors, etc.)
      if (mounted) {
        setState(() {
          _riskLabel = risk;
        });
      }

      // ✅ Make the list "live" (even if cooldown blocks notifications)
      _addLiveLogIfNeeded(risk, motion, vibration);

      // ✅ Keep your existing alert behavior (push + notification + voice)
      await _handleEarthquakeAlertIfNeeded(
        risk: risk,
        motion: motion,
        vibration: vibration,
        quake: quake,
      );

      _aiBusy = false;
    });
  }

  // ================= ALERT LOGIC (UNCHANGED FEATURES) =================
  Future<void> _handleEarthquakeAlertIfNeeded({
    required String risk,
    required double motion,
    required bool vibration,
    required bool quake,
  }) async {
    // ❗ UI ALREADY UPDATED ABOVE

    if (risk != "Critical" && risk != "High") return;

    final now = DateTime.now();
    if (_lastAlertTime != null &&
        now.difference(_lastAlertTime!) < alertCooldown) {
      return;
    }

    _lastAlertTime = now;

    await _alertService.pushEarthquakeAlert(
      riskLevel: risk,
      motion: motion,
      vibrationDetected: vibration,
      earthquakeDetected: quake,
    );

    NotificationService.showAlertNotification(
      "🌍 Earthquake Alert",
      "Risk Level: $risk",
    );

    await VoiceAlertService.speakEarthquakeAlert(risk);

    _addAlert(risk, motion, vibration);
  }

  // ================= LIVE FEED (SO LIST UPDATES CONTINUOUSLY) =================
  void _addLiveLogIfNeeded(String level, double motion, bool vibration) {
    // Log at most 1 entry per 2 seconds to avoid flooding UI
    final now = DateTime.now();
    if (now.difference(_lastLiveLogTime) < const Duration(seconds: 2)) return;
    _lastLiveLogTime = now;

    final alert = {
      "type": "Live", // doesn't change UI features, just helps if you want
      "level": level,
      "motion": motion,
      "vibration": vibration,
      "timestamp": now,
      "coords": _center,
    };

    if (!mounted) return;
    setState(() {
      _alerts.insert(0, alert);
      if (_alerts.length > 100) _alerts.removeLast();
    });
  }

  // ================= ALERT STORAGE (UNCHANGED FEATURES) =================
  void _addAlert(String level, double motion, bool vibration) {
    final alert = {
      "type": "Earthquake",
      "level": level,
      "motion": motion,
      "vibration": vibration,
      "timestamp": DateTime.now(),
      "coords": _center,
    };

    if (!mounted) return;
    setState(() {
      _alerts.insert(0, alert);
    });
  }

  Color _riskColor(String level) => _riskColors[level] ?? Colors.grey;

  // ================= DISPOSE =================
  @override
  void dispose() {
    _latestSub?.cancel();
    _windowSub?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  // ================= UI (UNCHANGED) =================
  @override
  Widget build(BuildContext context) {
    final color = _riskColor(_riskLabel);

    return Scaffold(
      endDrawer: const EarthquakeDrawer(),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Builder(
          builder: (context) => AppBar(
            backgroundColor: Colors.red.shade700,
            foregroundColor: Colors.white,
            centerTitle: true,
            title: const Text("Earthquake Detection"),
            actions: [
              DropdownButtonHideUnderline(
                child: DropdownButton2<String>(
                  value: _mapStyle,
                  customButton: const Icon(Icons.map, color: Colors.white),
                  dropdownStyleData: DropdownStyleData(
                    width: 160,
                    maxHeight: 200,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                  menuItemStyleData: const MenuItemStyleData(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                  ),
                  items: const [
                    DropdownMenuItem(value: "streets", child: Text("Street")),
                    DropdownMenuItem(value: "terrain", child: Text("Terrain")),
                    DropdownMenuItem(
                        value: "satellite", child: Text("Satellite")),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _mapStyle = v);
                    }
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => Scaffold.of(context).openEndDrawer(),
              ),
            ],
          ),
        ),
      ),
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
                MarkerLayer(
                  markers: _riskLabel == "Low"
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
                            Icons.warning,
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

          // ================= RISK BANNER =================
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
                        Icons.vibration,
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
                            "Earthquake Risk: $_riskLabel",
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Ground Motion: ${_motion.toStringAsFixed(3)} g",
                            style: const TextStyle(color: Colors.white70),
                          ),
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
                ? const Center(
              child: Text("No Recent Earthquake Alerts"),
            )
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
                        Icons.warning,
                        color: Colors.white,
                      ),
                    ),
                    title: Text("Earthquake Risk: $lvl"),
                    subtitle: Text(
                      "Time: ${alert['timestamp']}",
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EarthquakeAlertDetailPage(
                            alert: alert,
                          ),
                        ),
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
