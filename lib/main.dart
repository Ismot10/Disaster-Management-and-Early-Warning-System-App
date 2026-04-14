import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'utils/notification_service.dart';
import 'firebase_options.dart';

// ✅   theme notifier
import 'theme_notifier.dart';

// ✅   pages

import 'splash/splash_page.dart';
import 'onboarding/welcome_page.dart';
import 'onboarding/location_page.dart';
import 'onboarding/notification_page.dart';
import 'onboarding/complete_page.dart';
import 'dashboard/dashboard_page.dart';

// 🔹 Global notification plugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔹 Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await NotificationService.initialize(); // ✅ initialize notifications here


  // 🔹 Initialize local notifications
  const AndroidInitializationSettings androidInit =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initSettings = InitializationSettings(
    android: androidInit,
  );

  await flutterLocalNotificationsPlugin.initialize(initSettings);

  // ✅ Run the app with ThemeNotifier
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeNotifier(),
      child: const AlertNovaApp(),
    ),
  );
}

class AlertNovaApp extends StatelessWidget {
  const AlertNovaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    return MaterialApp(
      title: 'AlertNova 1.0',
      debugShowCheckedModeBanner: false,

      // ✅ Light/Dark theme
      themeMode: themeNotifier.themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),

      // ✅ App routes
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashPage(),
        '/welcome': (context) => const WelcomePage(),
        '/location': (context) => const LocationPage(),
        '/notification': (context) => const NotificationPage(),
        '/complete': (context) => const CompletePage(),
        '/dashboard': (context) => const DashboardPage(),
      },
    );
  }
}
