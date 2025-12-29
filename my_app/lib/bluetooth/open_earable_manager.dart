import 'dart:async';
import 'package:open_earable_flutter/open_earable_flutter.dart';

typedef ConnectionCallback = void Function(bool connected);
typedef AccelerometerCallback = void Function(Map<String, double> accel);
typedef SensorDataCallback = void Function(String data);

/// Bluetooth Manager (OpenEarable)
///
/// This file implements a singleton BluetoothManager class that wraps the open_earable_flutter package.
/// It provides a simplified API for scanning, connecting, and streaming sensor data from OpenEarable devices.
///
/// Features:
/// - Scans for nearby OpenEarable Bluetooth devices.
/// - Connects to and disconnects from devices.
/// - Streams accelerometer and sensor data to registered callbacks.
/// - Handles connection state and device information.
/// - Exposes a stream for IMU data and manages callback registration.

/// BluetoothManager: a thin wrapper around `open_earable_flutter` that
/// exposes the simplified API the app expects (singleton, callbacks,
/// scan/connect/disconnect, and accelerometer/sensor callbacks).
///
/// Handles device discovery, connection, sensor configuration, and data streaming.
class BluetoothManager {
  BluetoothManager._internal() {
    _wearableManager = WearableManager();
    _setupListeners();
  }

  // ---------- Debug helpers ----------
  void _log(String s) {
    // Keep logs concise and centralized
    try {
    } catch (_) {}
  }

  static final BluetoothManager instance = BluetoothManager._internal();

  late final WearableManager _wearableManager;
  Wearable? _connectedWearable;
  DiscoveredDevice? _connectedDevice;

  // Callback registries
  final List<ConnectionCallback> _connectionCallbacks = [];
  final List<AccelerometerCallback> _accelerometerCallbacks = [];
  final List<SensorDataCallback> _sensorDataCallbacks = [];

  // Internal IMU stream controller
  final StreamController<Map<String, double>> _imuController = StreamController.broadcast();
  bool _imuSubscribed = false;

  bool get isConnected => _connectedWearable != null;

  /// A lightweight device representation used by the UI
  DiscoveredDevice? get connectedDevice => _connectedDevice;

  // ---------------- Helper Methods ----------------
  
  /// Extract accelerometer data from SensorDoubleValue
  /// SensorDoubleValue has a 'values' property which is a List'<'double'>'
  /// The values are in order: [X, Y, Z] based on axisNames
  Map<String, double>? _extractAccelerometerData(dynamic dataObj) {
    try {
      List<double>? values;
      
      // SensorDoubleValue has a 'values' property that is List<double>
      try {
        values = (dataObj as dynamic).values as List<double>?;
        if (values != null && values.length >= 3) {
          return {
            'x': values[0],
            'y': values[1],
            'z': values[2],
          };
        }
      } catch (e) {
        _log('Failed to access .values property: $e');
      }
      
      // Fallback: Try if it's already a List
      if (values == null && dataObj is List && dataObj.length >= 3) {
        values = dataObj.map((e) => (e as num).toDouble()).toList();
        return {
          'x': values[0],
          'y': values[1],
          'z': values[2],
        };
      }
      
      return null;
    } catch (e) {
      _log('_extractAccelerometerData error: $e');
      return null;
    }
  }

  // ---------------- Setup ----------------
  void _setupListeners() {
    // Listen for connection events from the native manager
    _wearableManager.connectStream.listen((wearable) {
      _connectedWearable = wearable;

      // If the wearable was created from a DiscoveredDevice, try to capture a reference
      try {
        _connectedDevice = (wearable as dynamic).discoveredDevice as DiscoveredDevice?;
      } catch (_) {
        _connectedDevice = null;
      }

      // Notify connection callbacks
      final connected = _connectedWearable != null;
      _log('connectStream event: connected=$connected, wearable=${(wearable as dynamic).toString()}');
      for (final cb in List<ConnectionCallback>.from(_connectionCallbacks)) {
        try {
          cb(connected);
        } catch (e) {
          // ignore callback errors
        }
      }

      // Register disconnect listener
      try {
        wearable.addDisconnectListener(() {
          _connectedWearable = null;
          _connectedDevice = null;
          _log('Device disconnected');
          for (final cb in List<ConnectionCallback>.from(_connectionCallbacks)) {
            try {
              cb(false);
            // ignore: empty_catches
            } catch (e) {}
          }
        });
      } catch (e) {
        _log('addDisconnectListener not supported: $e');
      }

      // If the wearable exposes sensors, try to configure and listen safely using dynamic calls
      try {
        final dynamic sensorManager = wearable as dynamic;
        final dynamic sensors = sensorManager.sensors;
        if (sensors != null) {
          // Attempt to write a default config when available (best-effort)
          try {
            if ((sensorManager as dynamic).writeSensorConfig != null) {
              try {
                // Some implementations may accept a map-like config. We'll attempt a dynamic call.
                (sensorManager as dynamic).writeSensorConfig({'sensorId': 0, 'samplingRate': 50.0, 'latency': 0});
              } catch (_) {}
            }
          } catch (_) {}

          // Find an IMU-like sensor (best effort)
          dynamic imuSensor;
          try {
            final sensorsList = sensors as List;
            imuSensor = sensorsList.isNotEmpty
                ? sensorsList.firstWhere((s) {
                    try {
                      return (s as dynamic).sensorId == 0;
                    } catch (_) {
                      return false;
                    }
                  }, orElse: () => sensorsList[0])
                : null;
          } catch (_) {
            imuSensor = null;
          }

          if (imuSensor != null) {
            try {
              _log('Setting up sensorStream listener in _setupListeners');
              (imuSensor as dynamic).sensorStream.listen((data) {
                try {
                  // SensorDoubleValue has a 'values' property (List<double>)
                  final map = _extractAccelerometerData(data);
                  if (map != null) {
                    // minimal log to help debugging without spamming
                    _log('IMU sample x=${map['x']?.toStringAsFixed(2)} y=${map['y']?.toStringAsFixed(2)} z=${map['z']?.toStringAsFixed(2)}');

                    // broadcast to registered accel callbacks
                    final callbacks = List<AccelerometerCallback>.from(_accelerometerCallbacks);
                    if (callbacks.isEmpty) {
                      _log('⚠️ WARNING: No accelerometer callbacks registered!');
                    }
                    for (final cb in callbacks) {
                      try {
                        cb(map);
                      } catch (e) { 
                        _log('accelerometer callback error: $e');
                      }
                    }

                    // Also broadcast a small string so the UI can display a human readable message
                    final s = 'ACCEL: x=${map['x']?.toStringAsFixed(2)}, y=${map['y']?.toStringAsFixed(2)}, z=${map['z']?.toStringAsFixed(2)}';

                    for (final cb in List<SensorDataCallback>.from(_sensorDataCallbacks)) {
                      try {
                        cb(s);
                      } catch (e) { _log('sensor data callback error: $e'); }
                    }

                    // Internal stream for other consumers
                    _imuController.add(map);
                  }
                } catch (e) {
                  _log('IMU sample handler error: $e');
                }
              }, onError: (e) {
                _log('imu sensorStream error: $e');
              });

              _imuSubscribed = true;
              _log('✅ IMU configured and streaming');
            } catch (e) { 
              _log('Failed to listen to imuSensor.sensorStream: $e');
            }
          }
        }
      } catch (_) {}
    });
  }

  // ---------------- Public API ----------------

  /// Start scanning and collect discovered devices for [timeout].
  /// Returns a deduplicated list of [DiscoveredDevice].
  Future<List<DiscoveredDevice>> startScan({Duration timeout = const Duration(seconds: 5)}) async {
    _log('Starting scan for ${timeout.inSeconds}s');
    final results = <String, DiscoveredDevice>{};

    final sub = (_wearableManager as dynamic).scanStream.listen((device) {
      try {
        final dyn = device as dynamic;
        final key = dyn.id ?? dyn.name ?? device.toString();
        results[key] = device as DiscoveredDevice;
        _log('Found device: id=${dyn.id} name=${dyn.name} rssi=${dyn.rssi ?? 'N/A'}');
      } catch (e) {
        _log('scan listener error: $e');
      }
    }, onError: (e) {
      _log('scan stream error: $e');
    });

    try {
      await (_wearableManager as dynamic).startScan();
    } catch (e) {
      _log('startScan error: $e');
    }

    await Future.delayed(timeout);

    try {
      await (_wearableManager as dynamic).stopScan();
    } catch (e) {
      _log('stopScan error: $e');
    }

    await sub.cancel();

    _log('Scan complete: ${results.length} device(s)');
    return results.values.toList();
  }

  Future<bool> connectToDevice(DiscoveredDevice device) async {
    _log('Connecting to device id=${device.id} name=${device.name}');
    try {
      try { await (_wearableManager as dynamic).stopScan(); } catch (_) {}
      try { await (_wearableManager as dynamic).connectToDevice(device); } catch (e) { _log('connectToDevice error: $e'); }

      // Wait a short while for connectStream to produce the wearable
      await Future.delayed(const Duration(milliseconds: 500));

      _log('connectToDevice returned; isConnected=$isConnected');
      return isConnected;
    } catch (e) {
      _log('Connect error: $e');
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      await _connectedWearable?.disconnect();
      _connectedWearable = null;
      _connectedDevice = null;
      for (final cb in List<ConnectionCallback>.from(_connectionCallbacks)) {
        try {
          cb(false);
        // ignore: empty_catches
        } catch (e) {}
      }
    // ignore: empty_catches
    } catch (e) {
    }
  }

  Future<int?> getBatteryLevel() async {
    // open_earable_flutter may expose a battery API; returning null when unknown.
    return null;
  }

  // Sensor configuration helpers used by the UI
  Future<void> configureSensors({bool accel = true, bool gyro = false, bool mag = false}) async {
    // Configuration is applied when a wearable connects in _setupListeners above.
    // Nothing to do here for now; kept for API compatibility.
    return;
  }

  Future<void> setSamplingRate(int hz) async {
    // Not implemented: delegate to SensorManager.writeSensorConfig on connect instead.
    return;
  }

  /// Ensure sensors are subscribed for the currently-connected wearable.
  /// Public helper to allow UI to request streaming if automatic setup didn't occur.
  Future<void> ensureSensorSubscriptions() async {
    if (!isConnected) {
      _log('ensureSensorSubscriptions called but not connected');
      return;
    }
    if (_imuSubscribed) {
      _log('ensureSensorSubscriptions: already subscribed');
      return;
    }

    try {
      final dynamic wearable = _connectedWearable as dynamic;
      final sensors = wearable?.sensors;
      if (sensors is List && sensors.isNotEmpty) {
        // Find an IMU-like sensor safely without using firstWhere/orElse (avoids runtime type mismatch)
        dynamic imuSensor;
        try {
          final sensorsList = sensors;
          for (var s in sensorsList) {
            try {
              if ((s as dynamic).sensorId == 0) {
                imuSensor = s;
                break;
              }
            } catch (_) {}
          }
          if (imuSensor == null && sensorsList.isNotEmpty) imuSensor = sensorsList[0];
        } catch (_) {
          imuSensor = null;
        }

        if (imuSensor != null) {
          try {
            _log('Setting up sensorStream listener in ensureSensorSubscriptions');
            (imuSensor as dynamic).sensorStream.listen((data) {
              try {
                // SensorDoubleValue has a 'values' property (List<double>)
                final map = _extractAccelerometerData(data);
                if (map != null) {
                  _log('Calling ${_accelerometerCallbacks.length} accelerometer callback(s)');
                  for (final cb in List<AccelerometerCallback>.from(_accelerometerCallbacks)) {
                    try {
                      cb(map);
                    } catch (e) { _log('accelerometer callback error: $e'); }
                  }
                  _imuController.add(map);
                } else {
                  _log('⚠️ _extractAccelerometerData returned null');
                }
              } catch (e) {
                _log('ensureSensorSubscriptions: sample handler error: $e');
              }
            }, onError: (e) { _log('ensureSensorSubscriptions: sensorStream error: $e'); });

            _imuSubscribed = true;
            _log('ensureSensorSubscriptions: subscribed to IMU');
          } catch (e) {
            _log('ensureSensorSubscriptions: failed to subscribe $e');
          }
        } else {
          _log('ensureSensorSubscriptions: no IMU-like sensor found');
        }
      } else {
        _log('ensureSensorSubscriptions: no sensors available on wearable');
      }
    } catch (e) {
      _log('ensureSensorSubscriptions error: $e');
    }
  }

  // ---------------- Callback registration ----------------
  void addConnectionCallback(ConnectionCallback cb) => _connectionCallbacks.add(cb);
  void removeConnectionCallback(ConnectionCallback cb) => _connectionCallbacks.remove(cb);

  void addAccelerometerCallback(AccelerometerCallback cb) => _accelerometerCallbacks.add(cb);
  void removeAccelerometerCallback(AccelerometerCallback cb) => _accelerometerCallbacks.remove(cb);

  void addSensorDataCallback(SensorDataCallback cb) => _sensorDataCallbacks.add(cb);
  void removeSensorDataCallback(SensorDataCallback cb) => _sensorDataCallbacks.remove(cb);

  // Expose IMU as a stream for advanced usage
  Stream<Map<String, double>> get imuStream => _imuController.stream;

  void dispose() {
    _connectedWearable?.disconnect();
    _imuController.close();
  }
}
