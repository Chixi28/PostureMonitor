import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider/theme_provider.dart';
import '../bluetooth/open_earable_manager.dart';
import 'dart:math';

class LiveDataScreen extends StatefulWidget {
  const LiveDataScreen({super.key});

  @override
  State<LiveDataScreen> createState() => _LiveDataScreenState();
}

class _LiveDataScreenState extends State<LiveDataScreen> {
  // Use singleton instance
  final BluetoothManager bluetoothManager = BluetoothManager.instance;

  // Local state
  String selectedSensor = 'accelerometer';
  Map<String, double> accelerometerData = {'x': 0.0, 'y': 0.0, 'z': 0.0};
  String sensorData = '';
  bool isConnected = false;

  @override
  void initState() {
    super.initState();
    print('[LiveDataScreen] initState: registering callbacks');
    bluetoothManager.addConnectionCallback(_handleConnectionChanged);
    bluetoothManager.addAccelerometerCallback(_handleAccelerometerData);
    bluetoothManager.addSensorDataCallback(_handleSensorData);
    isConnected = bluetoothManager.isConnected;
    print('[LiveDataScreen] initState: isConnected=$isConnected');

    // If already connected, ensure sensors are subscribed (helps recover on hot restart)
    if (isConnected) {
      bluetoothManager.ensureSensorSubscriptions().catchError((e) {
        print('ensureSensorSubscriptions error: $e');
      });
    }
  }

  void _handleConnectionChanged(bool connected) {
    if (mounted) {
      setState(() {
        isConnected = connected;
      });

      if (connected) {
        // Try to ensure subscriptions are in place when a connection is established
        bluetoothManager.ensureSensorSubscriptions().catchError((e) {
          print('ensureSensorSubscriptions error (on connect): $e');
        });
      }
    }
  }

  void _handleAccelerometerData(Map<String, double> data) {
    print('[LiveDataScreen] _handleAccelerometerData called: x=${data['x']?.toStringAsFixed(2)} y=${data['y']?.toStringAsFixed(2)} z=${data['z']?.toStringAsFixed(2)}');
    print('[LiveDataScreen] mounted=$mounted');

    if (mounted) {
      setState(() {
        accelerometerData = data;
        print('[LiveDataScreen] setState called, accelerometerData updated');
      });
    } else {
      print('[LiveDataScreen] ⚠️ Widget not mounted, skipping setState');
    }
  }

  void _handleSensorData(String data) {
    if (mounted) {
      setState(() {
        sensorData = data;
      });
    }
  }

  @override
  void dispose() {
    bluetoothManager.removeConnectionCallback(_handleConnectionChanged);
    bluetoothManager.removeAccelerometerCallback(_handleAccelerometerData);
    bluetoothManager.removeSensorDataCallback(_handleSensorData);
    super.dispose();
  }

  // --- Widget Builders (Updated to take theme colors) ---

  Widget _buildReadoutCard(
      String label, String value, Color color, String unit, Color dataTextColor, Color containerColor) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(color: color.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: dataTextColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Courier',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            unit,
            style: TextStyle(
              color: color.withOpacity(0.6),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrientationIndicator(String label, double angle, Color color, Color containerColor, Color dataTextColor) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.8),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              color: containerColor,
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (angle + 180) / 360,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 40,
          child: Text(
            '${angle.toStringAsFixed(0)}°',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  // --- Utility Calculations ---
  double _calculateMagnitude(Map<String, double> data) {
    final x = data['x'] ?? 0.0;
    final y = data['y'] ?? 0.0;
    final z = data['z'] ?? 0.0;
    return sqrt(x * x + y * y + z * z);
  }

  double _calculatePitch(Map<String, double> data) {
    final x = data['x'] ?? 0.0;
    final y = data['y'] ?? 0.0;
    final z = data['z'] ?? 0.0;
    return atan2(-x, sqrt(y * y + z * z)) * 180 / pi;
  }

  double _calculateRoll(Map<String, double> data) {
    final y = data['y'] ?? 0.0;
    final z = data['z'] ?? 0.0;
    return atan2(y, z) * 180 / pi;
  }

  double _calculateYaw(Map<String, double> data) {
    final x = data['x'] ?? 0.0;
    final y = data['y'] ?? 0.0;
    return atan2(y, x) * 180 / pi;
  }

  // --- Main Build Method ---
  @override
  Widget build(BuildContext context) {
    // Access ThemeProvider state
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.currentBrightness == Brightness.dark;

    // Theme-aware colors
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final containerColor = isDarkMode ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05);
    final dataTextColor = isDarkMode ? Colors.white : Colors.black;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Telemetry", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
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
            colors: [Color(0xFFE0E0E0), Color(0xFFF0F0F0)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Connection status
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: containerColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isConnected ? Colors.green : Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          bluetoothManager.connectedDevice?.name ?? bluetoothManager.connectedDevice?.id ?? 'OpenEarable Device',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: textColor.withOpacity(0.7)),
                        onPressed: () => Navigator.pop(context),
                        tooltip: 'Back to Device List',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 1. Digital Readouts (X, Y, Z)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildReadoutCard(
                      "ACCEL X",
                      accelerometerData['x']?.toStringAsFixed(3) ?? '0.000',
                      Colors.redAccent,
                      'g',
                      dataTextColor,
                      containerColor,
                    ),
                    _buildReadoutCard(
                      "ACCEL Y",
                      accelerometerData['y']?.toStringAsFixed(3) ?? '0.000',
                      Colors.greenAccent,
                      'g',
                      dataTextColor,
                      containerColor,
                    ),
                    _buildReadoutCard(
                      "ACCEL Z",
                      accelerometerData['z']?.toStringAsFixed(3) ?? '0.000',
                      Colors.blueAccent,
                      'g',
                      dataTextColor,
                      containerColor,
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // 2. Magnitude and orientation
                Row(
                  children: [
                    // Magnitude
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: containerColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: textColor.withOpacity(0.1)),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'MAGNITUDE',
                              style: TextStyle(
                                color: textColor.withOpacity(0.7),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _calculateMagnitude(accelerometerData).toStringAsFixed(3),
                              style: TextStyle(
                                color: dataTextColor,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Courier',
                              ),
                            ),
                            Text(
                              'g',
                              style: TextStyle(
                                color: textColor.withOpacity(0.5),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Orientation indicators
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: containerColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: textColor.withOpacity(0.1)),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'ORIENTATION',
                              style: TextStyle(
                                color: textColor.withOpacity(0.7),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildOrientationIndicator(
                              'Pitch',
                              _calculatePitch(accelerometerData),
                              Colors.purpleAccent,
                              containerColor,
                              dataTextColor,
                            ),
                            const SizedBox(height: 8),
                            _buildOrientationIndicator(
                              'Roll',
                              _calculateRoll(accelerometerData),
                              Colors.orangeAccent,
                              containerColor,
                              dataTextColor,
                            ),
                            const SizedBox(height: 8),
                            _buildOrientationIndicator(
                              'Yaw',
                              _calculateYaw(accelerometerData),
                              Colors.cyanAccent,
                              containerColor,
                              dataTextColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 15),

                // Additional Data Display
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    width: 200,
                    decoration: BoxDecoration(
                      color: containerColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: textColor.withOpacity(0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center, // Changed from start to center
                      children: [
                        Text(
                          'SENSOR DATA',
                          style: TextStyle(
                            color: textColor.withOpacity(0.7),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center, // Also center the row
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center, // Center column content
                              children: [
                                Text(
                                  'Device Status',
                                  style: TextStyle(
                                    color: textColor.withOpacity(0.6),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isConnected ? 'Connected' : 'Disconnected',
                                  style: TextStyle(
                                    color: isConnected ? Colors.green : Colors.red,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
                ,
                const Expanded(
                  child: SizedBox(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}