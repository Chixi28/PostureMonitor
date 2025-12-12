import 'dart:async';
import 'package:flutter/material.dart';
import '../bluetooth/bluetooth_manager.dart';
import 'dart:math';

// Assuming your BluetoothManager and PostureStatus enum are accessible.
// The PostureStatus enum is re-included here for completeness.
enum PostureStatus {
  good,
  warning,
  neutral,
  bad,
}

class PostureMonitorScreen extends StatefulWidget {
  const PostureMonitorScreen({super.key});

  @override
  State<PostureMonitorScreen> createState() => _PostureMonitorScreenState();
}

class _PostureMonitorScreenState extends State<PostureMonitorScreen> {
  final BluetoothManager bluetoothManager = BluetoothManager.instance;

  // Sensor data
  Map<String, double> accelerometerData = {'x': 0.0, 'y': 0.0, 'z': 0.0};

  // Posture analysis
  double _currentPitch = 0.0;    // Head tilt forward/backward (nodding)
  double _currentRoll = 0.0;     // Head tilt side to side
  double _currentYaw = 0.0;      // Head rotation left/right (not used for posture)
  double _currentMagnitude = 0.0; // Overall movement (not used for posture)

  // Posture status
  PostureStatus _postureStatus = PostureStatus.neutral; // Default to neutral/placeholder
  String _postureMessage = "Waiting for data...";
  Color _postureColor = Colors.grey;

  // History for smoothing and movement detection
  List<double> _pitchHistory = [];
  List<double> _rollHistory = [];
  int _maxHistory = 20;

  // Thresholds (adjust these based on testing)
  static const double _goodPitchRange = 15.0;    // ±15 degrees for good posture
  static const double _warningPitchRange = 30.0; // ±30 degrees for warning
  static const double _badPitchThreshold = 40.0; // >40 degrees is bad

  static const double _goodRollRange = 10.0;     // ±10 degrees for good
  static const double _warningRollRange = 20.0;  // ±20 degrees for warning

  // Movement detection
  static const double _movementThreshold = 0.05;
  bool _isMoving = false;
  int _stillTime = 0; // Time in seconds user has been still

  // Calibration
  double _calibratedPitch = 0.0;
  double _calibratedRoll = 0.0;
  bool _isCalibrated = false;

  // Statistics
  int _goodPostureTime = 0;
  int _warningPostureTime = 0;
  int _badPostureTime = 0;
  Timer? _statisticsTimer;
  DateTime? _sessionStartTime;

  // Flag to manage initial navigation pop guard
  bool _initialConnectionCheckPassed = false;


  @override
  void initState() {
    super.initState();

    final isConnected = bluetoothManager.isConnected;

    // Check initial connection state
    if (isConnected) {
      _initialConnectionCheckPassed = true;
      _sessionStartTime = DateTime.now();
      _startStatisticsTimer();
      // Set initial status color/message based on connection (or lack thereof)
      _postureMessage = "Good posture! Keep it up!";
      _postureColor = Colors.green;
      _postureStatus = PostureStatus.good;
    } else {
      // If disconnected on launch, set neutral state
      _postureMessage = "Device disconnected. Please connect the OpenEarable.";
      _postureColor = Colors.blueGrey;
      _postureStatus = PostureStatus.neutral;
    }


    // Set up callbacks
    bluetoothManager.addAccelerometerCallback(_handleAccelerometerData);
    bluetoothManager.addConnectionCallback(_handleConnectionChanged);
  }

  void _handleConnectionChanged(bool connected) {
    if (!mounted) return;

    setState(() {
      if (connected) {
        _initialConnectionCheckPassed = true;
        _sessionStartTime = DateTime.now();
        _startStatisticsTimer();
        // Reset stats on new connection
        _goodPostureTime = 0;
        _warningPostureTime = 0;
        _badPostureTime = 0;
      } else if (_initialConnectionCheckPassed) {
        // Only pop if the device *was* connected and now is *not*.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Device disconnected!'), backgroundColor: Colors.red),
            );
          }
        });
      }

      // Update UI state when disconnected
      if (!connected) {
        _statisticsTimer?.cancel();
        _postureStatus = PostureStatus.neutral;
        _postureColor = Colors.blueGrey;
        _postureMessage = "Device disconnected. Please connect the OpenEarable.";
      }
    });
  }

  void _handleAccelerometerData(Map<String, double> data) {
    if (!mounted || !bluetoothManager.isConnected) return; // Ignore data if not connected

    setState(() {
      accelerometerData = data;

      // Calculate orientation
      _currentPitch = _calculatePitch(data);
      _currentRoll = _calculateRoll(data);
      _currentYaw = _calculateYaw(data);
      _currentMagnitude = _calculateMagnitude(data);

      // Apply calibration
      if (_isCalibrated) {
        _currentPitch -= _calibratedPitch;
        _currentRoll -= _calibratedRoll;
      }

      // Update history
      _updateHistory();

      // Analyze posture
      _analyzePosture();

      // Detect movement
      _detectMovement();
    });
  }

  void _updateHistory() {
    _pitchHistory.add(_currentPitch);
    _rollHistory.add(_currentRoll);

    if (_pitchHistory.length > _maxHistory) {
      _pitchHistory.removeAt(0);
      _rollHistory.removeAt(0);
    }
  }

  void _analyzePosture() {
    if (!bluetoothManager.isConnected) return;

    // Get average over last few readings to smooth out noise
    double avgPitch = _getAverage(_pitchHistory);
    double avgRoll = _getAverage(_rollHistory);

    // Check for bad posture (slouching)
    if (avgPitch.abs() > _badPitchThreshold) {
      // Head tilted too far forward or backward
      _postureStatus = PostureStatus.bad;
      _postureColor = Colors.red;

      if (avgPitch > 0) {
        _postureMessage = "You're slouching forward!\nSit up straight.";
      } else {
        _postureMessage = "Head tilted too far back!";
      }
    }
    // Check for warning posture
    else if (avgPitch.abs() > _warningPitchRange || avgRoll.abs() > _warningRollRange) {
      _postureStatus = PostureStatus.warning;
      _postureColor = Colors.orange;

      if (avgPitch.abs() > _warningPitchRange) {
        _postureMessage = "Slight slouch detected.\nAdjust your posture.";
      } else {
        _postureMessage = "Head tilted to the side.\nCenter your head.";
      }
    }
    // Good posture
    else if (avgPitch.abs() < _goodPitchRange && avgRoll.abs() < _goodRollRange) {
      _postureStatus = PostureStatus.good;
      _postureColor = Colors.green;
      _postureMessage = "Good posture! Keep it up!";
    }
    // Neutral (between good and warning)
    else {
      _postureStatus = PostureStatus.neutral;
      _postureColor = Colors.blue;
      _postureMessage = "Posture is okay.\nCould be improved.";
    }
  }

  void _detectMovement() {
    if (!bluetoothManager.isConnected) return;

    // Calculate movement variance
    if (_pitchHistory.length < 5) return;

    double pitchVariance = _calculateVariance(_pitchHistory);
    double rollVariance = _calculateVariance(_rollHistory);

    bool wasMoving = _isMoving;
    _isMoving = (pitchVariance > _movementThreshold) || (rollVariance > _movementThreshold);

    if (_isMoving) {
      _stillTime = 0;
    } else {
      _stillTime++;
    }

    // Alert if sitting still for too long (e.g., 60 seconds)
    if (!wasMoving && !_isMoving && _stillTime > 60) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('You\'ve been sitting still for 60 seconds. Time to stretch!'),
            backgroundColor: Colors.blue,
          ),
        );
        _stillTime = 0; // Reset timer after alert
      }
    }
  }

  void _calibratePosture() {
    if (!bluetoothManager.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot calibrate: Device is not connected.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _calibratedPitch = _currentPitch;
      _calibratedRoll = _currentRoll;
      _isCalibrated = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Posture calibrated! This position is now set as your good posture.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _startStatisticsTimer() {
    _statisticsTimer?.cancel(); // Cancel any existing timer
    _statisticsTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !bluetoothManager.isConnected) {
        timer.cancel();
        return;
      }

      setState(() {
        switch (_postureStatus) {
          case PostureStatus.good:
            _goodPostureTime++;
            break;
          case PostureStatus.warning:
          case PostureStatus.neutral:
          // Neutral postures are grouped with warning time for stats
            _warningPostureTime++;
            break;
          case PostureStatus.bad:
            _badPostureTime++;
            break;
        }
      });
    });
  }

  String _getSessionDuration() {
    if (_sessionStartTime == null || !bluetoothManager.isConnected) return "0:00";

    final duration = DateTime.now().difference(_sessionStartTime!);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  // --- Utility Calculations ---

  double _getAverage(List<double> list) {
    if (list.isEmpty) return 0.0;
    return list.reduce((a, b) => a + b) / list.length;
  }

  double _calculateVariance(List<double> list) {
    if (list.length < 2) return 0.0;

    double mean = _getAverage(list);
    double variance = 0.0;

    for (var value in list) {
      variance += pow(value - mean, 2);
    }

    return variance / list.length;
  }

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

  // --- Widget Builders ---

  IconData _getPostureIcon() {
    switch (_postureStatus) {
      case PostureStatus.good:
        return Icons.check_circle;
      case PostureStatus.warning:
        return Icons.warning;
      case PostureStatus.neutral:
        return Icons.remove_circle;
      case PostureStatus.bad:
        return Icons.error;
      default:
        return Icons.help;
    }
  }

  Widget _buildDisconnectedView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.signal_cellular_connected_no_internet_0_bar, color: Colors.white24, size: 60),
          const SizedBox(height: 20),
          const Text(
            'No Live Data',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Connect your OpenEarable device to start monitoring posture.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pushNamed(context, '/deviceConnect');
            },
            icon: const Icon(Icons.bluetooth_searching, color: Colors.blueAccent),
            label: const Text('Go to Connect Screen', style: TextStyle(color: Colors.blueAccent)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.blueAccent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionPrompt(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.pushNamed(context, '/deviceConnect');
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        ),
        icon: const Icon(Icons.bluetooth_searching, color: Colors.white),
        label: const Text(
          "CONNECT DEVICE",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildConnectedVisualization(BuildContext context) {
    // Get constraints of the parent widget
    return LayoutBuilder(
      builder: (context, constraints) {
        // Center point for the visualization
        final centerX = constraints.maxWidth / 2;
        final centerY = constraints.maxHeight / 2;

        // Scaling factor: map max angle deviation (e.g., 40 degrees) to a safe area on screen
        final maxRadius = (min(constraints.maxWidth, constraints.maxHeight) / 2) * 0.8;
        const maxAngleToDisplay = 40.0; // Max angle for visual scaling

        // Clamp and scale the pitch and roll values
        final clampedPitch = _currentPitch.clamp(-maxAngleToDisplay, maxAngleToDisplay);
        final clampedRoll = _currentRoll.clamp(-maxAngleToDisplay, maxAngleToDisplay);

        // Calculate display coordinates (Pitch affects Y, Roll affects X)
        final displayX = centerX + (clampedRoll / maxAngleToDisplay) * maxRadius;
        final displayY = centerY + (clampedPitch / maxAngleToDisplay) * maxRadius;

        return Column(
          children: [
            Text(
              'HEAD ORIENTATION',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Background grid/box
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),

                  // Good posture ring (e.g., ±15 degrees)
                  Container(
                    width: (2 * _goodPitchRange / maxAngleToDisplay) * maxRadius,
                    height: (2 * _goodPitchRange / maxAngleToDisplay) * maxRadius,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.green.withOpacity(0.5), width: 1.5),
                      shape: BoxShape.circle,
                    ),
                  ),
                  // Warning posture ring (e.g., ±30 degrees)
                  Container(
                    width: (2 * _warningPitchRange / maxAngleToDisplay) * maxRadius,
                    height: (2 * _warningPitchRange / maxAngleToDisplay) * maxRadius,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.orange.withOpacity(0.5), width: 1.5),
                      shape: BoxShape.circle,
                    ),
                  ),


                  // Center crosshair (Horizontal)
                  Positioned(
                    top: centerY - 1,
                    left: 0,
                    right: 0,
                    child: Container(height: 2, color: Colors.white.withOpacity(0.3)),
                  ),
                  // Center crosshair (Vertical)
                  Positioned(
                    left: centerX - 1,
                    top: 0,
                    bottom: 0,
                    child: Container(width: 2, color: Colors.white.withOpacity(0.3)),
                  ),

                  // Head position indicator
                  Positioned(
                    left: displayX - 20, // Adjust by half the indicator size
                    top: displayY - 20, // Adjust by half the indicator size
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _postureColor.withOpacity(0.5),
                        shape: BoxShape.circle,
                        border: Border.all(color: _postureColor, width: 2),
                      ),
                      child: const Icon(
                        Icons.face,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Orientation readings
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildOrientationReading("PITCH", "${_currentPitch.toStringAsFixed(1)}°", Colors.purpleAccent),
                _buildOrientationReading("ROLL", "${_currentRoll.toStringAsFixed(1)}°", Colors.orangeAccent),
                _buildOrientationReading("MOVEMENT", _isMoving ? "MOVING" : "STILL", Colors.cyanAccent),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildOrientationReading(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: color.withOpacity(0.7),
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'Courier',
          ),
        ),
      ],
    );
  }

  Widget _buildStatistic(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 10,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _statisticsTimer?.cancel();

    bluetoothManager.removeAccelerometerCallback(_handleAccelerometerData);
    bluetoothManager.removeConnectionCallback(_handleConnectionChanged);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = bluetoothManager.isConnected;

    // Calculate posture score (0-100)
    int postureScore = 100;
    if (_postureStatus == PostureStatus.warning) postureScore = 70;
    if (_postureStatus == PostureStatus.neutral) postureScore = 50;
    if (_postureStatus == PostureStatus.bad) postureScore = 30;

    // Calculate percentage of time in each posture state
    int totalTime = _goodPostureTime + _warningPostureTime + _badPostureTime;
    int goodPercentage = totalTime > 0 ? (_goodPostureTime * 100 ~/ totalTime) : 0;
    int warningPercentage = totalTime > 0 ? (_warningPostureTime * 100 ~/ totalTime) : 0;
    int badPercentage = totalTime > 0 ? (_badPostureTime * 100 ~/ totalTime) : 0;

    // Fallback for disconnected state
    if (!isConnected) {
      postureScore = 0;
      _postureColor = Colors.blueGrey;
      _postureMessage = "Device disconnected. Please connect the OpenEarable.";
    }


    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Posture Monitor", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20),
        actions: [
          IconButton(
            icon: Icon(
              _isCalibrated ? Icons.check_circle : Icons.straighten,
              color: isConnected ? Colors.white70 : Colors.grey,
            ),
            onPressed: isConnected ? _calibratePosture : null, // Disable when disconnected
            tooltip: 'Calibrate Current Posture',
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
          // FIX: Use SingleChildScrollView to prevent bottom overflow
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0), // Padding applied here
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Connection status
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
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
                          isConnected
                              ? bluetoothManager.connectedDevice?.platformName ?? 'OpenEarable Device'
                              : 'Disconnected',
                          style: TextStyle(
                            color: isConnected ? Colors.white : Colors.redAccent,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Text(
                        _getSessionDuration(),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Posture Status Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _postureColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _postureColor.withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: _postureColor.withOpacity(0.2),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Posture score
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'POSTURE SCORE',
                            style: TextStyle(
                              color: _postureColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: _postureColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              isConnected ? '$postureScore/100' : 'N/A',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Posture message
                      Text(
                        _postureMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Posture icon
                      Icon(
                        isConnected ? _getPostureIcon() : Icons.bluetooth_disabled,
                        color: _postureColor,
                        size: 60,
                      ),

                      const SizedBox(height: 16),

                      // Posture tips or Connection prompt
                      if (!isConnected)
                        _buildConnectionPrompt(context)
                      else if (_postureStatus == PostureStatus.bad)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.lightbulb_outline, color: Colors.orange, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Tip: Keep your ears aligned with your shoulders',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Posture visualization (Now with a fixed height)
                Container(
                  height: 350, // Fixed height to prevent overflow in SingleChildScrollView
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: isConnected
                      ? _buildConnectedVisualization(context)
                      : _buildDisconnectedView(context),
                ),

                const SizedBox(height: 20),

                // Statistics
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'SESSION STATISTICS',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 12),

                      if (isConnected)
                        Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildStatistic("Good", "$goodPercentage%", Colors.green),
                                _buildStatistic("Warning/Neutral", "$warningPercentage%", Colors.orange),
                                _buildStatistic("Poor", "$badPercentage%", Colors.red),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Progress bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: SizedBox(
                                height: 8,
                                child: totalTime > 0
                                    ? Row(
                                  children: [
                                    Expanded(flex: _goodPostureTime, child: Container(color: Colors.green)),
                                    Expanded(flex: _warningPostureTime, child: Container(color: Colors.orange)),
                                    Expanded(flex: _badPostureTime, child: Container(color: Colors.red)),
                                  ],
                                )
                                    : Container(color: Colors.white.withOpacity(0.1)),
                              ),
                            ),
                          ],
                        )
                      else
                        const Text(
                          "Connect device to track session statistics.",
                          style: TextStyle(color: Colors.white54, fontSize: 14),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}