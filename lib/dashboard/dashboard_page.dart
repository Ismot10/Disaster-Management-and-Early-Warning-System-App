import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

import 'flood_page.dart';
import 'landslide_page.dart';
import 'wildfire_page.dart';
import 'earthquake_page.dart';
import 'storm_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Realtime Database references for each disaster type
    final floodRef = FirebaseDatabase.instance.ref().child('floodData');
    final landslideRef = FirebaseDatabase.instance.ref().child('landslideData');
    final wildfireRef = FirebaseDatabase.instance.ref().child('wildfireData');
    final earthquakeRef = FirebaseDatabase.instance.ref().child('earthquakeData');
    final stormRef = FirebaseDatabase.instance.ref().child('stormData');

    // List of disasters and their data references
    final disasters = [
      {
        "name": "Flood Warning",
        "icon": Icons.water,
        "color": Colors.blue,
        "ref": floodRef,
        "page": const FloodPage(),
      },
      {
        "name": "Landslide Warning",
        "icon": Icons.terrain,
        "color": Colors.yellow,
        "ref": landslideRef,
        "page": const LandslidePage(),
      },
      {
        "name": "Wildfire Warning",
        "icon": Icons.local_fire_department,
        "color": Colors.redAccent,
        "ref": wildfireRef,
        "page": const WildfirePage(),
      },
      {
        "name": "Earthquake Warning",
        "icon": Icons.public,
        "color": Colors.orange,
        "ref": earthquakeRef,
        "page": const EarthquakePage(),
      },
      {
        "name": "Storm Warning",
        "icon": Icons.thunderstorm,
        "color": Colors.blueAccent,
        "ref": stormRef,
        "page": const StormPage(),
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Disaster Dashboard",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.deepPurple,
      ),
      body: ListView.builder(
        itemCount: disasters.length,
        itemBuilder: (context, index) {
          final disaster = disasters[index];
          final DatabaseReference ref = disaster["ref"] as DatabaseReference;

          return StreamBuilder(
            stream: ref.limitToLast(1).onValue,

            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
                // No data found → show default card
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: ListTile(
                    leading: Icon(
                      disaster["icon"] as IconData,
                      color: disaster["color"] as Color,
                    ),
                    title: Text(disaster["name"] as String),
                    subtitle: const Text("No recent alerts"),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.grey,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => disaster["page"] as Widget,
                        ),
                      );
                    },
                  ),
                );
              }

              // ✅ FIX: Safely handle nested Firebase data under child keys
              final raw = (snapshot.data!).snapshot.value;
              Map<String, dynamic> data = {};

              if (raw is Map && raw.isNotEmpty) {
                // If child nodes like -Nx123abc exist, extract the last one
                final lastEntry = raw.entries.last.value;
                if (lastEntry is Map) {
                  data = Map<String, dynamic>.from(lastEntry);
                } else if (raw.values.first is Map) {
                  // fallback
                  data = Map<String, dynamic>.from(raw.values.first);
                }
              } else if (raw is Map<String, dynamic>) {
                // If not nested, just take it directly
                data = Map<String, dynamic>.from(raw);
              }

              // Extract fields safely
              final time = data['timestamp']?.toString() ?? "Unknown time";
              final waterLevel = data['water_level_cm']?.toString() ?? "-";
              final rainIntensity =
                  data['rain_intensity_percent']?.toString() ?? "-";
              final floodDetected =
                  (data['flood_detected'] == 1 ||
                      data['flood_detected'] == true)
                  ? "⚠️ Flood Detected"
                  : "No Flood";

              String subtitle = "";

              // Customize subtitle depending on disaster type
              switch (disaster["name"]) {
                case "Flood Warning":
                  subtitle =
                      "$floodDetected\nWater Level: $waterLevel cm | Rain: $rainIntensity%\nTime: $time";
                  break;
                default:
                  subtitle = "Last update: $time";
              }

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: Icon(
                    disaster["icon"] as IconData,
                    color: disaster["color"] as Color,
                  ),
                  title: Text(disaster["name"] as String),
                  subtitle: Text(subtitle),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => disaster["page"] as Widget,
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
