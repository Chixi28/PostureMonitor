import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider/theme_provider.dart';
import '../bluetooth/open_earable_manager.dart';
import 'dart:math';

enum PostureStatus {
  good,
  warning,
  neutral,
  bad,
  calibrating,
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
  double _currentPitch = 0.0;    // Head tilt forward/backward
  double _currentRoll = 0.0;     // Head tilt side to side
  double _currentYaw = 0.0;      // Head rotation left/right
  double _currentMagnitude = 0.0; // Overall movement

  // Posture status
  PostureStatus _postureStatus = PostureStatus.neutral;
  String _postureMessage = "Waiting for data...";
  Color _postureColor = Colors.grey;

  // History for smoothing
  final List<double> _pitchHistory = [];
  final List<double> _rollHistory = [];
  final int _maxHistory = 20;

  // Calibration parameters
  double _calibratedPitch = 0.0;       // Baseline good posture pitch
  double _calibratedRoll = 0.0;        // Baseline good posture roll
  double _calibratedPitchStd = 0.0;    // Natural variation in pitch during good posture
  double _calibratedRollStd = 0.0;     // Natural variation in roll during good posture
  List<double> _calibrationPitchSamples = [];
  List<double> _calibrationRollSamples = [];
  bool _isCalibrated = false;

  // Guided calibration state
  bool _isCalibrating = false;
  int _calibrationProgress = 0;
  String _calibrationMessage = "Get ready for calibration...";
  Timer? _calibrationTimer;
  int _calibrationSampleCount = 0;
  final int _calibrationRequiredSamples = 50;
  final int _calibrationSampleDuration = 5000;

  // Dynamic thresholds based on calibration
  double _goodPitchThreshold = 15.0;    // Increased from 10.0
  double _warningPitchThreshold = 25.0; // Increased from 20.0
  double _badPitchThreshold = 35.0;     // Increased from 30.0
  double _goodRollThreshold = 12.0;     // Increased from 8.0
  double _warningRollThreshold = 20.0;  // Increased from 15.0

  // Movement detection
  static const double _movementThreshold = 0.05;
  bool _isMoving = false;
  int _stillTime = 0;

  // REMOVED: Statistics variables
  // int _goodPostureTime = 0;
  // int _warningPostureTime = 0;
  // int _badPostureTime = 0;
  // Timer? _statisticsTimer;

  DateTime? _sessionStartTime;
  bool _initialConnectionCheckPassed = false;

  @override
  void initState() {
    super.initState();
    final isConnected = bluetoothManager.isConnected;
    if (isConnected) {
      _initialConnectionCheckPassed = true;
      _sessionStartTime = DateTime.now();
      _postureMessage = "Please calibrate your good posture first";
      _postureColor = Colors.blue;
      _postureStatus = PostureStatus.neutral;
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
        // REMOVED: Statistics timer start
        // _goodPostureTime = 0;
        // _warningPostureTime = 0;
        // _badPostureTime = 0;
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
        _postureStatus = PostureStatus.neutral;
        _postureColor = Colors.blueGrey;
        _postureMessage = "Device disconnected. Please connect the OpenEarable.";
      }
    });
  }

  void _handleAccelerometerData(Map<String, double> data) {
    if (!mounted || !bluetoothManager.isConnected) {
      return;
    }

    setState(() {
      accelerometerData = data;
      _currentPitch = _calculatePitch(data);
      _currentRoll = _calculateRoll(data);
      _currentYaw = _calculateYaw(data);
      _currentMagnitude = _calculateMagnitude(data);

      _updateHistory();

      if (_isCalibrating) {
        _collectCalibrationSample();
      } else {
        if (_isCalibrated) {
          _analyzePosture();
        }
        _detectMovement();
      }
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

  void _startGuidedCalibration() {
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
      _isCalibrating = true;
      _calibrationProgress = 0;
      _calibrationSampleCount = 0;
      _calibrationPitchSamples.clear();
      _calibrationRollSamples.clear();
      _calibrationMessage = "1. Sit in a comfortable, upright position\n2. Look straight ahead\n3. Keep your head level\n4. Hold still for 5 seconds...";
      _postureStatus = PostureStatus.calibrating;
      _postureColor = Colors.blue;
      _postureMessage = "Calibrating...";
    });

    _calibrationTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted || !bluetoothManager.isConnected || _calibrationSampleCount >= _calibrationRequiredSamples) {
        timer.cancel();
        _completeCalibration();
        return;
      }

      setState(() {
        _calibrationProgress = (_calibrationSampleCount * 100 ~/ _calibrationRequiredSamples);
        if (_calibrationProgress % 20 == 0) {
          _calibrationMessage = "Hold still... ${(5 - (_calibrationSampleCount * 5 ~/ _calibrationRequiredSamples))}s remaining";
        }
      });
    });
  }

  void _collectCalibrationSample() {
    if (_calibrationSampleCount >= _calibrationRequiredSamples) return;

    if (_pitchHistory.length >= 3) {
      double pitchVariance = _calculateVariance(_pitchHistory);
      double rollVariance = _calculateVariance(_rollHistory);

      if (pitchVariance < _movementThreshold * 2 && rollVariance < _movementThreshold * 2) {
        _calibrationPitchSamples.add(_currentPitch);
        _calibrationRollSamples.add(_currentRoll);
        _calibrationSampleCount++;
      }
    }
  }

  void _completeCalibration() {
    if (!mounted) return;

    if (_calibrationPitchSamples.length < _calibrationRequiredSamples * 0.8) {
      setState(() {
        _isCalibrating = false;
        _calibrationMessage = "Calibration failed. Please hold still and try again.";
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Calibration failed. Please hold still and try again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    double pitchMean = _calculateMean(_calibrationPitchSamples);
    double rollMean = _calculateMean(_calibrationRollSamples);
    double pitchStd = _calculateStandardDeviation(_calibrationPitchSamples, pitchMean);
    double rollStd = _calculateStandardDeviation(_calibrationRollSamples, rollMean);

    double pitchStdMultiplier = max(pitchStd, 3.0);
    double rollStdMultiplier = max(rollStd, 2.5);

    setState(() {
      _calibratedPitch = pitchMean;
      _calibratedRoll = rollMean;
      _calibratedPitchStd = pitchStd;
      _calibratedRollStd = rollStd;

      // Set dynamic thresholds with increased base values
      _goodPitchThreshold = max(pitchStdMultiplier * 1.5, 12.0);
      _warningPitchThreshold = max(pitchStdMultiplier * 2.5, 22.0);
      _badPitchThreshold = max(pitchStdMultiplier * 3.5, 32.0);

      _goodRollThreshold = max(rollStdMultiplier * 1.5, 10.0);
      _warningRollThreshold = max(rollStdMultiplier * 2.5, 18.0);

      _isCalibrated = true;
      _isCalibrating = false;
      _calibrationProgress = 100;
      _calibrationMessage = "Calibration complete!";

      _pitchHistory.clear();
      _rollHistory.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Calibration complete! Good posture baseline established.\nYour target: Pitch: ${pitchMean.toStringAsFixed(1)}°, Roll: ${rollMean.toStringAsFixed(1)}°'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _analyzePosture() {
    if (!bluetoothManager.isConnected || !_isCalibrated) return;

    if (_pitchHistory.length < 3) {
      _postureStatus = PostureStatus.neutral;
      _postureMessage = "Analyzing posture...";
      _postureColor = Colors.blue;
      return;
    }

    // Use smoothed values
    double avgPitch = _getAverage(_pitchHistory);
    double avgRoll = _getAverage(_rollHistory);

    // Calculate deviation from calibrated baseline
    double pitchDeviation = (avgPitch - _calibratedPitch).abs();
    double rollDeviation = (avgRoll - _calibratedRoll).abs();

    // Determine posture status based on deviations
    if (pitchDeviation > _badPitchThreshold || rollDeviation > _badPitchThreshold) {
      _postureStatus = PostureStatus.bad;
      _postureColor = Colors.red;
      if (pitchDeviation > rollDeviation) {
        if (avgPitch > _calibratedPitch) {
          _postureMessage = "You're leaning too far forward!\nSit up straight.";
        } else {
          _postureMessage = "Head tilted too far back!\nBring head forward.";
        }
      } else {
        if (avgRoll > _calibratedRoll) {
          _postureMessage = "Head tilted too far right!\nCenter your head.";
        } else {
          _postureMessage = "Head tilted too far left!\nCenter your head.";
        }
      }
    } else if (pitchDeviation > _warningPitchThreshold || rollDeviation > _warningRollThreshold) {
      _postureStatus = PostureStatus.warning;
      _postureColor = Colors.orange;
      if (pitchDeviation > rollDeviation) {
        _postureMessage = "Slight slouch detected.\nAdjust your posture.";
      } else {
        _postureMessage = "Head slightly tilted.\nStraighten up.";
      }
    } else if (pitchDeviation <= _goodPitchThreshold && rollDeviation <= _goodRollThreshold) {
      _postureStatus = PostureStatus.good;
      _postureColor = Colors.green;
      _postureMessage = "Excellent posture! Keep it up!";
    } else {
      _postureStatus = PostureStatus.neutral;
      _postureColor = Colors.blue;
      _postureMessage = "Acceptable posture.\nCould be improved.";
    }
  }

  void _detectMovement() {
    if (!bluetoothManager.isConnected) return;
    if (_pitchHistory.length < 5) return;

    double pitchVariance = _calculateVariance(_pitchHistory);
    double rollVariance = _calculateVariance(_rollHistory);
    _isMoving = (pitchVariance > _movementThreshold) || (rollVariance > _movementThreshold);

    if (_isMoving) {
      _stillTime = 0;
    } else {
      _stillTime++;
    }
  }

  // REMOVED: _startStatisticsTimer method

  // Statistical calculations
  double _calculateMean(List<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  double _calculateStandardDeviation(List<double> values, double mean) {
    if (values.length < 2) return 0.0;
    double variance = 0.0;
    for (var value in values) {
      variance += pow(value - mean, 2);
    }
    return sqrt(variance / values.length);
  }

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
    return atan2(x, z) * 180 / pi;
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

  String _getSessionDuration() {
    if (_sessionStartTime == null || !bluetoothManager.isConnected) return "0:00";
    final duration = DateTime.now().difference(_sessionStartTime!);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

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
      case PostureStatus.calibrating:
        return Icons.timer;
    }
  }

  Widget _buildCalibrationView(BuildContext context, Color textColor, Color containerColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.auto_awesome, color: Colors.blue, size: 60),
          const SizedBox(height: 20),
          const Text(
            'Guided Calibration',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _calibrationMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.blue, fontSize: 14),
          ),
          const SizedBox(height: 20),
          LinearProgressIndicator(
            value: _calibrationProgress / 100,
            backgroundColor: Colors.blue.withOpacity(0.2),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
          const SizedBox(height: 10),
          Text(
            '$_calibrationProgress% Complete',
            style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
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
        ],
      ),
    );
  }

  Widget _buildConnectedVisualization(BuildContext context, Color textColor, Color containerColor) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final centerX = constraints.maxWidth / 2;
        final centerY = constraints.maxHeight / 2;
        final maxRadius = (min(constraints.maxWidth, constraints.maxHeight) / 2) * 0.8;

        double pitchDeviation = _isCalibrated ? (_currentPitch - _calibratedPitch) : _currentPitch;
        double rollDeviation = _isCalibrated ? (_currentRoll - _calibratedRoll) : _currentRoll;

        final clampedPitchDeviation = pitchDeviation.clamp(-45.0, 45.0);
        final clampedRollDeviation = rollDeviation.clamp(-45.0, 45.0);

        final displayX = centerX + (clampedRollDeviation / 45.0) * maxRadius;
        final displayY = centerY + (clampedPitchDeviation / 45.0) * maxRadius;

        return Column(
          children: [
            Text(
              _isCalibrated ? 'DEVIATION FROM GOOD POSTURE' : 'HEAD ORIENTATION',
              style: TextStyle(
                color: textColor.withOpacity(0.7),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 0),
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Background grid
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: textColor.withOpacity(0.1)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),

                  // Concentric posture zones, properly centered
                  if (_isCalibrated) ...[
                    // Bad posture zone (outer ring)
                    Positioned(
                      left: centerX - ( (2 * _badPitchThreshold / 45.0) * maxRadius) / 2,
                      top: centerY - ( (2 * _badPitchThreshold / 45.0) * maxRadius) / 2,
                      child: Container(
                        width: (2 * _badPitchThreshold / 45.0) * maxRadius,
                        height: (2 * _badPitchThreshold / 45.0) * maxRadius,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.red.withOpacity(0.5), width: 3.0),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    // Warning posture zone (middle ring)
                    Positioned(
                      left: centerX - ( (2 * _warningPitchThreshold / 45.0) * maxRadius) / 2,
                      top: centerY - ( (2 * _warningPitchThreshold / 45.0) * maxRadius) / 2,
                      child: Container(
                        width: (2 * _warningPitchThreshold / 45.0) * maxRadius,
                        height: (2 * _warningPitchThreshold / 45.0) * maxRadius,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.orange.withOpacity(0.5), width: 3.0),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    // Good posture zone (inner ring)
                    Positioned(
                      left: centerX - ( (2 * _goodPitchThreshold / 45.0) * maxRadius) / 2,
                      top: centerY - ( (2 * _goodPitchThreshold / 45.0) * maxRadius) / 2,
                      child: Container(
                        width: (2 * _goodPitchThreshold / 45.0) * maxRadius,
                        height: (2 * _goodPitchThreshold / 45.0) * maxRadius,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.green.withOpacity(0.5), width: 3.0),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],

                  // Center crosshair
                  Positioned(
                    top: centerY - 1,
                    left: 0,
                    right: 0,
                    child: Container(height: 2, color: Colors.blue.withOpacity(0.5)),
                  ),
                  Positioned(
                    left: centerX - 1,
                    top: 0,
                    bottom: 0,
                    child: Container(width: 2, color: Colors.blue.withOpacity(0.5)),
                  ),

                  // Center point
                  Positioned(
                    left: centerX - 8,
                    top: centerY - 8,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.7),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.star,
                        color: Colors.white,
                        size: 8,
                      ),
                    ),
                  ),

                  // Head position indicator
                  Positioned(
                    left: displayX - 25,
                    top: displayY - 25,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: _postureColor.withOpacity(0.6),
                        shape: BoxShape.circle,
                        border: Border.all(color: _postureColor, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: _postureColor.withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.face,
                        color: textColor,
                        size: 30,
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
                _buildOrientationReading(
                  "PITCH",
                  "${_currentPitch.toStringAsFixed(1)}°",
                  _isCalibrated ? "${(_currentPitch - _calibratedPitch).toStringAsFixed(1)}°" : "--",
                  Colors.purpleAccent,
                ),
                _buildOrientationReading(
                  "ROLL",
                  "${_currentRoll.toStringAsFixed(1)}°",
                  _isCalibrated ? "${(_currentRoll - _calibratedRoll).toStringAsFixed(1)}°" : "--",
                  Colors.orangeAccent,
                ),
                _buildOrientationReading(
                  "STATUS",
                  _isCalibrated ? _postureStatus.toString().split('.').last.toUpperCase() : "UNCALIBRATED",
                  _isCalibrated ? "" : "",
                  _postureColor,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildOrientationReading(String label, String value, String deviation, Color color) {
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
        if (deviation.isNotEmpty)
          Text(
            _isCalibrated ? "Δ: $deviation" : "",
            style: TextStyle(
              color: color.withOpacity(0.6),
              fontSize: 10,
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    // REMOVED: Statistics timer cancellation
    _calibrationTimer?.cancel();
    bluetoothManager.removeAccelerometerCallback(_handleAccelerometerData);
    bluetoothManager.removeConnectionCallback(_handleConnectionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.currentBrightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final containerColor = isDarkMode ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05);
    final isConnected = bluetoothManager.isConnected;

    int postureScore = 100;
    if (_postureStatus == PostureStatus.warning) postureScore = 75;
    if (_postureStatus == PostureStatus.neutral) postureScore = 60;
    if (_postureStatus == PostureStatus.bad) postureScore = 40;
    if (_postureStatus == PostureStatus.calibrating) postureScore = 0;

    if (!isConnected || !_isCalibrated) {
      postureScore = 0;
      _postureColor = Colors.blueGrey;
      if (!_isCalibrated && isConnected) {
        _postureMessage = "Please calibrate your posture first";
      }
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Posture Monitor", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: _isCalibrating
                ? const Icon(Icons.timer, color: Colors.blue)
                : Icon(
              _isCalibrated ? Icons.check_circle : Icons.calendar_today,
              color: isConnected ? Theme.of(context).iconTheme.color?.withOpacity(0.7) : Colors.grey,
            ),
            onPressed: isConnected && !_isCalibrating ? _startGuidedCalibration : null,
            tooltip: _isCalibrated ? 'Recalibrate Posture' : 'Start Guided Calibration',
          ),
        ],
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                          isConnected
                              ? bluetoothManager.connectedDevice?.name ?? bluetoothManager.connectedDevice?.id ?? 'OpenEarable Device'
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

                // Calibration view or posture status
                if (_isCalibrating)
                  _buildCalibrationView(context, textColor, containerColor)
                else
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'POSTURE STATUS',
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
                                isConnected && _isCalibrated ? '$postureScore/100' : 'N/A',
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

                        Text(
                          _postureMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const SizedBox(height: 16),

                        Icon(
                          isConnected ? _getPostureIcon() : Icons.bluetooth_disabled,
                          color: _postureColor,
                          size: 60,
                        ),

                        const SizedBox(height: 16),

                        if (!isConnected)
                          ElevatedButton.icon(
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
                          )
                        else if (!_isCalibrated)
                          ElevatedButton.icon(
                            onPressed: _startGuidedCalibration,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            ),
                            icon: const Icon(Icons.auto_awesome, color: Colors.white),
                            label: const Text(
                              "START GUIDED CALIBRATION",
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ),

                const SizedBox(height: 20),

                // Visualization
                Container(
                  height: 400, // Slightly increased height for better visibility
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: containerColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: textColor.withOpacity(0.1)),
                  ),
                  child: !isConnected
                      ? _buildDisconnectedView(context, textColor, containerColor)
                      : _buildConnectedVisualization(context, textColor, containerColor),
                ),

                // REMOVED: Session Statistics section
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}