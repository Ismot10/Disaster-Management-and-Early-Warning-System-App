import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

import 'flood_page.dart';
import 'landslide_page.dart';
import 'wildfire_page.dart';
import 'earthquake_page.dart';
import 'storm_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  // ✅ Safe helper: Firebase "push-id map" → latest child Map<String,dynamic>
  Map<String, dynamic> _latestMapFromSnapshot(dynamic raw) {
    if (raw == null) return {};
    if (raw is Map && raw.isNotEmpty) {
      // raw is like { pushId1: {...}, pushId2: {...} }
      try {
        final lastEntry = raw.entries.last.value;
        if (lastEntry is Map) return Map<String, dynamic>.from(lastEntry);
      } catch (_) {}

      // fallback
      try {
        final first = raw.values.first;
        if (first is Map) return Map<String, dynamic>.from(first);
      } catch (_) {}
    }

    if (raw is Map<String, dynamic>) {
      return Map<String, dynamic>.from(raw);
    }

    return {};
  }

  @override
  Widget build(BuildContext context) {
    // Realtime Database references for each disaster type
    final floodRef = FirebaseDatabase.instance.ref().child('floodData');
    final landslideRef = FirebaseDatabase.instance.ref().child('landslideData');
    final wildfireRef = FirebaseDatabase.instance.ref().child('wildfireData');
    final earthquakeRef = FirebaseDatabase.instance.ref().child('earthquakeData');

    // Storm nodes
    final stormRef = FirebaseDatabase.instance.ref().child('stormData');
    final fusionRef = FirebaseDatabase.instance.ref().child('fusionData');

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
        "icon": Icons.terrain_sharp,
        "color": Colors.lime,
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
        // keep a ref here (used for normal flow), but storm tile will be handled specially
        "ref": fusionRef,
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

      // ✅ Body keeps your ListView behavior + adds a bottom weather card
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: disasters.length,
              itemBuilder: (context, index) {
                final disaster = disasters[index];
                final String name = disaster["name"] as String;

                // ✅ SPECIAL: Storm tile uses BOTH stormData + fusionData
                if (name == "Storm Warning") {
                  return StreamBuilder<DatabaseEvent>(
                    stream: stormRef.limitToLast(1).onValue,
                    builder: (context, stormSnap) {
                      final stormRaw = stormSnap.data?.snapshot.value;
                      final stormData = _latestMapFromSnapshot(stormRaw);

                      return StreamBuilder<DatabaseEvent>(
                        stream: fusionRef.limitToLast(1).onValue,
                        builder: (context, fusionSnap) {
                          final fusionRaw = fusionSnap.data?.snapshot.value;
                          final fusionData = _latestMapFromSnapshot(fusionRaw);

                          // If BOTH empty → default card
                          if ((stormData.isEmpty) && (fusionData.isEmpty)) {
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              child: ListTile(
                                leading: Icon(
                                  disaster["icon"] as IconData,
                                  color: disaster["color"] as Color,
                                ),
                                title: Text(name),
                                subtitle: const Text("No recent alerts"),
                                trailing: const Icon(Icons.chevron_right,
                                    color: Colors.grey),
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

                          // -------- stormData fields --------
                          final stormTime =
                              stormData['timestamp']?.toString() ?? "Unknown";
                          final stormRisk =
                              stormData['risk_level']?.toString() ?? "Normal";
                          final stormWind =
                              stormData['wind_speed_mps']?.toString() ?? "-";
                          final cycloneDetected =
                          (stormData['cyclone_detected'] == 1 ||
                              stormData['cyclone_detected'] == true);

                          // -------- fusionData fields --------
                          final fusionTime =
                              fusionData['timestamp']?.toString() ?? "Unknown";
                          final fusedEvent =
                              fusionData['fused_event']?.toString() ?? "Normal";
                          final fusedRisk =
                              fusionData['fused_risk']?.toString() ?? "Normal";
                          final stormRiskFromFusion =
                              fusionData['storm_risk']?.toString() ?? "Normal";
                          final floodRiskFromFusion =
                              fusionData['flood_risk']?.toString() ?? "Low";

                          final windFusion =
                              fusionData['wind_speed_mps']?.toString() ?? "-";
                          final rainFusion =
                              fusionData['rain_percent']?.toString() ?? "-";
                          final waterFusion =
                              fusionData['water_percent']?.toString() ?? "-";
                          final distFusion =
                              fusionData['distance_cm']?.toString() ?? "-";

                          // Badge rule (safe)
                          final showAlertBadge = (fusedRisk == "HighRisk" ||
                              fusedRisk == "Extreme" ||
                              stormRisk == "Cyclone" ||
                              stormRiskFromFusion == "Cyclone" ||
                              cycloneDetected ||
                              fusedEvent.contains("Cyclone"));

                          // Color rules (safe, only storm tile)
                          Color? cardColor;
                          Color iconColor = disaster["color"] as Color;

                          if (fusedRisk == "Extreme" ||
                              fusedEvent.contains("Cyclone") ||
                              stormRisk == "Cyclone" ||
                              cycloneDetected) {
                            cardColor = Colors.red.withOpacity(0.08);
                            iconColor = Colors.red;
                          } else if (fusedRisk == "HighRisk" ||
                              stormRiskFromFusion == "Cyclone") {
                            cardColor = Colors.deepOrange.withOpacity(0.08);
                            iconColor = Colors.deepOrange;
                          } else if (stormRiskFromFusion == "Storm" ||
                              stormRisk == "Storm") {
                            cardColor = Colors.blueAccent.withOpacity(0.06);
                            iconColor = Colors.blueAccent;
                          }

                          final subtitle =
                              "Storm Node: $stormRisk • Wind: $stormWind m/s • Cyclone: ${cycloneDetected ? 'YES' : 'NO'}\n"
                              "Fusion Node: $fusedEvent (Risk: $fusedRisk)\n"
                              "Fusion Inputs: Wind: $windFusion m/s • Rain: $rainFusion% • Water: $waterFusion% • Dist: $distFusion cm\n"
                              "Storm(Fusion): $stormRiskFromFusion | Flood: $floodRiskFromFusion\n"
                              "Time(Storm): $stormTime\n"
                              "Time(Fusion): $fusionTime";

                          return Card(
                            color: cardColor,
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            child: ListTile(
                              leading: Icon(
                                disaster["icon"] as IconData,
                                color: iconColor,
                              ),
                              title: Row(
                                children: [
                                  Text(name),
                                  const SizedBox(width: 8),
                                  if (showAlertBadge)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        "⚠️ ALERT",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Text(subtitle),
                              trailing: const Icon(Icons.chevron_right,
                                  color: Colors.grey),
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
                  );
                }

                // ✅ NORMAL: other tiles stay exactly same behavior (single ref stream)
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

                    final data = _latestMapFromSnapshot(snapshot.data!.snapshot.value);
                    final time = data['timestamp']?.toString() ?? "Unknown time";

                    // ---------------- FLOOD ----------------
                    final waterLevel = data['water_level_cm']?.toString() ?? "-";
                    final rainIntensity =
                        data['rain_intensity_percent']?.toString() ?? "-";
                    final floodDetected =
                    (data['flood_detected'] == 1 || data['flood_detected'] == true)
                        ? "⚠️ Flood Detected"
                        : "No Flood";

                    // ---------------- LANDSLIDE ----------------
                    final landslideDetected =
                    (data['landslide_detected'] == 1 ||
                        data['landslide_detected'] == true);
                    final landslideRisk =
                        data['risk_level']?.toString() ?? "Unknown";
                    final pressure = data['pressure']?.toString() ?? "-";
                    final moisture = data['soil_moisture']?.toString() ?? "-";

                    // ---------------- WILDFIRE ----------------
                    final wildfireDetected =
                    (data['wildfire_detected'] == 1 ||
                        data['wildfire_detected'] == true);
                    final wildfireRisk =
                        data['risk_level']?.toString() ?? "Unknown";
                    final temperature = data['temperature']?.toString() ?? "-";
                    final smoke = data['gas_value']?.toString() ?? "-";
                    final humidity = data['humidity']?.toString() ?? "-";
                    final flameDetected =
                    (data['flame_detected'] == 1 || data['flame_detected'] == true);

                    // ---------------- EARTHQUAKE ----------------
                    final bool earthquakeDetected =
                    (data['vibration'] == true || data['vibration'] == 1);
                    final String earthquakeRisk =
                        data['risk_level']?.toString() ?? "Unknown";
                    final String motion = data['motion']?.toString() ?? "-";

                    String subtitle = "";
                    bool showAlertBadge = false;

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
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  "⚠️ ALERT",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text(subtitle),
                        trailing:
                        const Icon(Icons.chevron_right, color: Colors.grey),
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
          ),

          // ✅ WEATHER PANEL (Temp/Humidity from wildfireData, Wind from stormData)
          _WeatherPanel(
            wildfireRef: wildfireRef,
            stormRef: stormRef,
            latestMapFromSnapshot: _latestMapFromSnapshot,
          ),
        ],
      ),
    );
  }
}

class _WeatherPanel extends StatelessWidget {
  final DatabaseReference wildfireRef;
  final DatabaseReference stormRef;
  final Map<String, dynamic> Function(dynamic raw) latestMapFromSnapshot;

  const _WeatherPanel({
    required this.wildfireRef,
    required this.stormRef,
    required this.latestMapFromSnapshot,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: StreamBuilder<DatabaseEvent>(
            stream: wildfireRef.limitToLast(1).onValue,
            builder: (context, wildSnap) {
              final wildData = latestMapFromSnapshot(wildSnap.data?.snapshot.value);

              final temp = wildData['temperature']?.toString() ?? "-";
              final hum = wildData['humidity']?.toString() ?? "-";
              final wildTime = wildData['timestamp']?.toString() ?? "Unknown";

              return StreamBuilder<DatabaseEvent>(
                stream: stormRef.limitToLast(1).onValue,
                builder: (context, stormSnap) {
                  final stormData =
                  latestMapFromSnapshot(stormSnap.data?.snapshot.value);

                  final wind = stormData['wind_speed_mps']?.toString() ?? "-";
                  final stormTime = stormData['timestamp']?.toString() ?? "Unknown";

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "🌦️ Live Weather (Sensor)",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Expanded(
                            child: _weatherItem(
                              icon: Icons.thermostat,
                              label: "Temperature",
                              value: "$temp °C",
                            ),
                          ),
                          Expanded(
                            child: _weatherItem(
                              icon: Icons.water_drop,
                              label: "Humidity",
                              value: "$hum %",
                            ),
                          ),
                          Expanded(
                            child: _weatherItem(
                              icon: Icons.air,
                              label: "Wind",
                              value: "$wind m/s",
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),
                      Text(
                        "Temp/Humidity Time: $wildTime",
                        style: const TextStyle(color: Colors.black54, fontSize: 12),
                      ),
                      Text(
                        "Wind Time: $stormTime",
                        style: const TextStyle(color: Colors.black54, fontSize: 12),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _weatherItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: Colors.black.withOpacity(0.06),
          child: Icon(icon, size: 18, color: Colors.black87),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(color: Colors.black54, fontSize: 12)),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }
}