import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/flood_ai_service.dart';
import '../services/location_service.dart';
import '../theme_notifier.dart';
import '../utils/notification_service.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import '../services/realtime_database_service.dart';



const double SENSOR_HEIGHT_CM = 100.0; // sensor mounted height from riverbed
const double FLOOD_DISTANCE_CM = 20.0; // distance from sensor considered dangerous


const String MAPTILER_KEY = "LvYR3jp1KitFbknow9TR";

class FloodPage extends StatefulWidget {
    const FloodPage({super.key});

    @override
    State<FloodPage> createState() => _FloodPageState();
  }




class _FloodPageState extends State<FloodPage> with SingleTickerProviderStateMixin {

  // 🔹 AI buffer + service (MOVE HERE)
  final List<List<double>> _last10 = [];
  final FloodAIService _ai = FloodAIService();

  final RealtimeDatabaseService _realtimeDB = RealtimeDatabaseService();


  LatLng? _userCoords;   // ✅ ADD THIS HERE

  final Random _rnd = Random();
  Timer? _timer;
  StreamSubscription<DatabaseEvent>? _sensorSubscription;

  final List<Map<String, dynamic>> _alerts = [];
  DateTime _lastUpdated = DateTime.now();

  final Map<String, Color> _riskColors = {
    'Low': Colors.green,
    'Medium': Colors.orange,
    'High': Colors.deepOrange,
    'Critical': Colors.red,
  };

  String _riskLevel = 'Low';
  double? _predictedWL; // <-- ADD IT HERE

  final Map<String, LatLng> _locationsCoords = {
    "Dhaka": LatLng(23.8103, 90.4125),
    "Chittagong": LatLng(22.3569, 91.7832),
    "Sylhet": LatLng(24.8949, 91.8687),
    "Khulna": LatLng(22.8456, 89.5403),
    "Rajshahi": LatLng(24.3745, 88.6042),
  };

  final FlutterTts _flutterTts = FlutterTts();
  Map<String, dynamic> _currentData = {
    'water_level_cm': 0.0,
    'rain_intensity_percent': 0,
    'water_sensor_percent': 0,
    'cause': 'Normal',



};

  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  // map style
  String _mapStyle = "streets";
  String get _mapTilerURL {
    switch (_mapStyle) {
      case "terrain":
        return "https://api.maptiler.com/maps/terrain/{z}/{x}/{y}.png?key=$MAPTILER_KEY";
      case "satellite":
        return "https://api.maptiler.com/maps/hybrid/{z}/{x}/{y}.jpg?key=$MAPTILER_KEY";
      default:
        return "https://api.maptiler.com/maps/streets/{z}/{x}/{y}.png?key=$MAPTILER_KEY";
    }
  }

  @override
  void initState() {
    super.initState();

    _initializeTTS();
    _listenToRealtimeSensorData();
    _initLocation();

    // Load AI model asynchronously
    _ai.loadModel().then((_) {
      debugPrint("AI model ready: ${_ai.isModelLoaded}");
    });

    // periodic official API fetch but keep it light
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _safeFetchFloodData());

    // animation for pulse
    _animationController =
    AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initLocation() async {
    final coords = await LocationService.getCurrentLocation();
    if (coords != null && mounted) {
      setState(() {
        _userCoords = coords;   // <-- SAVES the value correctly
      });

    }
  }

  @override
  void dispose() {
    _sensorSubscription?.cancel();
    _timer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initializeTTS() async {
    try {
      await _flutterTts.awaitSpeakCompletion(true);
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      await _flutterTts.stop();

      // Check whether language is available (returns 1 on some platforms)
      try {
        final langAvailable = await _flutterTts.isLanguageAvailable("en-US");
        debugPrint("TTS isLanguageAvailable returned: $langAvailable");
      } catch (e) {
        // Some platforms may throw; we swallow and continue - real device may still work
        debugPrint("TTS availability check failed: $e");
      }
    } catch (e) {
      debugPrint("TTS init error: $e");
    }
  }

  Future<void> _speakFloodAlert(String location, String level) async {
    final player = AudioPlayer();
    String message;
    switch (level) {
      case 'Critical':
        message = "Alert! Emergency! Flood detected in $location. Critical risk level! Move immediately!";
        break;
      case 'High':
        message = "Warning! Flood detected in $location. High risk level! Take action!";
        break;
      case 'Medium':
        message = "Caution! Flood risk detected in $location. Medium level. Be prepared!";
        break;
      default:
        message = "Flood risk in $location is low. Be aware!";
    }

   // try play siren in assets/sounds/siren.mp3 (optional). if fails continue to TTS.
    try {
      await player.play(AssetSource('sounds/siren.mp3'));
    } catch (e) {
      debugPrint("AudioAsset play failed (ignored): $e");
    }

    // small pause then tts
    await Future.delayed(const Duration(seconds: 1));
    try {
      await _flutterTts.stop();
      await _flutterTts.speak(message);
    } catch (e) {
      debugPrint("TTS speak failed: $e");
    }
  }

  void _addAlert(Map<String, dynamic> alert) {
    // dedupe recent identical alerts within 1 minute for same location+level
    final exists = _alerts.any((a) =>
    a['location'] == alert['location'] &&
        a['level'] == alert['level'] &&
        (DateTime.now().difference(a['timestamp'] as DateTime).inMinutes < 1));
    if (!exists) {
      setState(() {
        _alerts.insert(0, alert);
        _lastUpdated = DateTime.now();

        // 🧪 Debug line — shows risk level and assigned color
        debugPrint("🟢 Added alert with level: ${alert['level']} "
            "-> color: ${_riskColors[alert['level']]}");
      });
    }
  }

  /// Robust RTDB listener that handles 'map of child nodes' structure
  // Add this at the top of your class
  DateTime? _lastTTSTime; // stores the last time TTS was triggered
  final Duration ttsCooldown = const Duration(minutes: 5); // adjust cooldown

  void _listenToRealtimeSensorData() {
    final dbRef = FirebaseDatabase.instance.ref("floodData").limitToLast(1);

    _sensorSubscription = dbRef.onValue.listen((event) async {
      if (!mounted) return;
      final snapshotValue = event.snapshot.value;
      if (snapshotValue == null) return;

      Map<String, dynamic> data = {};
      try {
        if (snapshotValue is Map) {
          final entries = snapshotValue.entries.toList();
          final last = entries.isNotEmpty ? entries.last.value : null;
          if (last is Map) data = Map<String, dynamic>.from(last);
        }
      } catch (e) {
        debugPrint("Error parsing RTDB snapshot: $e");
        return;
      }

      // Parse sensor values safely
      final double waterLevel = _toDoubleSafe(data['water_level_cm']);
      final int rain = _toIntSafe(data['rain_intensity_percent']);
      final int water = _toIntSafe(data['water_sensor_percent']);

      final double distanceFromSensor = _toDoubleSafe(data['water_level_cm']);
      final double actualWaterLevel = SENSOR_HEIGHT_CM - distanceFromSensor;



      // 🔍 DEBUG: raw sensor values
      debugPrint("RAW values: wl=$waterLevel rain=$rain water=$water");

      // Normalize risk from DB
      String dbRisk = (data['risk_level']?.toString() ?? 'Low').trim();
      dbRisk = dbRisk[0].toUpperCase() + dbRisk.substring(1).toLowerCase();

      String cause = "Normal";
      if (rain > 80) {
        cause = "Heavy Rainfall";
      } else if (water > 80) {
        cause = "High Groundwater Level";
      } else if (waterLevel > 80) {
        cause = "River Overflow";
      }


      // Update UI
      setState(() {
        _currentData = {
          'water_level_cm': waterLevel,
          'rain_intensity_percent': rain,
          'water_sensor_percent': water,
          'cause': cause,
        };
        _riskLevel = dbRisk; // DB risk only
        _lastUpdated = data['timestamp'] != null
            ? (DateTime.tryParse(data['timestamp'].toString()) ?? DateTime.now())
            : DateTime.now();
      });


      // Run AI prediction
      double? predictedWL;
      bool floodSoonByAI = false;

      if (_ai.isModelLoaded) {
        try {
          predictedWL = await _ai.predictFutureWaterLevel();

          if (!mounted) return;

          setState(() {
            _predictedWL = predictedWL;
          });

          // AI output is NORMALIZED DISTANCE (0–1)
          final double predictedDistance = predictedWL * SENSOR_HEIGHT_CM;

// FLOOD SOON if water is CLOSE to sensor
          floodSoonByAI = predictedDistance <= FLOOD_DISTANCE_CM;



          debugPrint(
              "🧠 AI decision → predictedDistance=$predictedDistance cm, "
                  "floodSoon=$floodSoonByAI"
          );

          // ✅ WRITE AI ALERT TO FIREBASE
          if (floodSoonByAI) {
            // Push structured alert to /alerts
            await _realtimeDB.pushAlert(
              disasterType: "flood",
              severity: "high",
              title: "⚠️ Flood Warning",
              message: "Flood likely in 20–30 minutes. Please prepare.",
              predictedDistance: predictedDistance,
              predictedMinutes: 25,
              location: "Your area",
              source: "flutter_ai",
              sendEmail: true,
            );

            // 2️⃣ SHOW APP NOTIFICATION
            NotificationService.showAlertNotification(
                "⚠️ Flood Warning",
                "Flood likely in 20–30 minutes. Please prepare!"
            );


            // 3️⃣ SPEAK TTS ALERT
            _speakFloodAlert("Your area", "High");
          }


        } catch (e) {
          debugPrint("❌ AI prediction failed: $e");
        }
      }



      // Determine if flood exists
      final bool flood = (
          data['flood_detected'] == 1 ||
              data['flood_detected'] == true ||
              data['flood_detected'] == '1'
      );

      // Create alert data
      final offsetLat = (_rnd.nextDouble() - 0.5) / 200;
      final offsetLng = (_rnd.nextDouble() - 0.5) / 200;
      final defaultCoords = _locationsCoords["Dhaka"] ?? LatLng(23.8103, 90.4125);
      final sensorCoords = LatLng(defaultCoords.latitude + offsetLat, defaultCoords.longitude + offsetLng);

      final newAlert = {
        'type': 'Flood',
        'level': _riskLevel,
        'location': "Sensor Station",
        'message': "Water Level: ${waterLevel.toStringAsFixed(1)} cm | Rain: $rain% | Water: $water%",
        'timestamp': DateTime.now(),
        'coords': sensorCoords,
        'source': 'sensor',
        'sensorData': Map<String, dynamic>.from(_currentData),
      };

      _addAlert(newAlert); // TTS removed

      // ✅ TTS only if DB risk is Critical AND AI predicts high water AND cooldown passed
      if (floodSoonByAI) {
        final now = DateTime.now();
        if (_lastTTSTime == null || now.difference(_lastTTSTime!) >= ttsCooldown) {
          _speakFloodAlert("Your area", "High");
          _lastTTSTime = now;
        }
      }


    }, onError: (err) {
      debugPrint("RTDB listener error: $err");
    });
  }



  double _toDoubleSafe(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }




  int _toIntSafe(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  /// ---------------- Official API fetch (off main thread parse) ----------------
  Future<void> _safeFetchFloodData() async {
    try {
      // ✅ correct endpoint
      final response = await http
          .get(Uri.parse('https://api3.ffwc.gov.bd/data_load/stations-2025/'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final List<Map<String, dynamic>> parsed =
        await compute(_parseStationsFromBody, response.body);

        for (final stationMap in parsed) {
          final level = stationMap['risk_level'] as String? ?? 'Low';
          final location = stationMap['name'] as String? ?? 'Unknown';
          final lat = stationMap['latitude'] as double? ?? 23.6850;
          final lng = stationMap['longitude'] as double? ?? 90.3563;
          final coords = LatLng(lat, lng);

          final newAlert = {
            'type': 'Flood',
            'level': level,
            'location': location,
            'message': 'Flood risk level: $level',
            'timestamp': DateTime.now(),
            'coords': coords,
            'source': 'official',
          };
          _addAlert(newAlert);

          if (level == 'High' || level == 'Critical') {
            _speakFloodAlert(location, level);
          }
        }
      } else {
        debugPrint("fetchFloodData: HTTP ${response.statusCode}");
      }
    } catch (e) {
      debugPrint('Error fetching flood data: $e');
    }
  }


  // top-level/background parser for compute()
  static List<Map<String, dynamic>> _parseStationsFromBody(String body) {
    try {
      final decoded = jsonDecode(body);
      // ✅ FIX: The FFWC API uses 'data' not 'stations'
      final list = (decoded is Map && decoded['data'] is Iterable)
          ? decoded['data'] as Iterable
          : [];

      final stations = <Map<String, dynamic>>[];
      for (var s in list) {
        try {
          final name = s['name']?.toString() ?? 'Unknown';
          final risk = s['risk_level']?.toString() ?? 'Low';
          final lat = double.tryParse(s['latitude'].toString()) ?? 23.6850;
          final lng = double.tryParse(s['longitude'].toString()) ?? 90.3563;
          stations.add({
            'name': name,
            'risk_level': risk,
            'latitude': lat,
            'longitude': lng,
          });
        } catch (_) {
          // skip station on parse error
        }
      }
      return stations;
    } catch (e) {
      debugPrint('Parse error: $e');
    }
    return <Map<String, dynamic>>[];
  }



  String formatDateTime(DateTime dt) {
    return "${dt.hour}:${dt.minute.toString().padLeft(2, '0')} — ${dt.year}-${dt.month}-${dt.day}";
  }

  @override
  Widget build(BuildContext context) {
    final color = _riskColors[_riskLevel] ?? Colors.grey;

    final now = DateTime.now();


    final predictedCm = _predictedWL != null ? _predictedWL! * 100 : null;


    final alertMarkers = _alerts.asMap().entries.map((entry) {
      final i = entry.key;
      final alert = entry.value;
      final LatLng? pos = alert['coords'] as LatLng?;
      final c = _riskColors[alert['level']] ?? Colors.blue;

      final timestamp = alert['timestamp'] as DateTime;
      final ageMinutes = now.difference(timestamp).inMinutes;
      final opacity = (1.0 - (ageMinutes / 15.0)).clamp(0.3, 1.0);

      // 🌟 Latest alert
      final isLatest = i == 0;
      return Marker(
        point: pos ?? LatLng(23.8103, 90.4125),
        width: 70, // make room for double ring
        height: 70,
      child: isLatest
          ? Stack(
        alignment: Alignment.center,
        children: [
          // Outer slow pulsing ring
          ScaleTransition(
            scale: _pulseAnimation, // ✅ use your existing animation
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.withOpacity(0.25),
              ),
            ),
          ),

          // Inner faster pulsing ring — use the controller directly
          ScaleTransition(
            scale: Tween<double>(begin: 1.0, end: 1.2).animate(
              CurvedAnimation(
                parent: _animationController, // ✅ FIXED here
                curve: Curves.easeInOut,
              ),
            ),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.withOpacity(0.4),
              ),
            ),
          ),

          // Center alert icon
          Icon(
            alert['source'] == 'official' ? Icons.location_on : Icons.adjust,
            color: c.withOpacity(opacity),
            size: 34,
          ),
        ],
      )
          : Icon(
        alert['source'] == 'official' ? Icons.location_on : Icons.adjust,
        color: c.withOpacity(opacity),
        size: 34,
      ),

      );
    }).toList();



    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Builder( // ✅ ensures Scaffold context is correct for drawer
          builder: (context) => AppBar(
            backgroundColor: Colors.blue,
            title: const Text(
              "Flood Detection",
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
            centerTitle: true,
            actions: [
              Row(
                children: [
                  // 👇 Icon-only dropdown button
                  DropdownButtonHideUnderline(
                    child: DropdownButton2<String>(
                      value: _mapStyle,
                      customButton: const Icon(Icons.map, color: Colors.white),

                      dropdownStyleData: DropdownStyleData(
                        maxHeight: 200,
                        width: 200, // ✅ this now controls the dropdown width
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        offset: const Offset(-80, 10), // ✅ aligns below the icon
                      ),

                      isExpanded: true, // ✅ keeps text in one line

                      menuItemStyleData: const MenuItemStyleData(
                        height: 45,
                        padding: EdgeInsets.symmetric(horizontal: 12),
                      ),

                      items: const [
                        DropdownMenuItem(
                          value: "streets",
                          child: Text(
                            "Street",
                            style: TextStyle(fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        DropdownMenuItem(
                          value: "terrain",
                          child: Text(
                            "Terrain",
                            style: TextStyle(fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        DropdownMenuItem(
                          value: "satellite",
                          child: Text(
                            "Satellite",
                            style: TextStyle(fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],

                      onChanged: (val) {
                        if (val != null) setState(() => _mapStyle = val);
                      },
                    ),
                  ),


                  IconButton(
                    icon: const Icon(Icons.settings, color: Colors.white),
                    tooltip: 'Menu',
                    onPressed: () {
                      Scaffold.of(context).openEndDrawer(); // ✅ drawer opens
                    },
                  ),
                ],
              ),
              const SizedBox(width: 8), // right padding
            ],
          ),
        ),
      ),

      endDrawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              height: 90,
              color: Colors.deepPurple,
              alignment: Alignment.center,
              child: const Text(
                'Menu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.location_on, color: Colors.red),
              title: const Text("My Locations"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LocationsPage()),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.blue),
              title: const Text("Settings"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const FloodSettingsPage(),
                  ),
                );
              },
            ),
          ],
        ),
      ),

      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {

            return ConstrainedBox(
              constraints: BoxConstraints(maxHeight: constraints.maxHeight),
              child: Column(
                children: [
                  // --- MAP SECTION (fixed height + center) ---
                  SizedBox(
                    height: 250,
                    child: FlutterMap(
                      options: MapOptions(
                        // make sure map has an initial center and zoom
                        initialCenter: _userCoords ?? LatLng(23.6850, 90.3563),

                        initialZoom: 6.5,
                        onTap: (tapPos, latLng) {
                          // optional tap handler
                          // print("Tapped at: $latLng");
                        },
                        maxZoom: 18.0,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: _mapTilerURL,
                          userAgentPackageName: 'com.example.flooddetection',
                        ),
                        MarkerLayer(markers: alertMarkers),
                      ],
                    ),
                  ),

                  // --- RISK BANNER (intrinsic height) ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Card(
                      elevation: 5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            colors: [
                              color.withOpacity(0.9),
                              color.withOpacity(0.6),
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.white,
                              child: Icon(Icons.water_drop, color: color, size: 30),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Flood Risk: $_riskLevel",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                        color: Colors.white),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    predictedCm != null
                                        ? "Predicted water level: ${predictedCm.toStringAsFixed(1)} cm"
                                        : "Predicted water level: --",
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

                  // --- ALERTS LIST (fills remaining space and scrolls) ---
                  Expanded(
                    child: _alerts.isEmpty
                        ? const Center(child: Text("No Recent Alerts"))
                        : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 12),
                      itemCount: _alerts.length,
                      itemBuilder: (ctx, i) {
                        final alert = _alerts[i];
                        final c = _riskColors[alert['level']] ?? Colors.grey;
                        final timestamp = alert['timestamp'] is DateTime
                            ? alert['timestamp'] as DateTime
                            : DateTime.now();
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              splashColor: c.withOpacity(0.2),
                              highlightColor: c.withOpacity(0.1),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: c,
                                child: Icon(
                                  alert['source'] == 'official'
                                      ? Icons.location_on
                                      : Icons.adjust,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(alert['message'] ?? ''),
                              subtitle: Text(
                                "Location: ${alert['location'] ?? 'Unknown'}\n"
                                    "Time: ${formatDateTime(timestamp)}",
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        FloodAlertDetailPage(alert: alert),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      }

                        ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );



        }
}


        /// ---------------------- FLOOD ALERT DETAIL ----------------------
class FloodAlertDetailPage extends StatelessWidget {
    final Map<String, dynamic> alert;
    const FloodAlertDetailPage({super.key, required this.alert});

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
          title: const Text("Flood Alert Detail"),
          backgroundColor: Colors.blue,
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
              Text("Water Level: ${sensor['water_level_cm']} cm"),
              Text("Rain Intensity: ${sensor['rain_intensity_percent']}%"),
              Text("Water Sensor: ${sensor['water_sensor_percent']}%"),
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
/// ---------------------- SETTINGS PAGE ----------------------
class FloodSettingsPage extends StatefulWidget {
    const FloodSettingsPage({super.key});

    @override
    State<FloodSettingsPage> createState() => _FloodSettingsPageState();
  }

class _FloodSettingsPageState extends State<FloodSettingsPage> {
    bool _notificationsEnabled = true;

    @override
    void initState() {
      super.initState();
      _loadSettings(); // ✅ Load user preferences when page opens
    }

    Future<void> _loadSettings() async {
      final enabled = await NotificationService.isNotificationEnabled();
      setState(() => _notificationsEnabled = enabled);
    }

    Future<void> _saveSettings() async {
      await NotificationService.setNotificationEnabled(_notificationsEnabled);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Settings saved successfully!")),
      );
      Navigator.pop(context);
    }

    @override
    Widget build(BuildContext context) {
      final themeNotifier = Provider.of<ThemeNotifier>(context);
      final isDark = themeNotifier.isDark;

      return Scaffold(
        appBar: AppBar(
          title: const Text("Settings", style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.deepPurple,
        ),
        body: ListView(
          children: [
            // ✅ Notifications toggle
            SwitchListTile(
              title: const Text("Enable Notifications"),
              subtitle: const Text("Receive alerts for flood warnings"),
              value: _notificationsEnabled,
              onChanged: (val) {
                setState(() {
                  _notificationsEnabled = val;
                });
              },
            ),

            const Divider(),

            // ✅ Theme switch (Light / Dark)
            ListTile(
              title: const Text("Theme"),
              subtitle: Text(isDark ? "Dark" : "Light"),
              trailing: Switch(
                value: isDark,
                onChanged: (val) {
                  themeNotifier.toggleTheme(val); // instantly change + save
                },
              ),
            ),

            const Divider(),

            // ✅ Save button
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.save, color: Colors.white),
                label: const Text(
                  "Save Settings",
                  style: TextStyle(color: Colors.white),
                ),
                onPressed: _saveSettings,
              ),
            ),
          ],
        ),
      );
    }
  }

// LOCATION PAGE.................................................................

class LocationsPage extends StatefulWidget {
    const LocationsPage({super.key});

    @override
    State<LocationsPage> createState() => _LocationsPageState();
  }

class _LocationsPageState extends State<LocationsPage> {
    List<String> _locations = [];
    final TextEditingController _controller = TextEditingController();
    final FirebaseFirestore _firestore = FirebaseFirestore.instance;

    // 🔹 Known coordinates for major Bangladesh cities
    final Map<String, LatLng> _cityCoords = {
      "Dhaka": LatLng(23.8103, 90.4125),
      "Chittagong": LatLng(22.3569, 91.7832),
      "Sylhet": LatLng(24.8949, 91.8687),
      "Khulna": LatLng(22.8456, 89.5403),
      "Rajshahi": LatLng(24.3745, 88.6042),
      "Barisal": LatLng(22.7010, 90.3535),
      "Rangpur": LatLng(25.7439, 89.2752),
    };

    @override
    void initState() {
      super.initState();
      _loadLocations();
    }

    /// 🔹 Load locations (Firestore first, fallback to SharedPreferences)
    Future<void> _loadLocations() async {
      try {
        final doc = await _firestore
            .collection('user_locations')
            .doc('default_user')
            .get();

        if (doc.exists &&
            doc.data() != null &&
            doc.data()!['locations'] != null) {
          setState(() {
            _locations = List<String>.from(doc['locations']);
          });
        } else {
          // If no data in Firestore, load from SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          final saved = prefs.getStringList('locations');
          setState(() {
            _locations = saved ?? ["Dhaka", "Chittagong"];
          });
        }
      } catch (e) {
        debugPrint("Error loading locations: $e");
        // fallback to local
        final prefs = await SharedPreferences.getInstance();
        final saved = prefs.getStringList('locations');
        setState(() {
          _locations = saved ?? ["Dhaka", "Chittagong"];
        });
      }
    }

    /// 🔹 Save locations both locally and to Firestore
    Future<void> _saveLocations() async {
      // Local save
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('locations', _locations);

      // Cloud save
      try {
        await _firestore.collection('user_locations').doc('default_user').set({
          'locations': _locations,
        });
      } catch (e) {
        debugPrint("Error saving to Firestore: $e");
      }
    }

    void _addLocation(String loc) {
      if (loc.isNotEmpty && !_locations.contains(loc)) {
        setState(() {
          _locations.add(loc);
        });
        _saveLocations(); // ✅ sync both
        _controller.clear();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$loc added successfully')));
      } else if (_locations.contains(loc)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$loc already exists')));
      }
    }

    void _removeLocation(int index) {
      final removed = _locations[index];
      setState(() {
        _locations.removeAt(index);
      });
      _saveLocations(); // ✅ sync both
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$removed removed')));
    }

    @override
    Widget build(BuildContext context) {
      // 🔹 Generate markers for saved locations
      final markers = _locations
          .map((loc) {
            final coords = _cityCoords[loc];
            if (coords == null) return null;
            return Marker(
              point: coords,
              width: 36,
              height: 36,
              child: const Icon(Icons.location_on, color: Colors.red, size: 34),
            );
          })
          .whereType<Marker>()
          .toList();

      return Scaffold(
        appBar: AppBar(
          title: const Text(
            "My Locations",
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.deepPurple,
        ),
        body: Column(
          children: [
            // 🔹 Map with markers
            SizedBox(
              height: 250,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(23.6850, 90.3563),
                  initialZoom: 6.5,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                    "https://api.maptiler.com/maps/streets/{z}/{x}/{y}.png?key=$MAPTILER_KEY",
                    additionalOptions: const {
                      'attribution': '© MapTiler © OpenStreetMap contributors',
                    },
                    userAgentPackageName: 'com.example.app',
                  ),

                  MarkerLayer(markers: markers),
                  RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution(
                        '© MapTiler © OpenStreetMap contributors',
                        onTap: null,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Divider(),

            // 🔹 Saved locations list
            Expanded(
              child: _locations.isEmpty
                  ? const Center(child: Text("No saved locations yet."))
                  : ListView.builder(
                      itemCount: _locations.length,
                      itemBuilder: (ctx, i) {
                        return ListTile(
                          leading: const Icon(
                            Icons.location_on,
                            color: Colors.red,
                          ),
                          title: Text(_locations[i]),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.grey),
                            onPressed: () => _removeLocation(i),
                          ),
                        );
                      },
                    ),
            ),

            // 🔹 Add new location field
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: "Enter new location",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                    ),
                    onPressed: () => _addLocation(_controller.text.trim()),
                    child: const Text(
                      "Add",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }





