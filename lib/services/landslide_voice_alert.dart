import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AlertLanguage { english, bangla }

class LandslideVoiceAlert {
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
      'landslide_alert_language',
      lang == AlertLanguage.bangla ? 'bn' : 'en',
    );
    await _applyLanguageSettings();
  }

  static AlertLanguage get currentLanguage => _language;

  static Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('landslide_alert_language');
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

  // ================= LANDSLIDE ALERT =================
  static Future<void> speakLandslideAlert(String level) async {
    final now = DateTime.now();
    if (_lastSpoken != null && now.difference(_lastSpoken!) < cooldown) {
      return; // Cooldown not passed
    }

    _lastSpoken = now;

    final message = _language == AlertLanguage.bangla
        ? _banglaMessage(level)
        : _englishMessage(level);

    if (message == null) return;

    // 🔊 Optional siren
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
  static String? _englishMessage(String level) {
    switch (level) {
      case "Critical":
        return "Emergency! Severe landslide detected. Evacuate immediately and move to safe ground.";
      case "High":
        return "Warning! High landslide risk detected. Stay alert and prepare for evacuation.";
      case "Medium":
        return "Caution! Moderate landslide risk. Be careful and monitor updates.";
      default:
        return null; // Low or unknown: no speech
    }
  }

  // 🇧🇩 Bangla
  static String? _banglaMessage(String level) {
    switch (level) {
      case "Critical":
        return "জরুরি সতর্কতা! গুরুতর ভূমিধস শনাক্ত হয়েছে। অবিলম্বে নিরাপদ স্থানে চলে যান।";
      case "High":
        return "সতর্কবার্তা! উচ্চমাত্রার ভূমিধস ঝুঁকি রয়েছে। সতর্ক থাকুন এবং প্রস্তুত থাকুন।";
      case "Medium":
        return "সতর্কতা! মাঝারি ভূমিধস ঝুঁকি। সাবধান থাকুন এবং আপডেট মনিটর করুন।";
      default:
        return null; // Low or unknown: no speech
    }
  }
}
