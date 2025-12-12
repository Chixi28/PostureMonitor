import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../bluetooth/bluetooth_manager.dart'; // Update import
import 'live_data_screen.dart'; // Add this import

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

    // ========== NEW: SET UP CALLBACKS ==========
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
    if (isScanning) return;

    setState(() => isScanning = true);
    devices.clear();

    try {
      final scannedDevices = await bluetoothManager.startScan(timeout: const Duration(seconds: 5));
      setState(() => devices = scannedDevices);

      if (scannedDevices.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No OpenEarable devices found'),
            backgroundColor: Colors.orange,
          ),
        );
      }
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
        // Configure sensors and set sampling rate
        await bluetoothManager.configureSensors(accel: true, gyro: true);
        await bluetoothManager.setSamplingRate(50);

        // Subscribe to accelerometer data
        final subscribed = await bluetoothManager.subscribeToSensor(
          BluetoothManager.accelerometerCharUuid,
              (data) {
            // Data will be parsed and callbacks called automatically in parseAccelerometerData
          },
        );

        if (subscribed && mounted) {
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
    // ========== NEW: REMOVE CALLBACKS ==========
    bluetoothManager.removeConnectionCallback(_handleConnectionChanged);
    bluetoothManager.removeSensorDataCallback(_handleSensorData);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(isConnected ? "Connected" : "Device Scanner"),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
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
                    ? const Color.fromRGBO(0, 122, 255, 0.8)
                    : const Color.fromRGBO(0, 122, 255, 1),
              ),
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A1A2E), Color(0xFF0F0F1A)],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Connection status banner
              if (isConnected && connectedDevice != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: const BoxDecoration(
                    color: Color.fromRGBO(0, 200, 83, 0.2),
                    border: Border(
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
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (sensorData.isNotEmpty)
                              Text(
                                sensorData,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.sensors, color: Colors.white70),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LiveDataScreen(),
                            ),
                          );
                        },
                        tooltip: 'View Sensor Data',
                      ),
                    ],
                  ),
                ),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
                child: Text(
                  "AVAILABLE DEVICES",
                  style: TextStyle(
                    color: Color.fromRGBO(255, 255, 255, 0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),

              Expanded(
                child: devices.isEmpty && !isScanning
                    ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.bluetooth_disabled,
                        color: Color.fromRGBO(255, 255, 255, 0.3),
                        size: 60,
                      ),
                      SizedBox(height: 16),
                      Text(
                        "No OpenEarable devices found",
                        style: TextStyle(color: Colors.white70),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Tap scan to search for devices",
                        style: TextStyle(
                          color: Color.fromRGBO(255, 255, 255, 0.5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: devices.length,
                  itemBuilder: (context, index) => _buildDeviceTile(devices[index]),
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
                                builder: (context) => LiveDataScreen(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
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
                          backgroundColor: isScanning
                              ? const Color.fromRGBO(0, 122, 255, 0.5)
                              : const Color.fromRGBO(0, 122, 255, 1),
                          icon: Icon(isScanning ? Icons.hourglass_top : Icons.bluetooth_searching),
                          label: Text(
                            isScanning ? "SCANNING..." : "SCAN FOR DEVICES",
                            style: const TextStyle(fontWeight: FontWeight.bold),
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

  Widget _buildDeviceTile(ScanResult result) {
    final deviceName = result.device.platformName.isNotEmpty
        ? result.device.platformName
        : result.device.remoteId.toString();

    final isAlreadyConnected = isConnected &&
        connectedDevice?.remoteId.toString() == result.device.remoteId.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isAlreadyConnected
            ? const Color.fromRGBO(0, 200, 83, 0.1)
            : const Color.fromRGBO(255, 255, 255, 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAlreadyConnected
              ? Colors.green
              : const Color.fromRGBO(255, 255, 255, 0.1),
          width: isAlreadyConnected ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isAlreadyConnected
                ? const Color.fromRGBO(0, 200, 83, 0.2)
                : const Color.fromRGBO(0, 122, 255, 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isAlreadyConnected ? Icons.bluetooth_connected : Icons.bluetooth,
            color: isAlreadyConnected
                ? Colors.green
                : const Color.fromRGBO(0, 122, 255, 1),
          ),
        ),
        title: Text(
          deviceName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "RSSI: ${result.rssi}",
              style: const TextStyle(
                color: Color.fromRGBO(255, 255, 255, 0.5),
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
            backgroundColor: const Color.fromRGBO(0, 200, 83, 0.2),
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
}