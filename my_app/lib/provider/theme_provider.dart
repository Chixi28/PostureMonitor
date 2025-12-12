import 'package:flutter/material.dart';

class ThemeProvider with ChangeNotifier {
  // Use Brightness.dark as the initial default theme, matching your original code.
  Brightness _currentBrightness = Brightness.dark;

  Brightness get currentBrightness => _currentBrightness;

  // Define the dark theme properties
  ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    primarySwatch: Colors.red,
    // The background color for your Scaffold when dark
    scaffoldBackgroundColor: const Color(0xFF0C0C0C),
    // Note: GoogleFonts text theme should be applied in main.dart
  );

  // Define the light theme properties
  ThemeData get lightTheme => ThemeData(
    brightness: Brightness.light,
    primarySwatch: Colors.red,
    // A light background color
    scaffoldBackgroundColor: const Color(0xFFF0F0F0),
    // Update app bar color for light mode clarity
    appBarTheme: const AppBarTheme(
      color: Colors.white,
      iconTheme: IconThemeData(color: Colors.black),
      titleTextStyle: TextStyle(color: Colors.black),
      elevation: 1,
    ),
  );

  // The method to toggle the theme
  void toggleTheme() {
    _currentBrightness =
    _currentBrightness == Brightness.dark
        ? Brightness.light
        : Brightness.dark;
    notifyListeners();
  }
}