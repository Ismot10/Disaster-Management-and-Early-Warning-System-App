import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as htmlParser;
import 'package:latlong2/latlong.dart';

/// Example mapping of locations to coordinates (you can extend)
final Map<String, LatLng> _locationsCoords = {
  "Chittagong": LatLng(22.3569, 91.7832),
  "Cox's Bazar": LatLng(21.4272, 92.0058),
  "Sylhet": LatLng(24.8949, 91.8687),
  "Khagrachhari": LatLng(23.1187, 91.9997),
  // add more as needed
};

class LandslideHttpService {
  /// Fetch official landslide data from BMD Landslide Warning page
  Future<List<Map<String, dynamic>>> fetchLandslideData() async {
    final List<Map<String, dynamic>> alerts = [];

    try {
      final response = await http.get(
        Uri.parse('https://live8.bmd.gov.bd/p/Landslide-Warning'),
      );

      if (response.statusCode == 200) {
        final document = htmlParser.parse(response.body);

        // Select all tables (BMD may have multiple tables per region)
        final tables = document.querySelectorAll('table');

        for (var table in tables) {
          final rows = table.querySelectorAll('tbody tr');

          for (var row in rows) {
            final location = row.querySelector('td:nth-child(1)')?.text.trim();
            final level = row.querySelector('td:nth-child(2)')?.text.trim();

            if (location == null || level == null) continue;

            final coords = _locationsCoords[location] ?? LatLng(23.8103, 90.4125);

            final newAlert = {
              'type': 'Landslide',
              'level': level,
              'location': location,
              'message': 'Landslide risk level: $level',
              'timestamp': DateTime.now(),
              'coords': coords,
              'source': 'official',
            };

            alerts.add(newAlert);
          }
        }
      } else {
        print("Failed to fetch BMD data. Status: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching BMD landslide data: $e");
    }

    return alerts;
  }
}
