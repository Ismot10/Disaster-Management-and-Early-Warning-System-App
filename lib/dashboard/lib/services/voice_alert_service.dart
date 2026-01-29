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

  // ================= SPEAK WILDFIRE =================
  static Future<void> speakWildfireAlert(String level) async {
    final now = DateTime.now();
    if (_lastSpoken != null &&
        now.difference(_lastSpoken!) < cooldown) {
      return;
    }

    _lastSpoken = now;

    final message = _language == AlertLanguage.bangla
        ? _wildfireBangla(level)
        : _wildfireEnglish(level);

    if (message == null) return;

    // 🔊 Siren (optional)
    try {
      await _player.play(AssetSource('sounds/siren.mp3'));
      await Future.delayed(const Duration(seconds: 1));
    } catch (_) {}

    try {
      await _tts.stop();
      await _tts.speak(message);
    } catch (_) {}
  }

  // ================= FLOOD (READY FOR USE) =================
  static Future<void> speakFloodAlert(String level) async {
    final message = _language == AlertLanguage.bangla
        ? _floodBangla(level)
        : _floodEnglish(level);

    if (message == null) return;

    try {
      await _tts.stop();
      await _tts.speak(message);
    } catch (_) {}
  }

  // ================= MESSAGES =================

  static String? _wildfireEnglish(String level) {
    switch (level) {
      case "Critical":
        return "Emergency. Wildfire detected nearby. Evacuate immediately.";
      case "High":
        return "Warning. High wildfire risk detected. Stay alert.";
      case "Medium":
        return "Caution. Moderate wildfire risk detected.";
      default:
        return null;
    }
  }

  static String? _wildfireBangla(String level) {
    switch (level) {
      case "Critical":
        return "জরুরি সতর্কতা। আপনার এলাকায় আগুন শনাক্ত হয়েছে। অবিলম্বে নিরাপদ স্থানে যান।";
      case "High":
        return "সতর্কবার্তা। আপনার এলাকায় আগুনের ঝুঁকি বেশি। সাবধান থাকুন।";
      case "Medium":
        return "সতর্কতা। আপনার এলাকায় মাঝারি মাত্রার আগুনের ঝুঁকি রয়েছে।";
      default:
        return null;
    }
  }

  static String? _floodEnglish(String level) {
    switch (level) {
      case "Critical":
        return "Emergency. Severe flood detected. Move to higher ground immediately.";
      case "High":
        return "Warning. High flood risk detected. Prepare to evacuate.";
      case "Medium":
        return "Caution. Moderate flood risk detected.";
      default:
        return null;
    }
  }

  static String? _floodBangla(String level) {
    switch (level) {
      case "Critical":
        return "জরুরি সতর্কতা। ভয়াবহ বন্যা শনাক্ত হয়েছে। অবিলম্বে উঁচু স্থানে যান।";
      case "High":
        return "সতর্কবার্তা। আপনার এলাকায় বন্যার ঝুঁকি বেশি। প্রস্তুত থাকুন।";
      case "Medium":
        return "সতর্কতা। আপনার এলাকায় মাঝারি বন্যার ঝুঁকি রয়েছে।";
      default:
        return null;
    }
  }
}
