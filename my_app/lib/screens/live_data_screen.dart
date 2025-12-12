import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider/theme_provider.dart';
import '../bluetooth/bluetooth_manager.dart';
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
  List<double> accelerometerHistoryX = [];
  List<double> accelerometerHistoryY = [];
  List<double> accelerometerHistoryZ = [];
  int maxHistoryPoints = 50;
  String selectedSensor = 'accelerometer';
  Map<String, double> accelerometerData = {'x': 0.0, 'y': 0.0, 'z': 0.0};
  String sensorData = '';
  bool isConnected = false;

  @override
  void initState() {
    super.initState();
    bluetoothManager.addConnectionCallback(_handleConnectionChanged);
    bluetoothManager.addAccelerometerCallback(_handleAccelerometerData);
    bluetoothManager.addSensorDataCallback(_handleSensorData);
    isConnected = bluetoothManager.isConnected;
  }

  void _handleConnectionChanged(bool connected) {
    if (mounted) {
      setState(() {
        isConnected = connected;
      });
    }
  }

  void _handleAccelerometerData(Map<String, double> data) {
    if (mounted) {
      setState(() {
        accelerometerData = data;
        _updateHistory(data);
      });
    }
  }

  void _handleSensorData(String data) {
    if (mounted) {
      setState(() {
        sensorData = data;
      });
    }
  }

  void _updateHistory(Map<String, double> data) {
    accelerometerHistoryX.add(data['x'] ?? 0.0);
    accelerometerHistoryY.add(data['y'] ?? 0.0);
    accelerometerHistoryZ.add(data['z'] ?? 0.0);

    if (accelerometerHistoryX.length > maxHistoryPoints) {
      accelerometerHistoryX.removeAt(0);
      accelerometerHistoryY.removeAt(0);
      accelerometerHistoryZ.removeAt(0);
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
              color: dataTextColor, // THEME CHANGE
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
              color: containerColor, // THEME CHANGE
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

  Widget _buildChartLegend(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // --- Utility Calculations (Unchanged) ---
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
        // Icon and text colors are now handled by AppBarTheme in theme_provider.dart
      ),
      body: Container(
        // THEME CHANGE: Conditional Background Gradient
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
                  // THEME CHANGE: Container color
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
                          bluetoothManager.connectedDevice?.platformName ?? 'OpenEarable Device',
                          style: TextStyle(
                            color: textColor, // THEME CHANGE: Text color
                            fontSize: 14,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: textColor.withOpacity(0.7)), // THEME CHANGE: Icon color
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
                        // THEME CHANGE: Container color and border
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
                                color: textColor.withOpacity(0.7), // THEME CHANGE: Text color
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _calculateMagnitude(accelerometerData).toStringAsFixed(3),
                              style: TextStyle(
                                color: dataTextColor, // THEME CHANGE: Text color
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Courier',
                              ),
                            ),
                            Text(
                              'g',
                              style: TextStyle(
                                color: textColor.withOpacity(0.5), // THEME CHANGE: Text color
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
                        // THEME CHANGE: Container color and border
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
                                color: textColor.withOpacity(0.7), // THEME CHANGE: Text color
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

                const SizedBox(height: 20),

                // 3. Main Chart Area
                Text(
                  "REAL-TIME PLOT",
                  style: TextStyle(
                    color: textColor.withOpacity(0.54), // THEME CHANGE: Text color
                    fontSize: 12,
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    // THEME CHANGE: Container color and border
                    decoration: BoxDecoration(
                      color: containerColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: textColor.withOpacity(0.1)),
                    ),
                    child: Column(
                      children: [
                        // Chart legend
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildChartLegend('X', Colors.redAccent),
                            const SizedBox(width: 20),
                            _buildChartLegend('Y', Colors.greenAccent),
                            const SizedBox(width: 20),
                            _buildChartLegend('Z', Colors.blueAccent),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Chart area
                        Expanded(
                          child: accelerometerHistoryX.isNotEmpty
                              ? CustomPaint(
                            painter: ChartPainter(
                              dataX: accelerometerHistoryX,
                              dataY: accelerometerHistoryY,
                              dataZ: accelerometerHistoryZ,
                              colorX: Colors.redAccent,
                              colorY: Colors.greenAccent,
                              colorZ: Colors.blueAccent,
                              gridColor: textColor.withOpacity(0.08), // THEME CHANGE: Grid color
                            ),
                          )
                              : Center(
                            child: Text(
                              "STREAMING DATA...",
                              style: TextStyle(
                                color: textColor.withOpacity(0.3), // THEME CHANGE: Text color
                                fontFamily: "Courier",
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- Chart Painter (Modified) ---

class ChartPainter extends CustomPainter {
  final List<double> dataX;
  final List<double> dataY;
  final List<double> dataZ;
  final Color colorX;
  final Color colorY;
  final Color colorZ;
  final Color gridColor; // ADDED: Theme-aware grid color

  ChartPainter({
    required this.dataX,
    required this.dataY,
    required this.dataZ,
    required this.colorX,
    required this.colorY,
    required this.colorZ,
    required this.gridColor, // ADDED
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor // THEME CHANGE: Use dynamic grid color
      ..strokeWidth = 1;

    // Draw grid lines
    for (var i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }

    // Find min and max values for scaling
    final allData = [...dataX, ...dataY, ...dataZ];
    final maxVal = allData.isNotEmpty ? allData.map((e) => e.abs()).reduce(max) : 1.0;
    final minVal = -maxVal;

    // Draw X, Y, Z lines
    _drawLine(canvas, size, dataX, colorX, minVal, maxVal);
    _drawLine(canvas, size, dataY, colorY, minVal, maxVal);
    _drawLine(canvas, size, dataZ, colorZ, minVal, maxVal);
  }

  void _drawLine(Canvas canvas, Size size, List<double> data, Color color, double minVal, double maxVal) {
    if (data.length < 2) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    final valueRange = maxVal - minVal;

    for (var i = 0; i < data.length; i++) {
      final x = size.width * i / (data.length - 1);
      final normalizedValue = (data[i] - minVal) / valueRange;
      final y = size.height * (1 - normalizedValue);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}