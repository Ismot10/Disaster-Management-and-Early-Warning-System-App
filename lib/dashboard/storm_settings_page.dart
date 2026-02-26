import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme_notifier.dart';
import '../utils/notification_service.dart';


// ✅ FIX: import your storm voice file correctly (adjust folder if needed)
import '../dashboard/storm_voice_alert.dart';
// or: import '../services/storm_voice_alert.dart';


class StormSettingsPage extends StatefulWidget {
  const StormSettingsPage({super.key});

  @override
  State<StormSettingsPage> createState() => _StormSettingsPageState();
}

class _StormSettingsPageState extends State<StormSettingsPage> {
  bool notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    loadSettings();
  }

  Future<void> loadSettings() async {
    final enabled = await NotificationService.isNotificationEnabled();
    if (!mounted) return;
    setState(() => notificationsEnabled = enabled);
  }

  Future<void> saveSettings() async {
    await NotificationService.setNotificationEnabled(notificationsEnabled);
    if (!mounted) return;

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
            subtitle: const Text("Receive alerts for Storm warnings"),
            value: notificationsEnabled,
            onChanged: (val) {
              setState(() => notificationsEnabled = val);
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
                themeNotifier.toggleTheme(val);
              },
            ),
          ),

          const Divider(),

          // ✅ FIXED: Storm voice language switch
          SwitchListTile(
            title: const Text("Bangla Voice Alerts"),
            subtitle: const Text("সতর্কবার্তা বাংলায় শোনা যাবে"),
            value: StormVoiceAlertService.currentLanguage ==
                AlertLanguage.bangla,
            onChanged: (val) async {
              await StormVoiceAlertService.setLanguage(
                val ? AlertLanguage.bangla : AlertLanguage.english,
              );
              if (!mounted) return;
              setState(() {});
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