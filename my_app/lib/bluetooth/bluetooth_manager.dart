import 'dart:async';
import 'dart:io';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class BluetoothManager {
  // Singleton instance
  static final BluetoothManager instance = BluetoothManager._internal();
  factory BluetoothManager() => instance;
  BluetoothManager._internal() {
    print("✅ BluetoothManager singleton created");
  }

  // State
  List<BluetoothService> _services = [];
  BluetoothDevice? _connectedDevice;
  Map<Guid, StreamSubscription<List<int>>?> _subscriptions = {};
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;

  // OpenEarable UUIDs (update these with your actual UUIDs)
  static const String sensorServiceUuid = "0000ffe0-0000-1000-8000-00805f9b34fb";
  static const String accelerometerCharUuid = "0000ffe1-0000-1000-8000-00805f9b34fb";
  static const String gyroscopeCharUuid = "0000ffe2-0000-1000-8000-00805f9b34fb";
  static const String magnetometerCharUuid = "0000ffe3-0000-1000-8000-00805f9b34fb";
  static const String buttonCharUuid = "0000ffe4-0000-1000-8000-00805f9b34fb";
  static const String batteryCharUuid = "0000180f-0000-1000-8000-00805f9b34fb";
  static const String configCharUuid = "0000ffe5-0000-1000-8000-00805f9b34fb";
  static const String samplingRateCharUuid = "0000ffe6-0000-1000-8000-00805f9b34fb";

  // ========== NEW: CALLBACK SYSTEM ==========
  final List<Function(bool)> _connectionCallbacks = [];
  final List<Function(Map<String, double>)> _accelerometerCallbacks = [];
  final List<Function(String)> _sensorDataCallbacks = [];

  // Public getters
  bool get isConnected => _connectedDevice?.isConnected ?? false;
  BluetoothDevice? get connectedDevice => _connectedDevice;
  List<BluetoothService> get services => _services;

  // ========== NEW: CALLBACK MANAGEMENT METHODS ==========
  void addConnectionCallback(Function(bool) callback) {
    _connectionCallbacks.add(callback);
    // Immediately notify with current state
    callback(isConnected);
  }

  void removeConnectionCallback(Function(bool) callback) {
    _connectionCallbacks.remove(callback);
  }

  void addAccelerometerCallback(Function(Map<String, double>) callback) {
    _accelerometerCallbacks.add(callback);
  }

  void removeAccelerometerCallback(Function(Map<String, double>) callback) {
    _accelerometerCallbacks.remove(callback);
  }

  void addSensorDataCallback(Function(String) callback) {
    _sensorDataCallbacks.add(callback);
  }

  void removeSensorDataCallback(Function(String) callback) {
    _sensorDataCallbacks.remove(callback);
  }

  void _notifyConnectionChange(bool connected) {
    for (var callback in _connectionCallbacks) {
      callback(connected);
    }
  }

  void _notifyAccelerometerData(Map<String, double> data) {
    for (var callback in _accelerometerCallbacks) {
      callback(data);
    }
  }

  void _notifySensorData(String data) {
    for (var callback in _sensorDataCallbacks) {
      callback(data);
    }
  }

  void clearAllCallbacks() {
    _connectionCallbacks.clear();
    _accelerometerCallbacks.clear();
    _sensorDataCallbacks.clear();
  }
  // ========== END OF NEW CALLBACK SYSTEM ==========

  // Request permissions
  Future<bool> _requestPermissions() async {
    if (Platform.isAndroid) {
      final androidStatus = await Permission.bluetoothScan.request();
      final androidConnectStatus = await Permission.bluetoothConnect.request();

      if (androidStatus.isGranted && androidConnectStatus.isGranted) {
        return true;
      }

      final locationStatus = await Permission.location.request();
      return locationStatus.isGranted;
    }
    return true;
  }

  // Start scan with filtering for OpenEarable devices
  Future<List<ScanResult>> startScan({Duration timeout = const Duration(seconds: 4)}) async {
    final granted = await _requestPermissions();
    if (!granted) {
      print("❌ Required permissions not granted");
      return [];
    }

    var state = await FlutterBluePlus.adapterState.first;
    if (state != BluetoothAdapterState.on) {
      print("❌ Bluetooth is OFF. Cannot scan.");
      return [];
    }

    print("🔵 Starting scan...");

    // Stop any ongoing scan first
    await FlutterBluePlus.stopScan();

    // Start new scan
    await FlutterBluePlus.startScan(
      timeout: timeout,
      oneByOne: false,
    );

    // Listen to scan results
    List<ScanResult> allResults = [];
    final subscription = FlutterBluePlus.scanResults.listen((results) {
      allResults = results;
    });

    // Wait for the scan timeout
    await Future.delayed(timeout);
    subscription.cancel();
    await FlutterBluePlus.stopScan();

    // Filter for OpenEarable devices
    final openEarables = allResults.where((r) {
      final name = r.device.platformName.toLowerCase();
      final hasService = r.advertisementData.serviceUuids
          .any((uuid) => uuid.toString().contains(sensorServiceUuid));

      return name.contains("openearable") || hasService || name.contains("earable");
    }).toList();

    print("🔹 Found ${openEarables.length} OpenEarable devices");
    for (var r in openEarables) {
      print("   - ${r.device.platformName} (${r.device.remoteId}) | RSSI: ${r.rssi}");
    }

    return openEarables;
  }

  // Connect to device and discover services
  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      print("🔗 Connecting to ${device.platformName}...");

      // Disconnect from previous device if connected
      if (_connectedDevice != null && _connectedDevice!.isConnected) {
        await disconnect();
      }

      // Connect with timeout
      await device.connect(timeout: Duration(seconds: 10));

      // Wait for connection to stabilize
      await Future.delayed(Duration(milliseconds: 500));

      if (device.isConnected) {
        _connectedDevice = device;
        print("✅ Connected to ${device.platformName}");

        // ========== NEW: NOTIFY CONNECTION CHANGE ==========
        _notifyConnectionChange(true);

        // Set up connection state listener
        _connectionStateSubscription = device.connectionState.listen((state) {
          if (state == BluetoothConnectionState.disconnected) {
            print("⚠️ Device disconnected");
            _notifyConnectionChange(false); // NEW: Notify disconnection
            _cleanup();
          }
        });

        // Discover services
        await discoverServices();

        return true;
      } else {
        print("❌ Connection failed");
        return false;
      }
    } catch (e) {
      print("❌ Connection error: $e");
      return false;
    }
  }

  // Discover all services and characteristics
  Future<void> discoverServices() async {
    if (_connectedDevice == null || !_connectedDevice!.isConnected) {
      print("❌ No device connected");
      return;
    }

    try {
      print("🔍 Discovering services...");
      _services = await _connectedDevice!.discoverServices();

      print("✅ Found ${_services.length} services:");
      for (var service in _services) {
        print("   Service: ${service.uuid}");
        for (var char in service.characteristics) {
          final props = char.properties;
          final propStr = '${props.read ? 'R' : ''}${props.write ? 'W' : ''}${props.notify ? 'N' : ''}${props.writeWithoutResponse ? 'WWR' : ''}';
          print("     - Characteristic: ${char.uuid} ($propStr)");
        }
      }
    } catch (e) {
      print("❌ Service discovery failed: $e");
    }
  }

  // Get characteristic by UUID
  BluetoothCharacteristic? getCharacteristic(String characteristicUuid) {
    for (var service in _services) {
      for (var char in service.characteristics) {
        if (char.uuid.toString().toLowerCase() == characteristicUuid.toLowerCase()) {
          return char;
        }
      }
    }
    return null;
  }

  // Subscribe to sensor data (notifications)
  Future<bool> subscribeToSensor(String characteristicUuid,
      Function(List<int>) onDataReceived) async {
    final char = getCharacteristic(characteristicUuid);
    if (char == null) {
      print("❌ Characteristic $characteristicUuid not found");
      return false;
    }

    if (!char.properties.notify) {
      print("❌ Characteristic doesn't support notifications");
      return false;
    }

    try {
      // Set up notification
      await char.setNotifyValue(true);

      // Subscribe to value updates
      final subscription = char.onValueReceived.listen(onDataReceived);
      _subscriptions[char.uuid] = subscription;

      print("✅ Subscribed to ${char.uuid}");
      return true;
    } catch (e) {
      print("❌ Failed to subscribe: $e");
      return false;
    }
  }

  // Read sensor data once
  Future<List<int>?> readSensorData(String characteristicUuid) async {
    final char = getCharacteristic(characteristicUuid);
    if (char == null || !char.properties.read) {
      print("❌ Cannot read from characteristic $characteristicUuid");
      return null;
    }

    try {
      final data = await char.read();
      print("📖 Read ${data.length} bytes from ${char.uuid}");
      return data;
    } catch (e) {
      print("❌ Read failed: $e");
      return null;
    }
  }

  // Write configuration data
  Future<bool> writeConfiguration(String characteristicUuid, List<int> data) async {
    final char = getCharacteristic(characteristicUuid);
    if (char == null) {
      print("❌ Characteristic $characteristicUuid not found");
      return false;
    }

    try {
      if (char.properties.writeWithoutResponse) {
        await char.write(data, withoutResponse: true);
      } else if (char.properties.write) {
        await char.write(data, withoutResponse: false);
      } else {
        print("❌ Cannot write to characteristic $characteristicUuid");
        return false;
      }

      print("📝 Wrote ${data.length} bytes to ${char.uuid}");
      return true;
    } catch (e) {
      print("❌ Write failed: $e");
      return false;
    }
  }

  // Set sensor sampling rate
  Future<bool> setSamplingRate(int rateHz) async {
    // Convert rate to bytes (depends on OpenEarable protocol)
    final data = [rateHz & 0xFF, (rateHz >> 8) & 0xFF];
    return await writeConfiguration(samplingRateCharUuid, data);
  }

  // Enable/disable specific sensors
  Future<bool> configureSensors({bool accel = true, bool gyro = true, bool mag = true}) async {
    // Example configuration byte:
    // bit 0: accelerometer, bit 1: gyroscope, bit 2: magnetometer
    int config = 0;
    if (accel) config |= 1 << 0;
    if (gyro) config |= 1 << 1;
    if (mag) config |= 1 << 2;

    return await writeConfiguration(configCharUuid, [config]);
  }

  // Parse sensor data (example for accelerometer)
  Map<String, double> parseAccelerometerData(List<int> data) {
    // Adjust this based on your OpenEarable's actual data format
    if (data.length < 6) return {'x': 0.0, 'y': 0.0, 'z': 0.0};

    // Convert two bytes to 16-bit signed integer
    int toInt16(int low, int high) {
      int value = (high << 8) | low;
      // Convert to signed if needed
      if (value > 32767) {
        value = value - 65536;
      }
      return value;
    }

    double x = toInt16(data[0], data[1]).toDouble() / 16384.0; // ±2g range
    double y = toInt16(data[2], data[3]).toDouble() / 16384.0;
    double z = toInt16(data[4], data[5]).toDouble() / 16384.0;

    // ========== NEW: NOTIFY ACCELEROMETER DATA ==========
    final parsedData = {'x': x, 'y': y, 'z': z};
    _notifyAccelerometerData(parsedData);
    _notifySensorData('Accel: X=${x.toStringAsFixed(3)}, Y=${y.toStringAsFixed(3)}, Z=${z.toStringAsFixed(3)}');

    return parsedData;
  }

  // Parse gyroscope data
  Map<String, double> parseGyroscopeData(List<int> data) {
    if (data.length < 6) return {'x': 0.0, 'y': 0.0, 'z': 0.0};

    // Convert two bytes to 16-bit signed integer
    int toInt16(int low, int high) {
      int value = (high << 8) | low;
      if (value > 32767) {
        value = value - 65536;
      }
      return value;
    }

    double x = toInt16(data[0], data[1]).toDouble() / 131.0; // ±250 dps range
    double y = toInt16(data[2], data[3]).toDouble() / 131.0;
    double z = toInt16(data[4], data[5]).toDouble() / 131.0;

    return {'x': x, 'y': y, 'z': z};
  }

  // Get battery level
  Future<int?> getBatteryLevel() async {
    final data = await readSensorData(batteryCharUuid);
    if (data != null && data.isNotEmpty) {
      return data[0];
    }
    return null;
  }

  // Unsubscribe from all notifications
  void unsubscribeAll() {
    _subscriptions.forEach((uuid, subscription) {
      subscription?.cancel();
    });
    _subscriptions.clear();

    // Turn off notifications on device
    for (var service in _services) {
      for (var char in service.characteristics) {
        if (char.isNotifying) {
          try {
            char.setNotifyValue(false);
          } catch (e) {
            print("⚠️ Error turning off notifications: $e");
          }
        }
      }
    }
  }

  // Disconnect from device
  Future<void> disconnect() async {
    // Cancel connection state subscription
    _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;

    unsubscribeAll();

    if (_connectedDevice != null && _connectedDevice!.isConnected) {
      print("🔌 Disconnecting from ${_connectedDevice!.platformName}...");
      try {
        await _connectedDevice!.disconnect();
        print("✅ Disconnected");
        // ========== NEW: NOTIFY DISCONNECTION ==========
        _notifyConnectionChange(false);
      } catch (e) {
        print("⚠️ Disconnect error: $e");
      }
    }

    _cleanup();
  }

  // Cleanup resources
  void _cleanup() {
    _connectedDevice = null;
    _services = [];
    _subscriptions.clear();
  }

  // Stop scanning
  Future<void> stopScan() async {
    print("⛔ Stopping scan...");
    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      print("⚠️ Stop scan error: $e");
    }
  }
}