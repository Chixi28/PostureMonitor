import 'package:flutter/material.dart';

/// Centralized theme state manager for the application.
///
/// This provider controls whether the app is displayed in
/// light mode or dark mode and exposes the corresponding
/// [ThemeData] configurations.
///
/// It is designed to be used with `Provider` or
/// `ChangeNotifierProvider` at the root of the widget tree.
class ThemeProvider with ChangeNotifier {
  /// Currently active brightness mode.
  ///
  /// Defaults to [Brightness.dark] to match the original
  /// application design and startup appearance.
  Brightness _currentBrightness = Brightness.dark;

  /// Returns the currently active brightness mode.
  Brightness get currentBrightness => _currentBrightness;

  /// Theme configuration for dark mode.
  ///
  /// This theme defines:
  /// - Dark brightness
  /// - Primary red color palette
  /// - Custom scaffold background color
  ///
  /// Typography (Google Fonts) is applied externally
  /// in `main.dart` to avoid duplication.
  ThemeData get darkTheme => ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.red,
        scaffoldBackgroundColor: const Color(0xFF0C0C0C),
      );

  /// Theme configuration for light mode.
  ///
  /// This theme defines:
  /// - Light brightness
  /// - Primary red color palette
  /// - Light scaffold background color
  /// - Explicit AppBar styling for visual clarity
  ThemeData get lightTheme => ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.red,
        scaffoldBackgroundColor: const Color(0xFFF0F0F0),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          iconTheme: IconThemeData(color: Colors.black),
          titleTextStyle: TextStyle(color: Colors.black),
          elevation: 1,
        ),
      );

  /// Toggles between light and dark themes.
  ///
  /// After switching the brightness mode, all listening
  /// widgets are notified, triggering a rebuild of the UI.
  void toggleTheme() {
    _currentBrightness =
        _currentBrightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark;
    notifyListeners();
  }
}