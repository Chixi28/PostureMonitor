import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart'; // REQUIRED for theming
import '../provider/theme_provider.dart'; // REQUIRED for theming
import '../bluetooth/bluetooth_manager.dart';
import 'live_data_screen.dart';

class DeviceConnectScreen extends StatefulWidget {
  const DeviceConnectScreen({super.key});

  @override
  State<DeviceConnectScreen> createState() => _DeviceConnectScreenState();
}

class _DeviceConnectScreenState extends State<DeviceConnectScreen> {
  // Use singleton instance
  final BluetoothManager bluetoothManager = BluetoothManager.instance;

  List<ScanResult> devices = [];
  bool isScanning = false;
  bool isConnected = false;
  String sensorData = '';
  BluetoothDevice? connectedDevice;

  @override
  void initState() {
    super.initState();
    _checkBluetoothState();

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

  Future<void> _checkBluetoothState() async {
    final state = await FlutterBluePlus.adapterState.first;
    if (state != BluetoothAdapterState.on && mounted) {
      _showBluetoothOffDialog();
    }
  }

  void _showBluetoothOffDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bluetooth is Off'),
        content: const Text('Please enable Bluetooth to scan for OpenEarable devices.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Starts scanning and updates the devices list with filtered OpenEarable devices
  Future<void> startScan() async {
    final state = await FlutterBluePlus.adapterState.first;
    if (state != BluetoothAdapterState.on && mounted) {
      _showBluetoothOffDialog();
      return;
    }

    if (isScanning) return;

    setState(() => isScanning = true);
    devices.clear();

    try {
      final scannedDevices = await bluetoothManager.startScan(timeout: const Duration(seconds: 5));
      setState(() => devices = scannedDevices);

    } catch (e) {
      print("Error scanning: $e");
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

  /// Connect to a device and set up sensor data streaming
  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      // Show connecting indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connecting to ${device.platformName}...'),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      final connected = await bluetoothManager.connectToDevice(device);

      if (connected) {
        // --- START STREAMING LOGIC ---
        // NOTE: This part MUST be updated with the simpler startStreaming()
        // method once it is added to BluetoothManager, but for now we use the old logic:
        await bluetoothManager.configureSensors(accel: true, gyro: true);
        await bluetoothManager.setSamplingRate(50);
        await bluetoothManager.subscribeToSensor(
          BluetoothManager.accelerometerCharUuid,
          bluetoothManager.parseAccelerometerData, // Use parser to trigger callbacks
        );
        // --- END STREAMING LOGIC ---

        if (mounted) {
          // Get battery level
          final battery = await bluetoothManager.getBatteryLevel();

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
      print("Connection error: $e");
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
    } catch (e) {
      print("Disconnect error: $e");
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

  Widget _buildDeviceTile(ScanResult result, bool isDarkMode) {
    final deviceName = result.device.platformName.isNotEmpty
        ? result.device.platformName
        : result.device.remoteId.toString();

    final isAlreadyConnected = isConnected &&
        connectedDevice?.remoteId.toString() == result.device.remoteId.toString();

    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subtitleColor = textColor.withOpacity(0.5);

    // Theme-aware colors for the tile
    final tileBackgroundColor = isAlreadyConnected
        ? Colors.green.withOpacity(0.1)
        : isDarkMode
        ? Colors.white.withOpacity(0.05)
        : Colors.black.withOpacity(0.05);

    final tileBorderColor = isAlreadyConnected
        ? Colors.green
        : isDarkMode
        ? Colors.white.withOpacity(0.1)
        : Colors.black.withOpacity(0.1);

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
                ? Colors.green.withOpacity(0.2)
                : Colors.blueAccent.withOpacity(0.1),
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
          deviceName,
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
            await connectToDevice(result.device);
          },
          style: TextButton.styleFrom(
            backgroundColor: Colors.green.withOpacity(0.2),
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
    // NOTE: This assumes ThemeProvider is correctly set up using the Provider package
    final isDarkMode = Provider.of<ThemeProvider>(context).currentBrightness == Brightness.dark;

    // Theme-aware colors
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subtitleColor = textColor.withOpacity(0.5);

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
                    ? Colors.blueAccent.withOpacity(0.8)
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
                    color: Colors.green.withOpacity(0.2),
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
                              connectedDevice!.platformName,
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
                        icon: Icon(Icons.sensors, color: textColor.withOpacity(0.7)),
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
                        color: textColor.withOpacity(0.3),
                        size: 60,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "No OpenEarable devices found",
                        style: TextStyle(color: textColor.withOpacity(0.7)),
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
                              ? Colors.blueAccent.withOpacity(0.5)
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