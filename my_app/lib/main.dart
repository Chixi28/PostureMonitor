import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/live_data_screen.dart';
import 'screens/device_connect_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/posture_monitoring_screen.dart';
import 'package:my_app/provider/theme_provider.dart';

/// Entry point of the application.
///
/// Initializes the global [ThemeProvider] using [ChangeNotifierProvider]
/// and injects it into the widget tree so that the theme can be changed
/// dynamically at runtime.
void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: const HeadNodApp(),
    ),
  );
}

/// Root widget of the Head Nod Tracker application.
///
/// This widget configures:
/// - Global theming (light/dark mode)
/// - Google Fonts integration
/// - Named route navigation
///
/// It listens to [ThemeProvider] to reactively update the app’s appearance
/// when the user changes the theme from the settings screen.
class HeadNodApp extends StatelessWidget {
  const HeadNodApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Head Nod Tracker",

      /// Dynamically selects the active theme based on the current brightness
      /// exposed by [ThemeProvider], and applies the Inter font across
      /// the entire app using Google Fonts.
      theme: (themeProvider.currentBrightness == Brightness.dark
              ? themeProvider.darkTheme
              : themeProvider.lightTheme)
          .copyWith(
        textTheme: GoogleFonts.interTextTheme(
          Theme.of(context).textTheme.apply(
                bodyColor:
                    themeProvider.currentBrightness == Brightness.dark
                        ? Colors.white
                        : Colors.black87,
              ),
        ),
      ),

      /// Defines the initial route shown when the app starts.
      initialRoute: "/splash",

      /// Centralized named route configuration for all screens
      /// in the application.
      routes: {
        "/splash": (_) => const SplashScreen(),
        "/home": (_) => const HomeScreen(),
        "/liveData": (_) => LiveDataScreen(),
        "/deviceConnect": (_) => DeviceConnectScreen(),
        "/postureMonitor": (_) => PostureMonitorScreen(),
        "/settings": (_) => const SettingsScreen(),
      },
    );
  }
}