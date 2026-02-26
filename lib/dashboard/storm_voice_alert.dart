import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keep same style as your LandslideVoiceAlert ✅
/// Works for BOTH:
/// - Storm risk: Normal / Storm / Cyclone
/// - Fusion risk: Normal / HighRisk / Extreme (+ fused_event text)
///
/// Use in StormPage:
/// await StormVoiceAlertService.speakStormFusionAlert(_fusedRisk, _fusedEvent);
/// await StormVoiceAlertService.speakStormRiskAlert(_stormRisk);
enum AlertLanguage { english, bangla }

class StormVoiceAlertService {
  static final FlutterTts _tts = FlutterTts();
  static final AudioPlayer _player = AudioPlayer();

  static DateTime? _lastSpoken;
  static const Duration cooldown = Duration(minutes: 3); // storm is fast-changing

  static AlertLanguage _language = AlertLanguage.english;
  static bool _initialized = false;

  // ================= INIT =================
  static Future<void> init() async {
    if (_initialized) return;

    await _loadLanguage();
    await _applyLanguageSettings();

    await _tts.setSpeechRate(0.50);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.05);
    await _tts.awaitSpeakCompletion(true);

    _initialized = true;
  }

  // ================= LANGUAGE =================
  static Future<void> setLanguage(AlertLanguage lang) async {
    _language = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'storm_alert_language',
      lang == AlertLanguage.bangla ? 'bn' : 'en',
    );
    await _applyLanguageSettings();
  }

  static AlertLanguage get currentLanguage => _language;

  static Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('storm_alert_language');
    _language = saved == 'bn' ? AlertLanguage.bangla : AlertLanguage.english;
  }

  static Future<void> _applyLanguageSettings() async {
    if (_language == AlertLanguage.bangla) {
      await _tts.setLanguage("bn-BD"); // 🇧🇩 Bangla
    } else {
      await _tts.setLanguage("en-US"); // 🇺🇸 English
    }
  }

  // ================= COOLDOWN HELPERS =================
  static Future<void> _speakWithCooldown(String message,
      {bool playSiren = true}) async {
    final now = DateTime.now();
    if (_lastSpoken != null && now.difference(_lastSpoken!) < cooldown) {
      return;
    }
    _lastSpoken = now;

    // 🚨 siren first (optional)
    if (playSiren) {
      try {
        await _player.play(AssetSource('sounds/siren.mp3'));
        await Future.delayed(const Duration(seconds: 1));
      } catch (_) {}
    }

    try {
      await _tts.stop();
      await _tts.speak(message);
    } catch (_) {}
  }

  // ================= STORM-ONLY ALERT =================
  /// Call when storm risk becomes Storm/Cyclone (optional).
  /// Normal: no speech
  static Future<void> speakStormRiskAlert(String stormRisk) async {
    final msg = _language == AlertLanguage.bangla
        ? _banglaStormRiskMessage(stormRisk)
        : _englishStormRiskMessage(stormRisk);

    if (msg == null) return;

    final siren = stormRisk == "Cyclone"; // siren only for Cyclone
    await _speakWithCooldown(msg, playSiren: siren);
  }

  // ================= FUSION ALERT (RECOMMENDED) =================
  /// Your StormPage already calls this ✅
  /// fusedRisk: Normal / HighRisk / Extreme (or Cyclone/Storm sometimes)
  /// fusedEvent: Cyclone+Flood / FloodLikely / CycloneOnly / StormOnly / ...
  static Future<void> speakStormFusionAlert(
      String fusedRisk, String fusedEvent) async {
    // No speech for Normal
    if (fusedRisk == "Normal" && fusedEvent == "Normal") return;

    final msg = _language == AlertLanguage.bangla
        ? _banglaFusionMessage(fusedRisk, fusedEvent)
        : _englishFusionMessage(fusedRisk, fusedEvent);

    if (msg == null) return;

    // Siren only for the highest danger
    final siren = (fusedRisk == "Extreme") || fusedEvent.contains("Cyclone+Flood");
    await _speakWithCooldown(msg, playSiren: siren);
  }

  // ================= MESSAGES =================

  // 🌍 English (storm risk)
  static String? _englishStormRiskMessage(String stormRisk) {
    switch (stormRisk) {
      case "Cyclone":
        return "Emergency! Cyclone conditions detected. Take shelter immediately and follow official instructions.";
      case "Storm":
        return "Warning! Strong storm conditions detected. Stay indoors and avoid travel if possible.";
      default:
        return null; // Normal: no speech
    }
  }

  // 🇧🇩 Bangla (storm risk)
  static String? _banglaStormRiskMessage(String stormRisk) {
    switch (stormRisk) {
      case "Cyclone":
        return "জরুরি সতর্কতা! ঘূর্ণিঝড়ের পরিস্থিতি শনাক্ত হয়েছে। দ্রুত আশ্রয়ে যান এবং সরকারি নির্দেশনা অনুসরণ করুন।";
      case "Storm":
        return "সতর্কবার্তা! শক্তিশালী ঝড়ের পরিস্থিতি রয়েছে। ঘরের ভেতরে থাকুন এবং প্রয়োজনে যাত্রা এড়িয়ে চলুন।";
      default:
        return null;
    }
  }

  // 🌍 English (fusion)
  static String? _englishFusionMessage(String fusedRisk, String fusedEvent) {
    // Highest level
    if (fusedRisk == "Extreme" || fusedEvent == "Cyclone+Flood") {
      return "Extreme danger! $fusedEvent detected. Evacuate to a safe place and avoid rivers and low areas.";
    }

    // HighRisk level
    if (fusedRisk == "HighRisk") {
      if (fusedEvent == "FloodLikely") {
        return "High risk! Flood likely due to rising water and heavy conditions. Move valuables higher and stay alert.";
      }
      if (fusedEvent == "Cyclone+HeavyRain") {
        return "High risk! Cyclone and heavy rain detected. Stay sheltered and prepare for flooding.";
      }
      return "High risk event detected: $fusedEvent. Stay alert and follow safety instructions.";
    }

    // Storm/Cyclone (sometimes you may write these into fused_risk)
    if (fusedRisk == "Cyclone") {
      return "Cyclone risk is high. Take shelter immediately and follow official warnings.";
    }
    if (fusedRisk == "Storm") {
      return "Storm risk detected. Stay indoors and remain cautious.";
    }

    // Otherwise: no speech
    return null;
  }

  // 🇧🇩 Bangla (fusion)
  static String? _banglaFusionMessage(String fusedRisk, String fusedEvent) {
    if (fusedRisk == "Extreme" || fusedEvent == "Cyclone+Flood") {
      return "চরম বিপদ! $fusedEvent শনাক্ত হয়েছে। দ্রুত নিরাপদ স্থানে চলে যান এবং নদী ও নিচু এলাকা এড়িয়ে চলুন।";
    }

    if (fusedRisk == "HighRisk") {
      if (fusedEvent == "FloodLikely") {
        return "উচ্চ ঝুঁকি! বন্যার সম্ভাবনা রয়েছে। গুরুত্বপূর্ণ জিনিস উঁচুতে রাখুন এবং সতর্ক থাকুন।";
      }
      if (fusedEvent == "Cyclone+HeavyRain") {
        return "উচ্চ ঝুঁকি! ঘূর্ণিঝড় ও ভারী বৃষ্টি রয়েছে। আশ্রয়ে থাকুন এবং বন্যার জন্য প্রস্তুত থাকুন।";
      }
      return "উচ্চ ঝুঁকির ঘটনা শনাক্ত হয়েছে: $fusedEvent। সতর্ক থাকুন এবং নির্দেশনা অনুসরণ করুন।";
    }

    if (fusedRisk == "Cyclone") {
      return "ঘূর্ণিঝড়ের ঝুঁকি বেশি। দ্রুত আশ্রয়ে যান এবং সতর্কবার্তা অনুসরণ করুন।";
    }
    if (fusedRisk == "Storm") {
      return "ঝড়ের ঝুঁকি রয়েছে। ঘরের ভেতরে থাকুন এবং সতর্ক থাকুন।";
    }

    return null;
  }
}