import 'package:flutter/material.dart';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../theme_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/notification_service.dart';
import 'package:flutter_tts/flutter_tts.dart'; // ✅ already imported
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;

import 'dart:async';
import 'package:html/parser.dart' as htmlParser;

/// ---------------------- STORM PAGE ----------------------

class StormPage extends StatefulWidget {
  const StormPage({super.key});

  @override
  State<StormPage> createState() => _StormPageState();
}

class _StormPageState extends State<StormPage> {
  final Random _rnd = Random();
  Timer? _timer; // Timer for auto-refresh

  final List<Map<String, dynamic>> _alerts = [];
  DateTime _lastUpdated = DateTime.now();

  final Map<String, Color> _riskColors = {
    'Low': Colors.green,
    'Medium': Colors.orange,
    'High': Colors.deepOrange,
    'Critical': Colors.red,
  };

  String _riskLevel = 'Low';

  // Example coordinates for Bangladesh cities
  final Map<String, LatLng> _locationsCoords = {
    "Dhaka": LatLng(23.8103, 90.4125),
    "Chittagong": LatLng(22.3569, 91.7832),
    "Sylhet": LatLng(24.8949, 91.8687),
    "Khulna": LatLng(22.8456, 89.5403),
    "Rajshahi": LatLng(24.3745, 88.6042),
  };

  // 🔊 TTS setup
  final FlutterTts _flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _initializeTTS();
    fetchStormData(); // Initial fetch
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      fetchStormData(); // Auto-refresh every 1 min
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _initializeTTS() async {
    await _flutterTts.awaitSpeakCompletion(true);
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.6);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.3);

    // Force init on Android emulator
    await _flutterTts.speak("Text to speech engine initialized.");
    await _flutterTts.stop();
  }

  // 🔊 Helper: Speak alert with siren
  Future<void> _speakStormAlert(String location, String level) async {
    final player = AudioPlayer();
    String message;
    switch (level) {
      case 'Critical':
        message =
            "⚠️ Alert! Emergency! Storm risk predicted in $location. Critical risk level!";
        break;
      case 'High':
        message =
            "⚠️ Warning! Storm risk predicted in $location. High risk level!";
        break;
      case 'Medium':
        message = "Caution! Storm risk predicted in $location. Medium level.";
        break;
      default:
        message = "Storm risk in $location is low.";
    }

    // 🚨 Play the siren first
    await player.play(AssetSource('sounds/siren.mp3'));

    // Wait 2 seconds, then speak
    await Future.delayed(const Duration(seconds: 2));

    await _flutterTts.stop(); // stop any ongoing speech
    await _flutterTts.speak(message);
  }

  /// Add alert to list safely
  void _addAlert(Map<String, dynamic> alert) {
    final exists = _alerts.any(
      (a) =>
          a['location'] == alert['location'] &&
          a['timestamp'] == alert['timestamp'] &&
          a['level'] == alert['level'],
    );

    if (!exists) {
      setState(() {
        _alerts.insert(0, alert);
        _alerts.sort(
          (a, b) => (b['timestamp'] as DateTime).compareTo(
            a['timestamp'] as DateTime,
          ),
        );
        _lastUpdated = DateTime.now();
      });
    }
  }

  /// Fetch official storm data
  Future<void> fetchStormData() async {
    try {
      final response = await http.get(
        Uri.parse('https://live6.bmd.gov.bd/p/Signals'),
      );

      if (response.statusCode == 200) {
        final document = htmlParser.parse(response.body);

        // Select all tables (BMD may have multiple tables for regions)
        final tables = document.querySelectorAll('table');

        for (var table in tables) {
          // Get all table rows (skip header)
          final rows = table.querySelectorAll('tbody tr');

          for (var row in rows) {
            final location = row.querySelector('td:nth-child(1)')?.text.trim();
            final level = row.querySelector('td:nth-child(2)')?.text.trim();

            if (location == null || level == null) continue;

            final coords =
                _locationsCoords[location] ?? LatLng(23.8103, 90.4125);

            final newAlert = {
              'type': 'Storm',
              'level': level,
              'location': location,
              'message': 'Storm risk level: $level',
              'timestamp': DateTime.now(),
              'coords': coords,
              'source': 'official',
            };

            _addAlert(newAlert);

            // Speak only high/critical
            if (level == 'High' || level == 'Critical') {
              await _speakStormAlert(location, level);
            }
          }
        }

        setState(() {
          _lastUpdated = DateTime.now();
        });

        print('All storm data updated successfully.');
      } else {
        print('Failed to load storm data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching storm data: $e');
    }
  }

  /// Simulate and save to Firestore
  Future<void> _simulateStormAlert() async {
    final score = _rnd.nextDouble();
    if (score < 0.3) {
      _riskLevel = 'Low';
    } else if (score < 0.6) {
      _riskLevel = 'Medium';
    } else if (score < 0.85) {
      _riskLevel = 'High';
    } else {
      _riskLevel = 'Critical';
    }

    final now = DateTime.now();

    final location = _locationsCoords.keys.elementAt(
      _rnd.nextInt(_locationsCoords.length),
    );

    final newAlert = {
      'type': 'Storm',
      'level': _riskLevel,
      'location': location,
      'message': 'Storm risk level: $_riskLevel',
      'timestamp': now,
      'coords': _locationsCoords[location],
      'source': 'simulated',
    };

    _addAlert(newAlert);

    await FirebaseFirestore.instance.collection("alerts").add({
      "type": "Storm",
      "level": _riskLevel,
      "location": location,
      "message": "Storm risk level: $_riskLevel",
      "timestamp": FieldValue.serverTimestamp(),
      "coords": {
        "lat": _locationsCoords[location]!.latitude,
        "lng": _locationsCoords[location]!.longitude,
      },
    });

    // 🔊 Speak alert
    await _speakStormAlert(location, _riskLevel);
  }

  String formatDateTime(DateTime dt) {
    return "${dt.hour}:${dt.minute.toString().padLeft(2, '0')} — ${dt.year}-${dt.month}-${dt.day}";
  }

  @override
  Widget build(BuildContext context) {
    final color = _riskColors[_riskLevel] ?? Colors.grey;

    // markers for alerts (main map)
    final alertMarkers = _alerts.map((alert) {
      final LatLng? pos = alert['coords'] as LatLng?;
      final c = _riskColors[alert['level']] ?? Colors.blueGrey;

      return Marker(
        point: pos ?? LatLng(23.8103, 90.4125),
        width: 36,
        height: 36,
        child: Icon(
          alert['source'] == 'official' ? Icons.location_on : Icons.adjust,
          color: c,
          size: 34,
        ),
      );
    }).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueGrey,
        title: const Text(
          "Storm Prediction",
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.settings, color: Colors.white),
              onPressed: () {
                Scaffold.of(context).openEndDrawer();
              },
            ),
          ),
        ],
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
              leading: const Icon(Icons.settings, color: Colors.blueGrey),
              title: const Text("Settings"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StormSettingsPage()),
                );
              },
            ),
          ],
        ),
      ),

      body: Column(
        children: [
          Expanded(
            flex: 2,
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
                MarkerLayer(markers: alertMarkers),
                RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('© OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
          ),

          // Current Storm Status Card
          Card(
            margin: const EdgeInsets.all(12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: color,
                child: const Icon(Icons.cloud, color: Colors.white),
              ),
              title: Text(
                "Storm Risk: $_riskLevel",
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              subtitle: Text("Last updated: ${formatDateTime(_lastUpdated)}"),
              trailing: ElevatedButton(
                onPressed: _simulateStormAlert,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey,
                ),
                child: const Text("Refresh"),
              ),
            ),
          ),

          // Alerts list
          Expanded(
            flex: 2,
            child: _alerts.isEmpty
                ? const Center(child: Text("No Storm alerts yet. Tap Refresh."))
                : ListView.builder(
                    itemCount: _alerts.length,
                    itemBuilder: (ctx, i) {
                      final alert = _alerts[i];
                      final c = _riskColors[alert['level']] ?? Colors.grey;
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
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
                          title: Text(alert['message'] as String),
                          subtitle: Text(
                            "Location: ${alert['location']}\nTime: ${formatDateTime(alert['timestamp'] as DateTime)}",
                          ),
                          trailing: Icon(
                            Icons.chevron_right,
                            color: Colors.grey[600],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    StormAlertDetailPage(alert: alert),
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

      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.blueGrey,
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.white),
        label: const Text("Simulate Storm Alert"),
        onPressed: _simulateStormAlert,
      ),
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueGrey,
        title: const Text(
          "Storm Prediction",
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.settings, color: Colors.white),
              onPressed: () {
                Scaffold.of(context).openEndDrawer();
              },
            ),
          ),
        ],
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
              leading: const Icon(Icons.settings, color: Colors.blueGrey),
              title: const Text("Settings"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StormSettingsPage()),
                );
              },
            ),
          ],
        ),
      ),

      body: Column(
        children: [
          Expanded(
            flex: 2,
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
                MarkerLayer(markers: alertMarkers),
                RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('© OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
          ),

          // Current Flood Status Card
          Card(
            margin: const EdgeInsets.all(12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: color,
                child: const Icon(Icons.cloud, color: Colors.white),
              ),
              title: Text(
                "Storm Risk: $_riskLevel",
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              subtitle: Text("Last updated: ${formatDateTime(_lastUpdated)}"),
              trailing: ElevatedButton(
                onPressed: _simulateStormAlert,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey,
                ),
                child: const Text("Refresh"),
              ),
            ),
          ),

          // Alerts list
          Expanded(
            flex: 2,
            child: _alerts.isEmpty
                ? const Center(child: Text("No Storm alerts yet. Tap Refresh."))
                : ListView.builder(
                    itemCount: _alerts.length,
                    itemBuilder: (ctx, i) {
                      final alert = _alerts[i];
                      final c = _riskColors[alert['level']] ?? Colors.grey;
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
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
                          title: Text(alert['message'] as String),
                          subtitle: Text(
                            "Location: ${alert['location']}\nTime: ${formatDateTime(alert['timestamp'] as DateTime)}",
                          ),
                          trailing: Icon(
                            Icons.chevron_right,
                            color: Colors.grey[600],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.blueGrey,
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.white),
        label: const Text("Simulate Storm Alert"),
        onPressed: _simulateStormAlert,
      ),
    );
  }
}

/// ---------------------- FLOOD ALERT DETAIL ----------------------
class StormAlertDetailPage extends StatelessWidget {
  final Map<String, dynamic> alert;
  const StormAlertDetailPage({super.key, required this.alert});

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
        title: const Text("Storm Alert Detail"),
        backgroundColor: Colors.blueGrey,
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
class StormSettingsPage extends StatefulWidget {
  const StormSettingsPage({super.key});

  @override
  State<StormSettingsPage> createState() => _StormSettingsPageState();
}

class _StormSettingsPageState extends State<StormSettingsPage> {
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
            subtitle: const Text("Receive alerts for Storm warnings"),
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
                backgroundColor: Colors.blueGrey,
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
