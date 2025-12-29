import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import '../provider/theme_provider.dart'; // REQUIRED for theming
import '../bluetooth/open_earable_manager.dart';
import 'live_data_screen.dart';

/// Device Connect Screen
///
/// This file implements a Flutter screen for scanning, connecting, and managing OpenEarable Bluetooth devices.
/// It provides a user interface for device discovery, connection management, and navigation to live sensor data.
///
/// Features:
/// - Scans for nearby OpenEarable Bluetooth devices and displays them in a list.
/// - Allows users to connect to or disconnect from a device.
/// - Shows connection status and device information.
/// - Navigates to the live data screen for real-time sensor telemetry.
/// - Handles sensor data callbacks and updates UI accordingly.
/// - Adapts UI to light/dark themes using Provider.

/// Main screen widget for device connection and management.
///
/// Displays available devices, connection status, and navigation to sensor data.
class DeviceConnectScreen extends StatefulWidget {
  const DeviceConnectScreen({super.key});

  @override
  State<DeviceConnectScreen> createState() => _DeviceConnectScreenState();
}

/// State class for [DeviceConnectScreen].
///
/// Handles scanning, connecting, disconnecting, and UI updates for device management.
class _DeviceConnectScreenState extends State<DeviceConnectScreen> {
  /// Singleton instance for managing Bluetooth and sensor data.
  final BluetoothManager bluetoothManager = BluetoothManager.instance;

  List<DiscoveredDevice> devices = [];
  bool isScanning = false;
  bool isConnected = false;
  String sensorData = '';
  DiscoveredDevice? connectedDevice;

  @override
  void initState() {
    super.initState();

    // ========== SET UP CALLBACKS ==========
    bluetoothManager.addConnectionCallback(_handleConnectionChanged);
    bluetoothManager.addSensorDataCallback(_handleSensorData);

    // Initialize with current state
    isConnected = bluetoothManager.isConnected;
    connectedDevice = bluetoothManager.connectedDevice;
  }

  void _handleConnectionChanged(bool connected) {
    if (mounted) {
      setState(() {
        isConnected = connected;
        connectedDevice = bluetoothManager.connectedDevice;
        if (!connected) {
          // If disconnected, clear UI data
          sensorData = '';
        }
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

  /// Starts scanning and updates the devices list with filtered OpenEarable devices
  Future<void> startScan() async {
    if (isScanning) return;

    setState(() => isScanning = true);
    devices.clear();

    try {
      final scannedDevices = await bluetoothManager.startScan(timeout: const Duration(seconds: 5));
      setState(() => devices = scannedDevices);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Scan error: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => isScanning = false);
    }
  }

  // 💡 NEW: Extracted common data stream setup logic (now includes gyroscope)
  Future<void> _startDataStream() async {
    

    // Configure device to enable both sensors
    await bluetoothManager.configureSensors(accel: true, gyro: true, mag: false);


    
  }


  /// Connect to a device and set up sensor data streaming
  Future<void> connectToDevice(DiscoveredDevice device) async {
    try {
      // Show connecting indicator
      if (mounted) {
        final label = device.name.isNotEmpty ? device.name : device.id;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connecting to $label...'),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      final connected = await bluetoothManager.connectToDevice(device);

      if (connected) {
        await _startDataStream(); // Use the new extracted method

        if (mounted) {
          // Get battery level
          final battery = await bluetoothManager.getBatteryLevel();

          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Connected! Battery: ${battery ?? 'N/A'}%'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Connection failed');
      }
    } catch (e) {
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to connect: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Disconnect from the current device
  Future<void> disconnect() async {
    try {
      // Disconnecting also calls unsubscribeAll() in BluetoothManager
      await bluetoothManager.disconnect();
      // Callback will update the UI

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Disconnected'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    // ignore: empty_catches
    } catch (e) {
    }
  }

  @override
  void dispose() {
    // ========== REMOVE CALLBACKS ==========
    bluetoothManager.removeConnectionCallback(_handleConnectionChanged);
    bluetoothManager.removeSensorDataCallback(_handleSensorData);
    super.dispose();
  }

  // --- Widget Builders (Updated for theming) ---

  Widget _buildDeviceTile(DiscoveredDevice result, bool isDarkMode) {
    final deviceName = result.name.isNotEmpty ? result.name : result.id;

    final isAlreadyConnected = isConnected &&
        bluetoothManager.connectedDevice?.id == result.id;

    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subtitleColor = textColor.withValues(alpha: 0.5);

    // Theme-aware colors for the tile
    final tileBackgroundColor = isAlreadyConnected
        ? Colors.green.withValues(alpha: 0.1)
        : isDarkMode
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.05);

    final tileBorderColor = isAlreadyConnected
        ? Colors.green
        : isDarkMode
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.1);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: tileBackgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: tileBorderColor,
          width: isAlreadyConnected ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isAlreadyConnected
                ? Colors.green.withValues(alpha: 0.2)
                : Colors.blueAccent.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isAlreadyConnected ? Icons.bluetooth_connected : Icons.bluetooth,
            color: isAlreadyConnected
                ? Colors.green
                : Colors.blueAccent,
          ),
        ),
        title: Text(
          deviceName.toString(),
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "RSSI: ${result.rssi}",
              style: TextStyle(
                color: subtitleColor,
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: isAlreadyConnected
            ? const Text(
          "CONNECTED",
          style: TextStyle(
            color: Colors.greenAccent,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        )
            : TextButton(
          onPressed: () async {
            await connectToDevice(result);
          },
          style: TextButton.styleFrom(
            backgroundColor: Colors.green.withValues(alpha: 0.2),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: const Text(
            "CONNECT",
            style: TextStyle(
              color: Colors.greenAccent,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    // Access ThemeProvider state
    final isDarkMode = Provider.of<ThemeProvider>(context).currentBrightness == Brightness.dark;

    // Theme-aware colors
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subtitleColor = textColor.withValues(alpha: 0.5);

    // Background Gradient (custom dark mode theme colors from original code)
    final backgroundGradient = isDarkMode
        ? const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1A1A2E), Color(0xFF0F0F1A)],
    )
        : LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Colors.grey[200]!, Colors.white],
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(isConnected ? "Connected" : "Device Scanner"),
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: textColor),
        titleTextStyle: TextStyle(
          color: textColor,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        elevation: 0,
        actions: [
          if (isConnected)
            Padding(
              padding: const EdgeInsets.only(right: 20.0),
              child: IconButton(
                icon: const Icon(Icons.bluetooth_connected, color: Colors.green),
                onPressed: disconnect,
                tooltip: 'Disconnect',
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 20.0),
              child: Icon(
                Icons.radar,
                color: isScanning
                    ? Colors.blueAccent.withValues(alpha: 0.8)
                    : Colors.blueAccent,
              ),
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Connection status banner
              if (isConnected && connectedDevice != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.2),
                    border: const Border(
                      bottom: BorderSide(color: Colors.green, width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.bluetooth_connected, color: Colors.green, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              connectedDevice!.name,
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (sensorData.isNotEmpty)
                              Text(
                                sensorData,
                                style: TextStyle(
                                  color: subtitleColor,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.sensors, color: textColor.withValues(alpha: 0.7)),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LiveDataScreen(),
                            ),
                          );
                        },
                        tooltip: 'View Sensor Data',
                      ),
                    ],
                  ),
                ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
                child: Text(
                  "AVAILABLE DEVICES",
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),

              Expanded(
                child: devices.isEmpty && !isScanning
                    ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.bluetooth_disabled,
                        color: textColor.withValues(alpha: 0.3),
                        size: 60,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "No OpenEarable devices found",
                        style: TextStyle(color: textColor.withValues(alpha: 0.7)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Tap scan to search for devices",
                        style: TextStyle(
                          color: subtitleColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: devices.length,
                  itemBuilder: (context, index) => _buildDeviceTile(devices[index], isDarkMode),
                ),
              ),

              // Scan button at the bottom
              Padding(
                padding: const EdgeInsets.only(bottom: 30.0, left: 20, right: 20),
                child: Row(
                  children: [
                    if (isConnected)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LiveDataScreen(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            foregroundColor: isDarkMode ? Colors.black : Colors.white,
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          icon: const Icon(Icons.sensors),
                          label: const Text(
                            "VIEW SENSOR DATA",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: FloatingActionButton.extended(
                          onPressed: isScanning ? null : startScan,
                          foregroundColor: isDarkMode ? Colors.black : Colors.white,
                          backgroundColor: isScanning
                              ? Colors.blueAccent.withValues(alpha: 0.5)
                              : Colors.blueAccent,
                          icon: Icon(isScanning ? Icons.hourglass_top : Icons.bluetooth_searching),
                          label: const Text(
                            "SCAN FOR DEVICES",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
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
}