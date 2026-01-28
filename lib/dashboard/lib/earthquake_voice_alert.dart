import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AlertLanguage { english, bangla }

class VoiceAlertService {
  static final FlutterTts _tts = FlutterTts();
  static final AudioPlayer _player = AudioPlayer();

  static DateTime? _lastSpoken;
  static const Duration cooldown = Duration(minutes: 5);

  static AlertLanguage _language = AlertLanguage.english;
  static bool _initialized = false;

  // ================= INIT =================
  static Future<void> init() async {
    if (_initialized) return;

    await _loadLanguage();
    await _applyLanguageSettings();

    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(true);

    _initialized = true;
  }

  // ================= LANGUAGE =================
  static Future<void> setLanguage(AlertLanguage lang) async {
    _language = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'alert_language',
      lang == AlertLanguage.bangla ? 'bn' : 'en',
    );

    await _applyLanguageSettings();
  }

  static AlertLanguage get currentLanguage => _language;

  static Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('alert_language');

    _language =
    saved == 'bn' ? AlertLanguage.bangla : AlertLanguage.english;
  }

  static Future<void> _applyLanguageSettings() async {
    if (_language == AlertLanguage.bangla) {
      await _tts.setLanguage("bn-BD"); // 🇧🇩 Bangla
    } else {
      await _tts.setLanguage("en-US"); // 🇺🇸 English
    }
  }

  // ================= EARTHQUAKE ALERT =================
  static Future<void> speakEarthquakeAlert(String level) async {
    final now = DateTime.now();
    if (_lastSpoken != null &&
        now.difference(_lastSpoken!) < cooldown) return;

    _lastSpoken = now;

    final message = _language == AlertLanguage.bangla
        ? _earthquakeBangla(level)
        : _earthquakeEnglish(level);

    if (message == null) return;

    // 🔊 Siren sound (optional)
    try {
      await _player.play(AssetSource('sounds/siren.mp3'));
      await Future.delayed(const Duration(seconds: 1));
    } catch (_) {}

    try {
      await _tts.stop();
      await _tts.speak(message);
    } catch (_) {}
  }

  // ================= MESSAGES =================

  // 🌍 English
  static String? _earthquakeEnglish(String level) {
    switch (level) {
      case "Critical":
        return "Emergency. Strong earthquake detected. Drop, cover, and hold on immediately.";
      case "High":
        return "Warning. High earthquake risk detected. Stay alert and move to a safe area.";
      case "Medium":
        return "Caution. Moderate earthquake activity detected. Remain cautious.";
      default:
        return null;
    }
  }

  // 🇧🇩 Bangla
  static String? _earthquakeBangla(String level) {
    switch (level) {
      case "Critical":
        return "জরুরি সতর্কতা। শক্তিশালী ভূমিকম্প শনাক্ত হয়েছে। অবিলম্বে নিচু হয়ে বসুন, মাথা ঢাকুন এবং নিরাপদ থাকুন।";
      case "High":
        return "সতর্কবার্তা। আপনার এলাকায় উচ্চমাত্রার ভূমিকম্পের ঝুঁকি রয়েছে। নিরাপদ স্থানে থাকুন।";
      case "Medium":
        return "সতর্কতা। মাঝারি মাত্রার ভূমিকম্পের কার্যকলাপ শনাক্ত হয়েছে। সাবধান থাকুন।";
      default:
        return null;
    }
  }
}
