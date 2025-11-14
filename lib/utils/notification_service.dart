import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// 🔹 Initialize notifications (must be called in main.dart)
  static Future<void> initialize() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
    );

    await _notificationsPlugin.initialize(settings);
  }

  /// 🔹 Show a notification if user enabled alerts
  static Future<void> showAlertNotification(String title, String body) async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('notificationsEnabled') ?? true; // default ON

    if (!enabled) {
      debugPrint("🔕 Notifications disabled by user.");
      return;
    }

    // ✅ Android notification details (non-const because of Color)
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'flood_alerts', // channel id
          'Flood Alerts', // channel name
          channelDescription: 'Immediate flood warning notifications',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          color: const Color(0xFF1565C0),
          icon: '@mipmap/ic_launcher',
        );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _notificationsPlugin.show(
      0, // notification id
      title,
      body,
      notificationDetails,
    );
  }

  /// 🔹 Save user preference for notifications
  static Future<void> setNotificationEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notificationsEnabled', value);
  }

  /// 🔹 Get saved preference
  static Future<bool> isNotificationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notificationsEnabled') ?? true;
  }
}
