import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';


// LOCATION PAGE.....................................................................

class LocationsPage extends StatefulWidget {
const LocationsPage({super.key});

@override
State<LocationsPage> createState() => _LocationsPageState();
}

class _LocationsPageState extends State<LocationsPage> {
List<String> locations = [];
final TextEditingController controller = TextEditingController();
final FirebaseFirestore firestore = FirebaseFirestore.instance;

// 🔹 Known coordinates for major Bangladesh cities
final Map<String, LatLng> cityCoords = {
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
loadLocations();
}

/// 🔹 Load locations (Firestore first, fallback to SharedPreferences)
Future<void> loadLocations() async {
try {
final doc = await firestore
    .collection('user_locations')
    .doc('default_user')
    .get();

if (doc.exists &&
doc.data() != null &&
doc.data()!['locations'] != null) {
setState(() {
locations = List<String>.from(doc['locations']);
});
} else {
// If no data in Firestore, load from SharedPreferences
final prefs = await SharedPreferences.getInstance();
final saved = prefs.getStringList('locations');
setState(() {
locations = saved ?? ["Dhaka", "Chittagong"];
});
}
} catch (e) {
debugPrint("Error loading locations: $e");
// fallback to local
final prefs = await SharedPreferences.getInstance();
final saved = prefs.getStringList('locations');
setState(() {
locations = saved ?? ["Dhaka", "Chittagong"];
});
}
}

/// 🔹 Save locations both locally and to Firestore
Future<void> saveLocations() async {
// Local save
final prefs = await SharedPreferences.getInstance();
await prefs.setStringList('locations', locations);

// Cloud save
try {
await firestore.collection('user_locations').doc('default_user').set({
'locations': locations,
});
} catch (e) {
debugPrint("Error saving to Firestore: $e");
}
}

void addLocation(String loc) {
if (loc.isNotEmpty && !locations.contains(loc)) {
setState(() {
locations.add(loc);
});
saveLocations(); // ✅ sync both
controller.clear();
ScaffoldMessenger.of(
context,
).showSnackBar(SnackBar(content: Text('$loc added successfully')));
} else if (locations.contains(loc)) {
ScaffoldMessenger.of(
context,
).showSnackBar(SnackBar(content: Text('$loc already exists')));
}
}

void removeLocation(int index) {
final removed = locations[index];
setState(() {
locations.removeAt(index);
});
saveLocations(); // ✅ sync both
ScaffoldMessenger.of(
context,
).showSnackBar(SnackBar(content: Text('$removed removed')));
}

@override
Widget build(BuildContext context) {
// 🔹 Generate markers for saved locations
final markers = locations
    .map((loc) {
final coords = cityCoords[loc];
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
child: locations.isEmpty
? const Center(child: Text("No saved locations yet."))
    : ListView.builder(
itemCount: locations.length,
itemBuilder: (ctx, i) {
return ListTile(
leading: const Icon(
Icons.location_on,
color: Colors.red,
),
title: Text(locations[i]),
trailing: IconButton(
icon: const Icon(Icons.delete, color: Colors.grey),
onPressed: () => removeLocation(i),
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
