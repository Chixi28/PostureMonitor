import 'package:flutter/material.dart';
import 'dart:math' as math;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin { // Changed to TickerProviderStateMixin

  // 1. Main Controller (for scale and fade - runs once)
  late AnimationController _mainController;

  // 2. Rotation Controller (for continuous spin - repeats)
  late AnimationController _rotationController;

  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();

    // 1. Initialize Main Controller (Runs once, 3 seconds duration)
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    // 2. Initialize Rotation Controller (Runs continuously, 2 seconds for a full spin)
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(); // Starts repeating immediately

    // --- Animations linked to _mainController (run once) ---

    // Icon pulses in and out, settling at 1.0 scale
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeInOut),
      ),
    );

    // Text fades in and stays visible (Interval ends at 1.0)
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeIn), // Tweak: Ends at 1.0
      ),
    );

    // --- Animation linked to _rotationController (repeats) ---

    // Subtle rotation for a "scanning" ring effect (uses the repeating controller)
    _rotationAnimation = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(
        parent: _rotationController, // Tweak: Uses the repeating controller
        curve: Curves.linear,
      ),
    );

    // Start the main animation sequence
    _mainController.forward();

    // Navigate after animation + buffer
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, "/home");
      }
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _rotationController.dispose(); // Dispose the second controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A1A2E), // Dark Deep Blue
              Color(0xFF0F0F1A), // Almost Black
            ],
          ),
        ),
        child: Stack(
          children: [
            // Centered Content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // The Animated Icon Stack
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Rotating "Scanner" Ring (Listens to _rotationController)
                      AnimatedBuilder(
                        animation: _rotationController, // Tweak: Listens to the repeating controller
                        builder: (context, child) {
                          return Transform.rotate(
                            // Tweak: Use the prepared animation value
                            angle: _rotationAnimation.value,
                            child: Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.deepPurpleAccent.withOpacity(0.3),
                                  width: 2,
                                  style: BorderStyle.solid,
                                ),
                                gradient: const SweepGradient(
                                  colors: [
                                    Color.fromARGB(0, 103, 58, 183), // fully transparent deepPurpleAccent
                                    Colors.deepPurpleAccent,
                                  ],
                                  stops: [0.5, 1.0],
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      // Pulsing Icon with Glow (Listens to _mainController via ScaleTransition)
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.deepPurpleAccent.withOpacity(0.6),
                                blurRadius: 40,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.earbuds_sharp,
                            size: 80,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // Animated Text (Fade & Slide - Listens to _mainController via FadeTransition)
                  FadeTransition(
                    opacity: _fadeAnimation, // Tweak: This now holds 1.0 until navigation
                    child: Column(
                      children: [
                        const Text(
                          "POSTURE MONITOR",
                          style: TextStyle(
                            fontSize: 24,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 3.0,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "INITIALIZING SENSORS...",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.5),
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Progress Indicator (Continuous visual sign of loading)
            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: Center(
                child: SizedBox(
                  width: 200,
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.white.withOpacity(0.1),
                    color: Colors.deepPurpleAccent,
                    minHeight: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}