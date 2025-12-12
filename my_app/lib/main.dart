import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/live_data_screen.dart';
import 'screens/device_connect_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/posture_monitoring_screen.dart'; // Make sure this import is correct
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const HeadNodApp());
}

class HeadNodApp extends StatelessWidget {
  const HeadNodApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Posture Monitorgit push -u origin master",
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.red,
        scaffoldBackgroundColor: const Color(0xFF0C0C0C),
        textTheme: GoogleFonts.interTextTheme(
          Theme.of(context).textTheme.apply(bodyColor: Colors.white),
        ),
      ),
      initialRoute: "/splash",
      routes: {
        "/splash": (_) => const SplashScreen(),
        "/home": (_) => const HomeScreen(),
        "/liveData": (_) => LiveDataScreen(), // Remove const if StatefulWidget
        "/deviceConnect": (_) => DeviceConnectScreen(), // Remove const if StatefulWidget
        "/postureMonitor": (_) => PostureMonitorScreen(), // Remove const if StatefulWidget
        "/settings": (_) => SettingsScreen(), // Remove const if StatefulWidget
      },
    );
  }
}

