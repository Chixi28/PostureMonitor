import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider/theme_provider.dart';

/// Settings screen for configuring application behavior and appearance.
///
/// This screen provides:
/// - Theme configuration (dark/light mode)
/// - Application and device information
/// - Legal and informational links
///
/// The screen relies on [ThemeProvider] for theme state management
/// and adapts its styling dynamically based on the active theme.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

/// State implementation for [SettingsScreen].
///
/// This class contains helper widget builders to ensure consistent
/// styling and layout across different settings sections.
///
/// The screen itself is stateless with respect to theme data; all
/// theme changes are delegated to [ThemeProvider].
class _SettingsScreenState extends State<SettingsScreen> {

  /// Builds a styled section header used to visually separate
  /// logical groups of settings.
  ///
  /// [title] is rendered in uppercase-style formatting with
  /// increased letter spacing for emphasis.
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

  /// Builds a tappable settings tile with an optional navigation action.
  ///
  /// This widget adapts its colors automatically based on the current
  /// theme and displays a trailing arrow when [onTap] is provided.
  Widget _buildSettingTile(
    IconData icon,
    String title,
    String subtitle, {
    VoidCallback? onTap,
  }) {
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subtitleColor = textColor?.withValues(alpha: 0.5);
    final tileColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.05);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Icon(icon, color: textColor?.withValues(alpha: 0.7)),
        title: Text(title, style: TextStyle(color: textColor)),
        subtitle: Text(subtitle, style: TextStyle(color: subtitleColor)),
        trailing: onTap != null
            ? Icon(Icons.arrow_forward_ios, color: subtitleColor, size: 14)
            : null,
        onTap: onTap,
      ),
    );
  }

  /// Builds a switch-based settings tile.
  ///
  /// Typically used for boolean configuration options such as
  /// enabling or disabling dark mode.
  Widget _buildSwitchTile(
    IconData icon,
    String title,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final tileColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.05);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SwitchListTile(
        secondary: Icon(icon, color: textColor?.withValues(alpha: 0.7)),
        title: Text(title, style: TextStyle(color: textColor)),
        value: value,
        activeThumbColor: Colors.deepPurpleAccent,
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode =
        themeProvider.currentBrightness == Brightness.dark;

    final titleTextColor =
        Theme.of(context).appBarTheme.titleTextStyle?.color ??
            (isDarkMode ? Colors.white : Colors.black);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("System Config"),
        titleTextStyle: TextStyle(
          color: titleTextColor,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDarkMode
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1A1A2E),
                    Color(0xFF0F0F1A),
                  ],
                )
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFFFFFF),
                    Color(0xFFF0F0F0),
                  ],
                ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [

              _buildSectionHeader("INTERFACE & ALERTS"),

              _buildSwitchTile(
                Icons.dark_mode,
                "Dark Mode",
                isDarkMode,
                (val) {
                  themeProvider.toggleTheme();
                },
              ),

              const SizedBox(height: 30),

              _buildSectionHeader("APPLICATION & DEVICE INFO"),

              _buildSettingTile(
                Icons.info_outline,
                "OpenEarable Firmware Version",
                "v1.0.4",
              ),

              _buildSettingTile(
                Icons.security,
                "Privacy Policy",
                "View data usage terms",
                onTap: () { },
              ),

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