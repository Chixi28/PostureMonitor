import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Splash screen displayed during application startup.
///
/// This screen presents an animated logo with:
/// - A pulsing central icon
/// - A continuously rotating scanner ring
/// - Fading introductory text
/// - A persistent progress indicator
///
/// After the animation sequence completes, the user is automatically
/// navigated to the home screen.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

/// State implementation for [SplashScreen].
///
/// Uses two independent animation controllers:
/// - One controller for the main entrance animations (scale + fade)
/// - One controller for a continuous rotation effect
///
/// The separation allows smooth looping effects without restarting
/// the primary animation timeline.
class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  /// Controller responsible for one-time animations such as
  /// scaling the icon and fading in the text.
  late AnimationController _mainController;

  /// Controller responsible for continuous rotation of the scanner ring.
  late AnimationController _rotationController;

  /// Controls the pulsing scale of the central icon.
  late Animation<double> _scaleAnimation;

  /// Controls the opacity of the splash text.
  late Animation<double> _fadeAnimation;

  /// Controls the angular rotation of the scanner ring.
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();

    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeInOut),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
      ),
    );

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(
      CurvedAnimation(
        parent: _rotationController,
        curve: Curves.linear,
      ),
    );

    _mainController.forward();

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, "/home");
      }
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _rotationController.dispose();
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
              Color(0xFF1A1A2E),
              Color(0xFF0F0F1A),
            ],
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _rotationController,
                        builder: (context, child) {
                          return Transform.rotate(
                            angle: _rotationAnimation.value,
                            child: Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.deepPurpleAccent.withValues(alpha: 0.3),
                                  width: 2,
                                ),
                                gradient: const SweepGradient(
                                  colors: [
                                    Color.fromARGB(0, 103, 58, 183),
                                    Colors.deepPurpleAccent,
                                  ],
                                  stops: [0.5, 1.0],
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.deepPurpleAccent.withValues(alpha: 0.6),
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

                  FadeTransition(
                    opacity: _fadeAnimation,
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
                            color: Colors.white.withValues(alpha: 0.5),
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: Center(
                child: SizedBox(
                  width: 200,
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
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