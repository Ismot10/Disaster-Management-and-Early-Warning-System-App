import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme_notifier.dart';
import '../utils/notification_service.dart';
import 'lib/services/voice_alert_service.dart';



// ---------------------- SETTINGS PAGE ----------------------
class EarthquakeSettingsPage extends StatefulWidget {
  const EarthquakeSettingsPage({super.key});

  @override
  State<EarthquakeSettingsPage> createState() => _WildfireSettingsPageState();
}

class _WildfireSettingsPageState extends State<EarthquakeSettingsPage> {
  bool notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    loadSettings(); // ✅ Load user preferences when page opens
  }

  Future<void> loadSettings() async {
    final enabled = await NotificationService.isNotificationEnabled();
    setState(() => notificationsEnabled = enabled);
  }

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
        title: const Text("Settings", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepPurple,
      ),
      body: ListView(
        children: [
// ✅ Notifications toggle
          SwitchListTile(
            title: const Text("Enable Notifications"),
            subtitle: const Text("Receive alerts for wildfire warnings"),
            value: notificationsEnabled,
            onChanged: (val) {
              setState(() {
                notificationsEnabled = val;
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

// 🌍 Language switch (Bangla / English)
          SwitchListTile(
            title: const Text("Bangla Voice Alerts"),
            subtitle: const Text("সতর্কবার্তা বাংলায় শোনা যাবে"),
            value: VoiceAlertService.currentLanguage ==
                AlertLanguage.bangla,
            onChanged: (val) async {
              await VoiceAlertService.setLanguage(
                val ? AlertLanguage.bangla : AlertLanguage.english,
              );

              setState(() {}); // refresh UI
            },
          ),

// ✅ Save button
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
