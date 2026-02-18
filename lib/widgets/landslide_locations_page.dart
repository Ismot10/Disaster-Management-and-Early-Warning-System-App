import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ===================== LANDSLIDE LOCATIONS + SHELTERS PAGE =====================
class LocationsPage extends StatefulWidget {
  const LocationsPage({super.key});

  @override
  State<LocationsPage> createState() => _LocationsPageState();
}

class _LocationsPageState extends State<LocationsPage>
    with SingleTickerProviderStateMixin {
  List<String> locations = [];
  final TextEditingController controller = TextEditingController();
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  late AnimationController _pulseController;

  final Map<String, LatLng> cityCoords = {
    "Dhaka": LatLng(23.8103, 90.4125),
    "Chittagong": LatLng(22.3569, 91.7832),
    "Sylhet": LatLng(24.8949, 91.8687),
    "Khulna": LatLng(22.8456, 89.5403),
    "Rajshahi": LatLng(24.3745, 88.6042),
    "Barisal": LatLng(22.7010, 90.3535),
    "Rangpur": LatLng(25.7439, 89.2752),
  };

  final Map<String, LatLng> shelters = {
    "Dhaka Shelter 1": LatLng(23.8200, 90.4100),
    "Chittagong Shelter 1": LatLng(22.3560, 91.7800),
    "Sylhet Shelter 1": LatLng(24.8955, 91.8700),
  };

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
    super.dispose();
  }

  Future<void> loadLocations() async {
    try {
      final doc =
      await firestore.collection('user_locations').doc('default_user').get();
      if (doc.exists && doc.data()?['locations'] != null) {
        setState(() {
          locations = List<String>.from(doc['locations']);
        });
      } else {
        final prefs = await SharedPreferences.getInstance();
        final saved = prefs.getStringList('locations');
        setState(() {
          locations = saved ?? ["Dhaka", "Chittagong"];
        });
      }
    } catch (e) {
      debugPrint("Error loading locations: $e");
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList('locations');
      setState(() {
        locations = saved ?? ["Dhaka", "Chittagong"];
      });
    }
  }

  Future<void> saveLocations() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('locations', locations);

    try {
      await firestore.collection('user_locations').doc('default_user').set({
        'locations': locations,
      });
    } catch (e) {
      debugPrint("Error saving to Firestore: $e");
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

  @override
  Widget build(BuildContext context) {
    final locationMarkers = locations.map((loc) {
      final coords = cityCoords[loc];
      if (coords == null) return null;

      return Marker(
        point: coords,
        width: 70,
        height: 70,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ScaleTransition(
              scale: Tween(begin: 1.0, end: 1.4).animate(_pulseController),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue.withOpacity(0.3),
                ),
              ),
            ),
            const Icon(Icons.home, color: Colors.blue, size: 36),
          ],
        ),
      );
    }).whereType<Marker>().toList();

    final shelterMarkers = shelters.entries.map((entry) {
      final coords = entry.value;
      return Marker(
        point: coords,
        width: 70,
        height: 70,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ScaleTransition(
              scale: Tween(begin: 1.0, end: 1.4).animate(_pulseController),
              child: Container(
                width: 35,
                height: 35,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green.withOpacity(0.3),
                ),
              ),
            ),
            const Icon(Icons.local_hospital, color: Colors.green, size: 32),
          ],
        ),
      );
    }).toList();

    final allMarkers = [...locationMarkers, ...shelterMarkers];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Locations & Shelters",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          SizedBox(
            height: 300,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(23.8103, 90.4125),
                initialZoom: 7,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                  "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: 'com.earlywarning.app',
                ),
                MarkerLayer(markers: allMarkers),
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
          Expanded(
            child: locations.isEmpty
                ? const Center(child: Text("No saved locations yet."))
                : ListView.builder(
              itemCount: locations.length,
              itemBuilder: (ctx, i) => ListTile(
                leading:
                const Icon(Icons.location_on, color: Colors.blue),
                title: Text(locations[i]),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.grey),
                  onPressed: () => removeLocation(i),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
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
}
