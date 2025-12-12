import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // ADDED
import '../provider/theme_provider.dart'; // ADDED
// import 'posture_monitoring_screen.dart'; // Not needed since routes are used

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Access ThemeProvider state
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.currentBrightness == Brightness.dark;

    // Theme-aware colors
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subtitleColor = textColor.withOpacity(0.6);

    return Scaffold(
      extendBodyBehindAppBar: true,
      // Use Scaffold's background color defined in theme_provider.dart
      body: Container(
        // THEME CHANGE: Conditional Background Gradient
        decoration: BoxDecoration(
          gradient: isDarkMode
              ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A1A2E), // Deep Dark Blue/Black
              Color(0xFF16213E), // Slightly lighter Dark Blue
            ],
          )
              : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFFFFF), // White
              Color(0xFFF0F0F0), // Off-White
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Custom Header Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Head Tracker",
                          style: TextStyle(
                            color: textColor.withOpacity(0.9), // THEME CHANGE: Text color
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.greenAccent, // Status light is always bright
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "System Active",
                              style: TextStyle(
                                color: subtitleColor, // THEME CHANGE: Text color
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // 2. The Grid
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  padding: const EdgeInsets.all(16),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.85,
                  children: [
                    _buildMenuCard(
                        context,
                        "Live Data",
                        Icons.show_chart_rounded,
                        "/liveData",
                        Colors.blueAccent,
                        "Real-time graphs",
                        isDarkMode
                    ),
                    _buildMenuCard(
                        context,
                        "Posture Monitoring",
                        Icons.motion_photos_on_rounded,
                        "/postureMonitor",
                        Colors.purpleAccent,
                        "Track your Posture",
                        isDarkMode
                    ),
                    _buildMenuCard(
                        context,
                        "Bluetooth",
                        Icons.bluetooth_connected_rounded,
                        "/deviceConnect",
                        Colors.orangeAccent,
                        "Manage devices",
                        isDarkMode
                    ),
                    _buildMenuCard(
                        context,
                        "Settings",
                        Icons.tune_rounded,
                        "/settings",
                        Colors.pinkAccent,
                        "App preferences",
                        isDarkMode
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // THEME CHANGE: Added isDarkMode parameter to the helper function
  Widget _buildMenuCard(
      BuildContext context,
      String title,
      IconData icon,
      String route,
      Color accentColor,
      String subtitle,
      bool isDarkMode
      ) {

    final cardTextColor = isDarkMode ? Colors.white : Colors.black87;

    // THEME CHANGE: Card gradient and border must be conditional
    final cardGradient = isDarkMode
        ? [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)] // Dark mode transparent look
        : [Colors.white.withOpacity(0.8), Colors.white.withOpacity(0.7)]; // Light mode background

    final cardBorderColor = isDarkMode
        ? Colors.white.withOpacity(0.1)
        : Colors.black.withOpacity(0.1);


    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          // THEME CHANGE: Shadow is softer/lighter in Light Mode
          BoxShadow(
            color: isDarkMode ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => Navigator.pushNamed(context, route),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: cardGradient,
              ),
              border: Border.all(
                  color: cardBorderColor,
                  width: 1
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Icon Container
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 32, color: accentColor),
                  ),

                  // Text Content
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: cardTextColor, // THEME CHANGE: Text color
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: cardTextColor.withOpacity(0.5), // THEME CHANGE: Subtitle color
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}