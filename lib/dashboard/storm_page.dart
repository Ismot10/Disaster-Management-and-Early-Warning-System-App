import 'dart:async';

import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/storm_realtime_service.dart';
import '../services/storm_alert_service.dart';
import '../services/storm_ai_service.dart';

import '../utils/notification_service.dart';
import 'storm_voice_alert.dart';

import 'storm_drawer.dart';
import 'storm_alert_detail_page.dart';

/// ===================== STORM + FUSION PAGE =====================
/// Keeps your features ✅
/// - MapTiler style selector (street/terrain/satellite)
/// - Settings icon opens endDrawer
/// - Risk banner shows Storm + Fusion + sensor summary
/// - Live alert feed (storm + fusion + AI)
/// - Cooldown alerts (no spam)
///
/// Adds safe improvements ✅
/// - Handles both onChildAdded + onChildChanged patterns (future-proof)
/// - Prevents duplicate fusion/live logs
/// - Prevents crashes from unexpected types
/// - Adds manual refresh button (optional but useful)

const String MAPTILER_KEY = "LvYR3jp1KitFbknow9TR";

class StormPage extends StatefulWidget {
  const StormPage({super.key});

  @override
  State<StormPage> createState() => _StormPageState();
}

class _StormPageState extends State<StormPage>
    with SingleTickerProviderStateMixin {
  // ================= SERVICES =================
  final _realtime = StormRealtimeService();
  final _alertService = StormAlertService();
  final _ai = StormAIService();

  StreamSubscription? _stormLatestSub;
  StreamSubscription? _fusionLatestSub;
  StreamSubscription? _fusionWindowSub;

  // ================= STATE (STORM) =================
  double _wind = 0.0;
  String _stormRisk = "Normal"; // Normal/Storm/Cyclone
  bool _cycloneDetected = false;

  // ================= STATE (FUSION) =================
  String _fusedEvent = "Normal"; // Cyclone+Flood, FloodLikely, StormOnly...
  String _fusedRisk = "Normal"; // Normal/Storm/Cyclone/HighRisk/Extreme
  String _floodRisk = "Low"; // Low/Medium/High/Critical
  int _rainP = 0;
  int _waterP = 0;
  double _distanceCm = 0.0;

  // ================= ALERT LIST =================
  final List<Map<String, dynamic>> _alerts = [];

  // Avoid duplicates when Firebase emits quickly
  String _lastFusionSignature = "";
  String _lastStormSignature = "";

  // ================= ALERT CONTROL =================
  DateTime? _lastAlertTime;
  final Duration alertCooldown = const Duration(minutes: 3);

  // ================= LIVE FEED THROTTLE =================
  DateTime _lastLiveLogTime = DateTime.fromMillisecondsSinceEpoch(0);

  // ================= MAP =================
  final LatLng _center = const LatLng(23.8103, 90.4125); // Dhaka reference
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

  // ================= COLORS =================
  // Keep same style as your Earthquake page
  final Map<String, Color> _riskColors = {
    "Normal": Colors.green,
    "Storm": Colors.orange,
    "Cyclone": Colors.red,

    // Fusion risks
    "HighRisk": Colors.deepOrange,
    "Extreme": Colors.red,

    // Flood-like labels (in case you use them)
    "Low": Colors.green,
    "Medium": Colors.orange,
    "High": Colors.deepOrange,
    "Critical": Colors.red,
  };

  Color _riskColor(String level) => _riskColors[level] ?? Colors.blueGrey;

  // ================= AI CONTROL =================
  bool _aiBusy = false;

  // ================= INIT =================
  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    StormVoiceAlertService.init();
    _ai.loadModel();

    _listenStormLatest();
    _listenFusionLatest();
    _listenFusionWindowForAI();
  }

  // ================= DISPOSE =================
  @override
  void dispose() {
    _stormLatestSub?.cancel();
    _fusionLatestSub?.cancel();
    _fusionWindowSub?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  // ================= SAFE CONVERTERS =================
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

  String _asString(dynamic v, [String fallback = ""]) {
    if (v == null) return fallback;
    return v.toString();
  }

  // ================= STORM LATEST =================
  void _listenStormLatest() {
    _stormLatestSub = _realtime.streamStormLatest().listen((latest) {
      if (latest == null) return;

      final wind = _asDouble(latest["wind_speed_mps"], 0.0);
      final risk = _asString(latest["risk_level"], "Normal");
      final cyclone = _asInt(latest["cyclone_detected"], 0) == 1;
      final ts = _asString(latest["timestamp"], "");

      // dedupe signature (prevents repeated same record spam in list)
      final sig = "$ts|$wind|$risk|$cyclone";
      if (sig == _lastStormSignature) {
        // still update UI if needed but don't spam list
        if (!mounted) return;
        setState(() {
          _wind = wind;
          _stormRisk = risk;
          _cycloneDetected = cyclone;
        });
        return;
      }
      _lastStormSignature = sig;

      if (!mounted) return;
      setState(() {
        _wind = wind;
        _stormRisk = risk;
        _cycloneDetected = cyclone;
      });

      // Live log (so list feels alive)
      _addLiveLogIfNeeded(ts);
    });
  }

  // ================= FUSION LATEST =================
  void _listenFusionLatest() {
    _fusionLatestSub = _realtime.streamFusionLatest().listen((latest) async {
      if (latest == null) return;

      final fusedEvent = _asString(latest["fused_event"], "Normal");
      final fusedRisk = _asString(latest["fused_risk"], "Normal");
      final floodRisk = _asString(latest["flood_risk"], "Low");

      final rain = _asInt(latest["rain_percent"], 0);
      final water = _asInt(latest["water_percent"], 0);
      final dist = _asDouble(latest["distance_cm"], 0.0);

      final wind = _asDouble(latest["wind_speed_mps"], _wind);
      final stormRiskFromFusion = _asString(latest["storm_risk"], _stormRisk);

      final ts = _asString(latest["timestamp"], "");

      // dedupe fusion signature
      final fusionSig =
          "$ts|$fusedEvent|$fusedRisk|$floodRisk|$rain|$water|$dist|$wind|$stormRiskFromFusion";
      if (fusionSig == _lastFusionSignature) {
        if (!mounted) return;
        setState(() {
          _fusedEvent = fusedEvent;
          _fusedRisk = fusedRisk;
          _floodRisk = floodRisk;
          _rainP = rain;
          _waterP = water;
          _distanceCm = dist;
          _wind = wind;
          _stormRisk = stormRiskFromFusion;
        });
        return;
      }
      _lastFusionSignature = fusionSig;

      if (!mounted) return;
      setState(() {
        _fusedEvent = fusedEvent;
        _fusedRisk = fusedRisk;
        _floodRisk = floodRisk;

        _rainP = rain;
        _waterP = water;
        _distanceCm = dist;

        // wind + storm risk also exist in fusion record
        _wind = wind;
        _stormRisk = stormRiskFromFusion;
      });

      // Add fusion alert entry (always updates list, but deduped)
      _addFusionAlertEntry(fusedEvent, fusedRisk, ts);

      // Trigger notifications/voice only for important risks (with cooldown)
      await _handleFusionAlertIfNeeded(fusedRisk, fusedEvent);
    });
  }

  // ================= FUSION WINDOW -> AI =================
  void _listenFusionWindowForAI() {
    _fusionWindowSub =
        _realtime.streamFusionLast10Window().listen((window) async {
          if (window.length < 10) return;
          if (_aiBusy) return;
          if (!_ai.isModelLoaded) return;

          _aiBusy = true;

          // Build input [10][4] in correct order
          final input = window.map((e) {
            final wind = _asDouble(e["wind_speed_mps"], 0.0);
            final rain = _asDouble(e["rain_percent"], 0.0);
            final water = _asDouble(e["water_percent"], 0.0);
            final dist = _asDouble(e["distance_cm"], 0.0);
            return [wind, rain, water, dist];
          }).toList(growable: false);

          final aiResult = await _ai.predictEventFromWindow(input);
          // aiResult example: {"event":"Cyclone+Flood","confidence":0.82}

          if (mounted && aiResult != null) {
            final event = _asString(aiResult["event"], "");
            final conf = _asDouble(aiResult["confidence"], 0.0);

            _addAIEventLog(event, conf);
          }

          _aiBusy = false;
        });
  }

  // ================= ALERT / NOTIFICATION =================
  Future<void> _handleFusionAlertIfNeeded(
      String fusedRisk, String fusedEvent) async {
    final bool shouldNotify =
        fusedRisk == "Extreme" || fusedRisk == "HighRisk" || _stormRisk == "Cyclone";

    if (!shouldNotify) return;

    final now = DateTime.now();
    if (_lastAlertTime != null &&
        now.difference(_lastAlertTime!) < alertCooldown) {
      return;
    }
    _lastAlertTime = now;

    await _alertService.pushStormFusionAlert(
      fusedEvent: fusedEvent,
      fusedRisk: fusedRisk,
      wind: _wind,
      rainPercent: _rainP,
      waterPercent: _waterP,
      distanceCm: _distanceCm,
      stormRisk: _stormRisk,
      floodRisk: _floodRisk,
    );

    NotificationService.showAlertNotification(
      "🌪️ Storm Fusion Alert",
      "$fusedEvent • Risk: $fusedRisk",
    );

    await StormVoiceAlertService.speakStormFusionAlert(fusedRisk, fusedEvent);
  }

  // ================= ALERT LIST HELPERS =================
  void _addFusionAlertEntry(String event, String risk, String ts) {
    final alert = {
      "type": "Fusion",
      "event": event,
      "level": risk,
      "timestamp": ts.isEmpty ? DateTime.now() : ts,
      "coords": _center,
      "wind": _wind,
      "rain": _rainP,
      "water": _waterP,
      "dist": _distanceCm,
      "stormRisk": _stormRisk,
      "floodRisk": _floodRisk,
    };

    if (!mounted) return;
    setState(() {
      _alerts.insert(0, alert);
      if (_alerts.length > 150) _alerts.removeLast();
    });
  }

  void _addAIEventLog(String event, double confidence) {
    if (event.isEmpty) return;

    final alert = {
      "type": "AI",
      "event": event,
      "level": "AI",
      "confidence": confidence,
      "timestamp": DateTime.now(),
      "coords": _center,
    };

    if (!mounted) return;
    setState(() {
      _alerts.insert(0, alert);
      if (_alerts.length > 150) _alerts.removeLast();
    });
  }

  void _addLiveLogIfNeeded(String ts) {
    final now = DateTime.now();
    if (now.difference(_lastLiveLogTime) < const Duration(seconds: 2)) return;
    _lastLiveLogTime = now;

    final alert = {
      "type": "Live",
      "level": _stormRisk,
      "timestamp": ts.isEmpty ? now : ts,
      "coords": _center,
      "wind": _wind,
      "stormRisk": _stormRisk,
    };

    if (!mounted) return;
    setState(() {
      _alerts.insert(0, alert);
      if (_alerts.length > 150) _alerts.removeLast();
    });
  }

  // Optional manual refresh: simply clears list spam and keeps UI clean
  void _softRefresh() {
    if (!mounted) return;
    setState(() {
      _alerts.clear();
      _lastFusionSignature = "";
      _lastStormSignature = "";
    });
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    // Main banner uses fusion risk if available, else storm risk
    final bannerLevel = (_fusedRisk != "Normal") ? _fusedRisk : _stormRisk;
    final color = _riskColor(bannerLevel);

    final showMarker = bannerLevel != "Normal";

    return Scaffold(
      endDrawer: const StormDrawer(),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Builder(
          builder: (context) => AppBar(
            backgroundColor: Colors.blueGrey,
            foregroundColor: Colors.white,
            centerTitle: true,
            title: const Text("Storm Prediction (Fusion)"),
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
                    if (v != null) setState(() => _mapStyle = v);
                  },
                ),
              ),

              // ✅ NEW (safe): quick clear button (does not change your core features)
              IconButton(
                tooltip: "Clear log",
                icon: const Icon(Icons.refresh),
                onPressed: _softRefresh,
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
                  userAgentPackageName: 'com.earlywarning.app',
                ),
                MarkerLayer(
                  markers: !showMarker
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

          // ================= RISK BANNER (STORM + FUSION) =================
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
                        Icons.cloud,
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
                            "Storm Risk: $_stormRisk",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Fusion: $_fusedEvent  (Risk: $_fusedRisk)",
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Wind: ${_wind.toStringAsFixed(2)} m/s • Rain: $_rainP% • Water: $_waterP% • Dist: ${_distanceCm.toStringAsFixed(1)} cm",
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Flood Risk: $_floodRisk",
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
                ? const Center(child: Text("No Recent Storm/Fusion Alerts"))
                : ListView.builder(
              itemCount: _alerts.length,
              itemBuilder: (ctx, i) {
                final alert = _alerts[i];
                final type = _asString(alert["type"], "Live");

                String title = "";
                String subtitle = "";
                IconData icon = Icons.warning;

                final level = _asString(alert["level"], "Normal");
                final c = _riskColor(level);

                if (type == "Fusion") {
                  icon = Icons.merge_type;
                  title = "Fusion: ${_asString(alert["event"], "Normal")}";
                  subtitle =
                  "Risk: ${_asString(alert["level"], "Normal")}\n"
                      "Wind: ${_asString(alert["wind"], "0")} m/s • "
                      "Rain: ${_asString(alert["rain"], "0")}% • "
                      "Water: ${_asString(alert["water"], "0")}%\n"
                      "Time: ${_asString(alert["timestamp"], "")}";
                } else if (type == "AI") {
                  icon = Icons.psychology;
                  final conf = _asDouble(alert["confidence"], 0.0);
                  title =
                  "AI Prediction: ${_asString(alert["event"], "")}";
                  subtitle =
                  "Confidence: ${(conf * 100).toStringAsFixed(1)}%\n"
                      "Time: ${_asString(alert["timestamp"], "")}";
                } else {
                  icon = Icons.cloud;
                  title =
                  "Storm Risk: ${_asString(alert["stormRisk"], _stormRisk)}";
                  subtitle =
                  "Wind: ${_asString(alert["wind"], "0")} m/s\n"
                      "Time: ${_asString(alert["timestamp"], "")}";
                }

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: c,
                      child: Icon(icon, color: Colors.white),
                    ),
                    title: Text(title),
                    subtitle: Text(subtitle),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StormAlertDetailPage(
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