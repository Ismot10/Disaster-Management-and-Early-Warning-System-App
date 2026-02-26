import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ===================== STORM LOCATIONS + SHELTERS PAGE =====================
/// ✅ Same structure/features as your Landslide Locations page:
/// - Saves user locations (Firestore + SharedPreferences fallback)
/// - Shows pulsing markers for saved locations + storm shelters
/// - Includes storm-prone coastal areas of Bangladesh + nearby shelters (static list)
class StormLocationsPage extends StatefulWidget {
  const StormLocationsPage({super.key});

  @override
  State<StormLocationsPage> createState() => _StormLocationsPageState();
}

class _StormLocationsPageState extends State<StormLocationsPage>
    with SingleTickerProviderStateMixin {
  List<String> locations = [];
  final TextEditingController controller = TextEditingController();
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  late AnimationController _pulseController;

  // ✅ Major cities + common places (you can extend anytime)
  final Map<String, LatLng> cityCoords = {
    "Dhaka": const LatLng(23.8103, 90.4125),
    "Chittagong": const LatLng(22.3569, 91.7832),
    "Sylhet": const LatLng(24.8949, 91.8687),
    "Khulna": const LatLng(22.8456, 89.5403),
    "Rajshahi": const LatLng(24.3745, 88.6042),
    "Barisal": const LatLng(22.7010, 90.3535),
    "Rangpur": const LatLng(25.7439, 89.2752),

    // ✅ Storm-prone coastal districts / hotspots
    "Cox's Bazar": const LatLng(21.4272, 92.0058),
    "Teknaf": const LatLng(20.8624, 92.2975),
    "Kutubdia": const LatLng(21.8167, 91.8500),
    "Maheshkhali": const LatLng(21.5500, 91.9500),
    "Chandpur": const LatLng(23.2333, 90.6667),
    "Noakhali": const LatLng(22.8696, 91.0994),
    "Lakshmipur": const LatLng(22.9447, 90.8282),
    "Feni": const LatLng(23.0159, 91.3976),
    "Bhola": const LatLng(22.6850, 90.6480),
    "Patuakhali": const LatLng(22.3596, 90.3299),
    "Barguna": const LatLng(22.1592, 90.1256),
    "Satkhira": const LatLng(22.7085, 89.0715),
    "Bagerhat": const LatLng(22.6516, 89.7856),
    "Mongla Port": const LatLng(22.4890, 89.6160),
    "Sandwip": const LatLng(22.5167, 91.4333),
    "Hatiya": const LatLng(22.4000, 91.1000),
    "Char Fasson": const LatLng(22.1870, 90.7490),
    "Kuakata": const LatLng(21.8250, 90.1210),
  };

  // ✅ Static shelters list (example). Replace with your real shelter DB later.
  final Map<String, LatLng> shelters = {
    // Chattogram division
    "Cox's Bazar Cyclone Shelter": const LatLng(21.4400, 92.0100),
    "Teknaf Cyclone Shelter": const LatLng(20.8600, 92.3000),
    "Kutubdia Shelter": const LatLng(21.8200, 91.8500),
    "Sandwip Shelter": const LatLng(22.5200, 91.4300),

    // Barishal division
    "Bhola Cyclone Shelter": const LatLng(22.6900, 90.6500),
    "Patuakhali Cyclone Shelter": const LatLng(22.3600, 90.3300),
    "Barguna Cyclone Shelter": const LatLng(22.1600, 90.1200),
    "Kuakata Shelter": const LatLng(21.8250, 90.1210),

    // Khulna division (coastal)
    "Satkhira Cyclone Shelter": const LatLng(22.7100, 89.0700),
    "Mongla Cyclone Shelter": const LatLng(22.4900, 89.6160),
    "Bagerhat Shelter": const LatLng(22.6500, 89.7850),

    // Noakhali coast
    "Hatiya Cyclone Shelter": const LatLng(22.4050, 91.1000),
    "Noakhali Cyclone Shelter": const LatLng(22.8700, 91.1000),
  };

  bool showStormProneMarkers = true;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    loadLocations();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    controller.dispose();
    super.dispose();
  }

  Future<void> loadLocations() async {
    try {
      final doc =
      await firestore.collection('user_locations').doc('default_user').get();

      if (doc.exists && doc.data()?['storm_locations'] != null) {
        setState(() {
          locations = List<String>.from(doc['storm_locations']);
        });
      } else {
        final prefs = await SharedPreferences.getInstance();
        final saved = prefs.getStringList('storm_locations');
        setState(() {
          locations = saved ?? ["Dhaka", "Chittagong", "Cox's Bazar"];
        });
      }
    } catch (e) {
      debugPrint("Error loading storm locations: $e");
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList('storm_locations');
      setState(() {
        locations = saved ?? ["Dhaka", "Chittagong", "Cox's Bazar"];
      });
    }
  }

  Future<void> saveLocations() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('storm_locations', locations);

    try {
      await firestore.collection('user_locations').doc('default_user').set(
        {'storm_locations': locations},
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint("Error saving storm locations to Firestore: $e");
    }
  }

  void addLocation(String loc) {
    if (loc.isEmpty) return;

    if (!locations.contains(loc)) {
      setState(() => locations.add(loc));
      saveLocations();
      controller.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$loc added successfully')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$loc already exists')),
      );
    }
  }

  void removeLocation(int index) {
    final removed = locations[index];
    setState(() => locations.removeAt(index));
    saveLocations();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$removed removed')),
    );
  }

  // ✅ Nearest shelter (straight-line distance)
  String? nearestShelterName(LatLng userPoint) {
    double best = double.infinity;
    String? bestName;

    for (final entry in shelters.entries) {
      final s = entry.value;
      final d = _haversineKm(userPoint, s);
      if (d < best) {
        best = d;
        bestName = "${entry.key} (~${d.toStringAsFixed(1)} km)";
      }
    }
    return bestName;
  }

  // ✅ Accurate Haversine using dart:math
  double _haversineKm(LatLng a, LatLng b) {
    const double r = 6371.0; // Earth radius (km)

    final lat1 = a.latitude * math.pi / 180.0;
    final lon1 = a.longitude * math.pi / 180.0;
    final lat2 = b.latitude * math.pi / 180.0;
    final lon2 = b.longitude * math.pi / 180.0;

    final dLat = lat2 - lat1;
    final dLon = lon2 - lon1;

    final sinDLat = math.sin(dLat / 2.0);
    final sinDLon = math.sin(dLon / 2.0);

    final h = sinDLat * sinDLat +
        math.cos(lat1) * math.cos(lat2) * sinDLon * sinDLon;

    final c = 2.0 * math.atan2(math.sqrt(h), math.sqrt(1.0 - h));
    return r * c;
  }

  @override
  Widget build(BuildContext context) {
    // ✅ User location markers
    final locationMarkers = locations
        .map((loc) {
      final coords = cityCoords[loc];
      if (coords == null) return null;

      final nearest = nearestShelterName(coords);

      return Marker(
        point: coords,
        width: 80,
        height: 80,
        child: GestureDetector(
          onTap: () {
            if (nearest != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Nearest shelter: $nearest"),
                  duration: const Duration(seconds: 3),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("No shelter data found for $loc"),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              ScaleTransition(
                scale: Tween(begin: 1.0, end: 1.4).animate(_pulseController),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue.withOpacity(0.3),
                  ),
                ),
              ),
              const Icon(Icons.home, color: Colors.blue, size: 36),
            ],
          ),
        ),
      );
    })
        .whereType<Marker>()
        .toList();

    // ✅ Shelter markers
    final shelterMarkers = shelters.entries.map((entry) {
      final coords = entry.value;
      return Marker(
        point: coords,
        width: 80,
        height: 80,
        child: Tooltip(
          message: entry.key,
          child: Stack(
            alignment: Alignment.center,
            children: [
              ScaleTransition(
                scale: Tween(begin: 1.0, end: 1.4).animate(_pulseController),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green.withOpacity(0.28),
                  ),
                ),
              ),
              const Icon(Icons.local_hospital, color: Colors.green, size: 32),
            ],
          ),
        ),
      );
    }).toList();

    // ✅ Storm-prone hotspot markers (optional)
    final stormProneMarkers = showStormProneMarkers
        ? _stormPronePoints().map((p) {
      return Marker(
        point: p.value,
        width: 70,
        height: 70,
        child: Tooltip(
          message: p.key,
          child: Stack(
            alignment: Alignment.center,
            children: [
              ScaleTransition(
                scale:
                Tween(begin: 1.0, end: 1.35).animate(_pulseController),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.withOpacity(0.22),
                  ),
                ),
              ),
              const Icon(Icons.warning, color: Colors.red, size: 28),
            ],
          ),
        ),
      );
    }).toList()
        : <Marker>[];

    final allMarkers = [...locationMarkers, ...shelterMarkers, ...stormProneMarkers];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Storm Locations & Shelters",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            tooltip: "Toggle storm-prone markers",
            icon: Icon(
              showStormProneMarkers ? Icons.visibility : Icons.visibility_off,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() => showStormProneMarkers = !showStormProneMarkers);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 300,
            child: FlutterMap(
              options: const MapOptions(
                initialCenter: LatLng(22.8, 90.5), // coastal-ish center
                initialZoom: 6.7,
              ),
              children: [
                TileLayer(
                  urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: 'com.earlywarning.app',
                ),
                MarkerLayer(markers: allMarkers),
                RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('© OpenStreetMap contributors', onTap: null),
                  ],
                ),
              ],
            ),
          ),
          const Divider(),

          // ✅ Saved locations list
          Expanded(
            child: locations.isEmpty
                ? const Center(child: Text("No saved locations yet."))
                : ListView.builder(
              itemCount: locations.length,
              itemBuilder: (ctx, i) {
                final loc = locations[i];
                final coords = cityCoords[loc];
                final nearest = coords == null ? null : nearestShelterName(coords);

                return ListTile(
                  leading: const Icon(Icons.location_on, color: Colors.blue),
                  title: Text(loc),
                  subtitle: nearest == null
                      ? const Text("Tap marker to see nearest shelter")
                      : Text("Nearest shelter: $nearest"),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.grey),
                    onPressed: () => removeLocation(i),
                  ),
                );
              },
            ),
          ),

          // ✅ Add new location
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      hintText: "Enter location (ex: Cox's Bazar, Bhola, Dhaka)",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
                  onPressed: () => addLocation(controller.text.trim()),
                  child: const Text("Add", style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Storm-prone hotspot points (markers)
  List<MapEntry<String, LatLng>> _stormPronePoints() {
    const points = <MapEntry<String, LatLng>>[
      MapEntry("Storm-prone: Cox's Bazar", LatLng(21.4272, 92.0058)),
      MapEntry("Storm-prone: Teknaf", LatLng(20.8624, 92.2975)),
      MapEntry("Storm-prone: Bhola", LatLng(22.6850, 90.6480)),
      MapEntry("Storm-prone: Barguna", LatLng(22.1592, 90.1256)),
      MapEntry("Storm-prone: Patuakhali", LatLng(22.3596, 90.3299)),
      MapEntry("Storm-prone: Hatiya", LatLng(22.4000, 91.1000)),
      MapEntry("Storm-prone: Sandwip", LatLng(22.5167, 91.4333)),
      MapEntry("Storm-prone: Mongla", LatLng(22.4890, 89.6160)),
      MapEntry("Storm-prone: Satkhira", LatLng(22.7085, 89.0715)),
      MapEntry("Storm-prone: Kuakata", LatLng(21.8250, 90.1210)),
    ];
    return points;
  }
}