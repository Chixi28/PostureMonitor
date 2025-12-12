// main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Import Provider
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/live_data_screen.dart';
import 'screens/device_connect_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/posture_monitoring_screen.dart';
import 'package:google_fonts/google_fonts.dart';

// Import the new ThemeProvider
import 'package:my_app/provider/theme_provider.dart';

void main() {
  runApp(
    // 1. Wrap the app with a ChangeNotifierProvider
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: const HeadNodApp(),
    ),
  );
}

class HeadNodApp extends StatelessWidget {
  const HeadNodApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 2. Listen to the ThemeProvider
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Head Nod Tracker",

      // 3. Set the theme dynamically based on the provider
      theme: (themeProvider.currentBrightness == Brightness.dark
          ? themeProvider.darkTheme
          : themeProvider.lightTheme)
          .copyWith(
        // Apply Google Fonts here, merged with the base theme
        textTheme: GoogleFonts.interTextTheme(
          Theme.of(context).textTheme.apply(
            bodyColor: themeProvider.currentBrightness == Brightness.dark
                ? Colors.white
                : Colors.black87, // Ensure text color switches
          ),
        ),
      ),

      initialRoute: "/splash",
      routes: {
        "/splash": (_) => const SplashScreen(),
        "/home": (_) => const HomeScreen(),
        "/liveData": (_) => LiveDataScreen(),
        "/deviceConnect": (_) => DeviceConnectScreen(),
        "/postureMonitor": (_) => PostureMonitorScreen(),
        // The SettingsScreen will trigger the theme change
        "/settings": (_) => const SettingsScreen(),
      },
    );
  }
}