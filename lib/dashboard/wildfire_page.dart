import 'package:flutter/material.dart';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../services/wildfire_ai_service.dart';
import '../services/wildfire_alert_service.dart';
import '../theme_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/notification_service.dart';
import 'package:flutter_tts/flutter_tts.dart'; // ✅ already imported
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/wildfire_realtime_service.dart';
import 'dart:async';

/// ---------------------- WILDFIRE PAGE ----------------------



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

  // map
  LatLng _center = const LatLng(23.8103, 90.4125);

  // animation
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
    )..repeat(reverse: true);

    _init();
  }

  Future<void> _init() async {
    await _ai.loadModel();
    _listenRealtime();
  }

  // ----------------------------------------------------
  // REALTIME SENSOR LISTENER
  // ----------------------------------------------------
  void _listenRealtime() {
    _subscription = _realtime.streamWildfireData().listen((records) async {
      if (records.isEmpty) return;

      // Run AI
      final risk = await _ai.predictWildfireRisk();
      final label = _riskLabelFromValue(risk);

      setState(() {
        _risk = risk;
        _riskLabel = label;
      });

      await _handleAlert(risk, label);
    });
  }

  // ----------------------------------------------------
  // ALERT LOGIC (cooldown + push)
  // ----------------------------------------------------
  Future<void> _handleAlert(double risk, String label) async {
    if (risk < 0.3) return;

    final now = DateTime.now();
    if (_lastAlertTime != null &&
        now.difference(_lastAlertTime!) < alertCooldown) return;

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

    _addAlert(label);
  }

  // ----------------------------------------------------
  // ALERT LIST
  // ----------------------------------------------------
  void _addAlert(String level) {
    final alert = {
      "type": "Wildfire",
      "level": level,
      "timestamp": DateTime.now(),
      "location": "Sensor Area",
      "coords": _center,
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

  Color _riskColor(String level) =>
      _riskColors[level] ?? Colors.grey;

  @override
  void dispose() {
    _subscription?.cancel();
    _pulseController.dispose();
    _ai.close();
    super.dispose();
  }

  // ====================================================
  // UI
  // ====================================================
  @override
  Widget build(BuildContext context) {
    final color = _riskColor(_riskLabel);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white, // ✅ makes title + icons white
        centerTitle: true,
        title: const Text("Wildfire Detection"),
        actions: [
          IconButton(
            icon: const Icon(Icons.map),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {},
          ),
        ],
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
                  urlTemplate:
                  "https://api.maptiler.com/maps/streets/{z}/{x}/{y}.png?key=LvYR3jp1KitFbknow9TR",
                  userAgentPackageName: 'com.example.app',
                ),
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
                          Icon(Icons.local_fire_department,
                              color: color, size: 34),
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
                            "Probability: ${(100 * _risk).toStringAsFixed(1)}%",
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),

          // ================= RISK METER =================
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

/// ---------------------- WILDFIRE ALERT DETAIL ----------------------
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
    }[alert['level']]!;

    final LatLng? coords = alert['coords'] as LatLng?;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Wildfire Alert Detail"),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                alert['level'] as String,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 26,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                alert['message'] as String,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Location: ${alert['location']}",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Time: ${formatDateTime(alert['timestamp'] as DateTime)}",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),

              const SizedBox(height: 20),

              // Mini map for this alert (if coords present)
              if (coords != null) ...[
                SizedBox(
                  height: 200,
                  child: FlutterMap(
                    options: MapOptions(initialCenter: coords, initialZoom: 11),
                    children: [
                      TileLayer(
                        urlTemplate:
                            "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                        subdomains: const ['a', 'b', 'c'],
                        userAgentPackageName: 'com.earlywarning.app',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: coords,
                            width: 36,
                            height: 36,
                            child: Icon(
                              Icons.location_on,
                              color: color,
                              size: 34,
                            ),
                          ),
                        ],
                      ),
                      RichAttributionWidget(
                        attributions: [
                          TextSourceAttribution(
                            '© OpenStreetMap contributors',
                            onTap: null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              const Text(
                "In future this will include sensor data (rain level, soil moisture, water level, GPS).",
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------- SETTINGS PAGE ----------------------
class WildfireSettingsPage extends StatefulWidget {
  const WildfireSettingsPage({super.key});

  @override
  State<WildfireSettingsPage> createState() => _WildfireSettingsPageState();
}

class _WildfireSettingsPageState extends State<WildfireSettingsPage> {
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
            subtitle: const Text("Receive alerts for wildfire warnings"),
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
                backgroundColor: Colors.red,
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

// LOCATION PAGE.....................................................................

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
                      "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: 'com.earlywarning.app',
                ),
                MarkerLayer(markers: markers),
                RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution(
                      '© OpenStreetMap contributors',
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
