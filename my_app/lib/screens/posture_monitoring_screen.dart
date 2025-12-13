import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // ADDED
import '../provider/theme_provider.dart'; // ADDED
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

  // ... (All existing state variables and methods like _calculatePitch, _analyzePosture, etc., remain the same)
  // ... (Due to space, I'm omitting the unchanged methods like initState, _handleConnectionChanged, _analyzePosture, _calibratePosture, etc.)

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
    // ... (rest of initState remains unchanged)
    final isConnected = bluetoothManager.isConnected;
    if (isConnected) {
      _initialConnectionCheckPassed = true;
      _sessionStartTime = DateTime.now();
      _startStatisticsTimer();
      _postureMessage = "Good posture! Keep it up!";
      _postureColor = Colors.green;
      _postureStatus = PostureStatus.good;
    } else {
      _postureMessage = "Device disconnected. Please connect the OpenEarable.";
      _postureColor = Colors.blueGrey;
      _postureStatus = PostureStatus.neutral;
    }
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
        _goodPostureTime = 0;
        _warningPostureTime = 0;
        _badPostureTime = 0;
      } else if (_initialConnectionCheckPassed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Device disconnected!'), backgroundColor: Colors.red),
            );
          }
        });
      }
      if (!connected) {
        _statisticsTimer?.cancel();
        _postureStatus = PostureStatus.neutral;
        _postureColor = Colors.blueGrey;
        _postureMessage = "Device disconnected. Please connect the OpenEarable.";
      }
    });
  }

  void _handleAccelerometerData(Map<String, double> data) {
    if (!mounted || !bluetoothManager.isConnected) return;
    // ... (rest of _handleAccelerometerData logic)
    setState(() {
      accelerometerData = data;
      _currentPitch = _calculatePitch(data);
      _currentRoll = _calculateRoll(data);
      _currentYaw = _calculateYaw(data);
      _currentMagnitude = _calculateMagnitude(data);
      if (_isCalibrated) {
        _currentPitch -= _calibratedPitch;
        _currentRoll -= _calibratedRoll;
      }
      _updateHistory();
      _analyzePosture();
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
    double avgPitch = _getAverage(_pitchHistory);
    double avgRoll = _getAverage(_rollHistory);
    if (avgPitch.abs() > _badPitchThreshold) {
      _postureStatus = PostureStatus.bad;
      _postureColor = Colors.red;
      _postureMessage = avgPitch > 0
          ? "You're slouching forward!\nSit up straight."
          : "Head tilted too far back!";
    } else if (avgPitch.abs() > _warningPitchRange || avgRoll.abs() > _warningRollRange) {
      _postureStatus = PostureStatus.warning;
      _postureColor = Colors.orange;
      _postureMessage = avgPitch.abs() > _warningPitchRange
          ? "Slight slouch detected.\nAdjust your posture."
          : "Head tilted to the side.\nCenter your head.";
    } else if (avgPitch.abs() < _goodPitchRange && avgRoll.abs() < _goodRollRange) {
      _postureStatus = PostureStatus.good;
      _postureColor = Colors.green;
      _postureMessage = "Good posture! Keep it up!";
    } else {
      _postureStatus = PostureStatus.neutral;
      _postureColor = Colors.blue;
      _postureMessage = "Posture is okay.\nCould be improved.";
    }
  }

  void _detectMovement() {
    if (!bluetoothManager.isConnected) return;
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
    if (!wasMoving && !_isMoving && _stillTime > 60) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You\'ve been sitting still for 60 seconds. Time to stretch!'),
            backgroundColor: Colors.blue,
          ),
        );
        _stillTime = 0;
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
    _statisticsTimer?.cancel();
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

  // --- Utility Calculations (unchanged) ---
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
  // --- End Utility Calculations ---

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

  Widget _buildDisconnectedView(BuildContext context, Color textColor, Color containerColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.signal_cellular_connected_no_internet_0_bar, color: textColor.withOpacity(0.25), size: 60),
          const SizedBox(height: 20),
          Text(
            'No Live Data',
            style: TextStyle(
              color: textColor.withOpacity(0.54),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Connect your OpenEarable device to start monitoring posture.',
            textAlign: TextAlign.center,
            style: TextStyle(color: textColor.withOpacity(0.38)),
          ),
          const SizedBox(height: 20),
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

  Widget _buildConnectedVisualization(BuildContext context, Color textColor, Color containerColor) {
    // Get constraints of the parent widget
    return LayoutBuilder(
      builder: (context, constraints) {
        // Center point for the visualization
        final centerX = constraints.maxWidth / 2;
        final centerY = constraints.maxHeight / 2;

        final maxRadius = (min(constraints.maxWidth, constraints.maxHeight) / 2) * 0.8;
        const maxAngleToDisplay = 40.0;

        final clampedPitch = _currentPitch.clamp(-maxAngleToDisplay, maxAngleToDisplay);
        final clampedRoll = _currentRoll.clamp(-maxAngleToDisplay, maxAngleToDisplay);

        final displayX = centerX + (clampedRoll / maxAngleToDisplay) * maxRadius;
        final displayY = centerY + (clampedPitch / maxAngleToDisplay) * maxRadius;

        return Column(
          children: [
            Text(
              'HEAD ORIENTATION',
              style: TextStyle(
                color: textColor.withOpacity(0.7),
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
                      border: Border.all(color: textColor.withOpacity(0.1)),
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
                    child: Container(height: 2, color: textColor.withOpacity(0.3)),
                  ),
                  // Center crosshair (Vertical)
                  Positioned(
                    left: centerX - 1,
                    top: 0,
                    bottom: 0,
                    child: Container(width: 2, color: textColor.withOpacity(0.3)),
                  ),

                  // Head position indicator
                  Positioned(
                    left: displayX - 20,
                    top: displayY - 20,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _postureColor.withOpacity(0.5),
                        shape: BoxShape.circle,
                        border: Border.all(color: _postureColor, width: 2),
                      ),
                      child: Icon(
                        Icons.face,
                        color: textColor,
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

  Widget _buildStatistic(String label, String value, Color color, Color textColor) {
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
            color: textColor.withOpacity(0.7),
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
    // Access ThemeProvider state
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.currentBrightness == Brightness.dark;

    // Theme-aware colors
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final containerColor = isDarkMode ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05);

    final isConnected = bluetoothManager.isConnected;

    // ... (rest of score/percentage calculations remain the same)
    int postureScore = 100;
    if (_postureStatus == PostureStatus.warning) postureScore = 70;
    if (_postureStatus == PostureStatus.neutral) postureScore = 50;
    if (_postureStatus == PostureStatus.bad) postureScore = 30;
    int totalTime = _goodPostureTime + _warningPostureTime + _badPostureTime;
    int goodPercentage = totalTime > 0 ? (_goodPostureTime * 100 ~/ totalTime) : 0;
    int warningPercentage = totalTime > 0 ? (_warningPostureTime * 100 ~/ totalTime) : 0;
    int badPercentage = totalTime > 0 ? (_badPostureTime * 100 ~/ totalTime) : 0;
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
        // AppBar colors are now managed by the main MaterialApp theme
        actions: [
          IconButton(
            icon: Icon(
              _isCalibrated ? Icons.check_circle : Icons.straighten,
              color: isConnected ? Theme.of(context).iconTheme.color?.withOpacity(0.7) : Colors.grey,
            ),
            onPressed: isConnected ? _calibratePosture : null,
            tooltip: 'Calibrate Current Posture',
          ),
        ],
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                          isConnected
                              ? bluetoothManager.connectedDevice?.platformName ?? 'OpenEarable Device'
                              : 'Disconnected',
                          style: TextStyle(
                            color: isConnected ? textColor : Colors.redAccent,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Text(
                        _getSessionDuration(),
                        style: TextStyle(
                          color: textColor.withOpacity(0.7),
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
                                color: Colors.white, // Score text is always white on the colored chip
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
                        style: TextStyle(
                          color: textColor, // THEME CHANGE: Text color
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
                                    color: textColor.withOpacity(0.9), // THEME CHANGE: Text color
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

                // Posture visualization
                Container(
                  height: 350,
                  padding: const EdgeInsets.all(20),
                  // THEME CHANGE: Container color and border
                  decoration: BoxDecoration(
                    color: containerColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: textColor.withOpacity(0.1)),
                  ),
                  child: isConnected
                      ? _buildConnectedVisualization(context, textColor, containerColor)
                  // Pass theme colors to disconnected view
                      : _buildDisconnectedView(context, textColor, containerColor),
                ),

                const SizedBox(height: 20),

                // Statistics
                Container(
                  padding: const EdgeInsets.all(16),
                  // THEME CHANGE: Container color
                  decoration: BoxDecoration(
                    color: containerColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'SESSION STATISTICS',
                        style: TextStyle(
                          color: textColor.withOpacity(0.7),
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
                                _buildStatistic("Good", "$goodPercentage%", Colors.green, textColor),
                                _buildStatistic("Warning/Neutral", "$warningPercentage%", Colors.orange, textColor),
                                _buildStatistic("Poor", "$badPercentage%", Colors.red, textColor),
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
                                    : Container(color: textColor.withOpacity(0.1)), // THEME CHANGE: Inactive bar color
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          "Connect device to track session statistics.",
                          style: TextStyle(color: textColor.withOpacity(0.54), fontSize: 14),
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