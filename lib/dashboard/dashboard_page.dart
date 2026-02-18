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
        "icon": Icons.warning, // ⚠️ warning icon
        "color": Colors.deepOrange,
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
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

              // Safely handle nested Firebase data
              final raw = (snapshot.data!).snapshot.value;
              Map<String, dynamic> data = {};

              if (raw is Map && raw.isNotEmpty) {
                final lastEntry = raw.entries.last.value;
                if (lastEntry is Map) {
                  data = Map<String, dynamic>.from(lastEntry);
                } else if (raw.values.first is Map) {
                  data = Map<String, dynamic>.from(raw.values.first);
                }
              } else if (raw is Map<String, dynamic>) {
                data = Map<String, dynamic>.from(raw);
              }

              final time = data['timestamp']?.toString() ?? "Unknown time";

              // ---------------- FLOOD ----------------
              final waterLevel = data['water_level_cm']?.toString() ?? "-";
              final rainIntensity = data['rain_intensity_percent']?.toString() ?? "-";
              final floodDetected =
              (data['flood_detected'] == 1 || data['flood_detected'] == true)
                  ? "⚠️ Flood Detected"
                  : "No Flood";

              // ---------------- LANDSLIDE ----------------
              final landslideDetected =
              (data['landslide_detected'] == 1 || data['landslide_detected'] == true);
              final landslideRisk = data['risk_level']?.toString() ?? "Unknown";
              final pressure = data['pressure']?.toString() ?? "-";
              final moisture = data['soil_moisture']?.toString() ?? "-";

              // ---------------- WILDFIRE ----------------
              final wildfireDetected =
              (data['wildfire_detected'] == 1 || data['wildfire_detected'] == true);
              final wildfireRisk = data['risk_level']?.toString() ?? "Unknown";
              final temperature = data['temperature']?.toString() ?? "-";
              final smoke = data['gas_value']?.toString() ?? "-";
              final humidity = data['humidity']?.toString() ?? "-";
              final flameDetected =
              (data['flame_detected'] == 1 || data['flame_detected'] == true);

              // ---------------- EARTHQUAKE ----------------
              final bool earthquakeDetected =
              (data['vibration'] == true || data['vibration'] == 1);
              final String earthquakeRisk = data['risk_level']?.toString() ?? "Unknown";
              final String motion = data['motion']?.toString() ?? "-";

              String subtitle = "";
              bool showAlertBadge = false;

              // ---------------- CUSTOM SUBTITLE ----------------
              switch (disaster["name"]) {
                case "Flood Warning":
                  subtitle =
                  "$floodDetected\nWater Level: $waterLevel cm | Rain: $rainIntensity%\nTime: $time";
                  break;

                case "Landslide Warning":
                  subtitle = landslideDetected
                      ? "⚠️ LANDSLIDE DETECTED ($landslideRisk)\nPressure: $pressure | Soil Moisture: $moisture\nTime: $time"
                      : "Landslide Status: $landslideRisk\nPressure: $pressure | Soil Moisture: $moisture\nTime: $time";
                  showAlertBadge = landslideDetected;
                  break;

                case "Wildfire Warning":
                  if (wildfireDetected) {
                    subtitle =
                    "🔥 WILDFIRE DETECTED ($wildfireRisk)\nTemp: $temperature°C | Humidity: $humidity%\nSmoke: $smoke | Flame: ${flameDetected ? 'YES' : 'NO'}\nTime: $time";
                  } else {
                    subtitle =
                    "Wildfire State: $wildfireRisk\nTemp: $temperature°C | Humidity: $humidity%\nSmoke: $smoke | Flame: ${flameDetected ? 'YES' : 'NO'}\nTime: $time";
                  }
                  break;

                case "Earthquake Warning":
                  if (earthquakeDetected) {
                    subtitle =
                    "🌏 EARTHQUAKE DETECTED ($earthquakeRisk)\nGround Motion: $motion g\nTime: $time";
                  } else {
                    subtitle =
                    "Earthquake Status: $earthquakeRisk\nGround Motion: $motion g\nTime: $time";
                  }
                  break;

                default:
                  subtitle = "Last update: $time";
              }

              // ---------------- CARD COLOR ----------------
              Color? cardColor;
              if (disaster["name"] == "Landslide Warning" && landslideRisk == "High") {
                cardColor = Colors.deepOrange.withOpacity(0.08);
              } else if (disaster["name"] == "Wildfire Warning" && wildfireDetected) {
                cardColor = Colors.red.withOpacity(0.08);
              } else if (disaster["name"] == "Earthquake Warning" &&
                  earthquakeDetected &&
                  (earthquakeRisk == "High" || earthquakeRisk == "Critical")) {
                cardColor = Colors.orange.withOpacity(0.08);
              }

              // ---------------- LEADING ICON COLOR ----------------
              Color iconColor;
              if (disaster["name"] == "Landslide Warning" && landslideRisk == "High") {
                iconColor = Colors.deepOrange;
              } else if (disaster["name"] == "Wildfire Warning" && wildfireDetected) {
                iconColor = Colors.red;
              } else if (disaster["name"] == "Earthquake Warning" &&
                  earthquakeDetected &&
                  (earthquakeRisk == "High" || earthquakeRisk == "Critical")) {
                iconColor = Colors.orange;
              } else {
                iconColor = disaster["color"] as Color;
              }

              return Card(
                color: cardColor,
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: Icon(
                    disaster["name"] == "Landslide Warning"
                        ? Icons.warning
                        : disaster["icon"] as IconData,
                    color: iconColor,
                  ),
                  title: Row(
                    children: [
                      Text(disaster["name"] as String),
                      const SizedBox(width: 8),
                      if (showAlertBadge)
                        Container(
                          padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            "⚠️ ALERT",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
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
