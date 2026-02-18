import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/landslide_voice_alert.dart';
import '../theme_notifier.dart';
import '../utils/notification_service.dart';

/// ===================== LANDSLIDE SETTINGS PAGE =====================
class LandslideSettingsPage extends StatefulWidget {
  const LandslideSettingsPage({super.key});

  @override
  State<LandslideSettingsPage> createState() => _LandslideSettingsPageState();
}

class _LandslideSettingsPageState extends State<LandslideSettingsPage> {
  // ---------------- Settings State ----------------
  bool notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    loadSettings(); // Load user preferences when page opens
  }

  // ---------------- Load Settings ----------------
  Future<void> loadSettings() async {
    final enabled = await NotificationService.isNotificationEnabled();
    setState(() => notificationsEnabled = enabled);
  }

  // ---------------- Save Settings ----------------
  Future<void> saveSettings() async {
    await NotificationService.setNotificationEnabled(notificationsEnabled);

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
        title: const Text(
          "Settings",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.deepPurple,
      ),
      body: ListView(
        children: [
          // ---------------- Notifications Toggle ----------------
          SwitchListTile(
            title: const Text("Enable Notifications"),
            subtitle: const Text("Receive alerts for landslide warnings"),
            value: notificationsEnabled,
            onChanged: (val) {
              setState(() {
                notificationsEnabled = val;
              });
            },
          ),

          const Divider(),

          // ---------------- Theme Switch ----------------
          ListTile(
            title: const Text("Theme"),
            subtitle: Text(isDark ? "Dark" : "Light"),
            trailing: Switch(
              value: isDark,
              onChanged: (val) {
                themeNotifier.toggleTheme(val); // instant change + save
              },
            ),
          ),

          const Divider(),

          // ---------------- Bangla Voice Alerts ----------------
          SwitchListTile(
            title: const Text("Bangla Voice Alerts"),
            subtitle: const Text("সতর্কবার্তা বাংলায় শোনা যাবে"),
            value: LandslideVoiceAlert.currentLanguage == AlertLanguage.bangla,
            onChanged: (val) async {
              await LandslideVoiceAlert.setLanguage(
                val ? AlertLanguage.bangla : AlertLanguage.english,
              );
              setState(() {}); // refresh UI
            },
          ),

          const Divider(),

          // ---------------- Save Button ----------------
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
              onPressed: saveSettings,
            ),
          ),
        ],
      ),
    );
  }
}
