import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider/theme_provider.dart'; // Assuming the path lib/providers/theme_provider.dart

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Application/Interface state variables


  // -----------------------------------------------------------------------
  // Helper Widget Builders (REQUIRED TO FIX THE ERROR)
  // -----------------------------------------------------------------------

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 5),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.deepPurpleAccent,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _buildSettingTile(IconData icon, String title, String subtitle, {VoidCallback? onTap}) {
    // Determine appropriate colors based on the current theme
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subtitleColor = textColor?.withOpacity(0.5);
    final tileColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withOpacity(0.05)
        : Colors.black.withOpacity(0.05);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Icon(icon, color: textColor?.withOpacity(0.7)),
        title: Text(title, style: TextStyle(color: textColor)),
        subtitle: Text(subtitle, style: TextStyle(color: subtitleColor)),
        trailing: onTap != null ? Icon(Icons.arrow_forward_ios, color: subtitleColor, size: 14) : null,
        onTap: onTap,
      ),
    );
  }

  Widget _buildSwitchTile(IconData icon, String title, bool value, ValueChanged<bool> onChanged) {
    // Determine appropriate colors based on the current theme
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final tileColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withOpacity(0.05)
        : Colors.black.withOpacity(0.05);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SwitchListTile(
        secondary: Icon(icon, color: textColor?.withOpacity(0.7)),
        title: Text(title, style: TextStyle(color: textColor)),
        value: value,
        activeColor: Colors.deepPurpleAccent,
        onChanged: onChanged,
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Main Build Method
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Access the ThemeProvider
    // Using listen: false here because the themeProvider is only used to call the toggle method,
    // not to rebuild the widget based on theme state (the MaterialApp handles the rebuild).
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.currentBrightness == Brightness.dark;
    final titleTextColor = Theme.of(context).appBarTheme.titleTextStyle?.color
        ?? (isDarkMode ? Colors.white : Colors.black);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("System Config"),
        titleTextStyle: TextStyle(
          color: titleTextColor,
          fontSize: 20, // Enforce a consistent font size
          fontWeight: FontWeight.bold,
        ),
        // Colors handled by AppBarTheme in theme_provider.dart
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        // Conditional gradient based on the theme
        decoration: BoxDecoration(
          gradient: isDarkMode
              ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A1A2E), Color(0xFF0F0F1A)],
          )
              : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFFFFF), Color(0xFFF0F0F0)],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [

              // --- INTERFACE AND ALERTS ---
              _buildSectionHeader("INTERFACE & ALERTS"),

              // 1. Dark Mode
              _buildSwitchTile(
                Icons.dark_mode,
                "Dark Mode",
                isDarkMode, // Use state from provider to set switch value
                    (val) {
                  // Call the toggle method which rebuilds the whole app
                  themeProvider.toggleTheme();
                },
              ),

              const SizedBox(height: 30),

              // --- APPLICATION & DEVICE INFO ---
              _buildSectionHeader("APPLICATION & DEVICE INFO"),

              // 1. Firmware
              _buildSettingTile(
                Icons.info_outline,
                "OpenEarable Firmware Version",
                "v1.0.4",
              ),

              // 2. Privacy Policy
              _buildSettingTile(
                Icons.security,
                "Privacy Policy",
                "View data usage terms",
                onTap: () { /* Navigate to legal page */ },
              ),

              // 3. About
              _buildSettingTile(
                Icons.people_outline,
                "About Head Nod Tracker",
                "Credits and license information",
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: "Head Nod Tracker",
                    applicationVersion: "1.0.0",
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}