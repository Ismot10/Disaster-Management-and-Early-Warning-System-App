import 'package:flutter/material.dart';
import 'storm_settings_page.dart';
import 'storm_locations_page.dart';

// =====================================================
// 🔥 APP DRAWER
// =====================================================

class StormDrawer extends StatelessWidget {
  const StormDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      backgroundColor: isDark ? Colors.black : Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ===== HEADER WITH BACK ARROW =====
          Container(
            height: 90,
            color: Colors.deepPurple,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    Navigator.pop(context); // ✅ close drawer
                  },
                ),
                const Expanded(
                  child: Center(
                    child: Text(
                      "Menu",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 48), // balances arrow spacing
              ],
            ),
          ),

          // ===== MENU ITEMS =====
          ListTile(
            leading: const Icon(Icons.location_on, color: Colors.red),
            title: const Text("My Locations"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const StormLocationsPage(),
                ),
              );
            },
          ),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.settings, color: Colors.deepOrange),
            title: const Text("Settings"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const StormSettingsPage(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}