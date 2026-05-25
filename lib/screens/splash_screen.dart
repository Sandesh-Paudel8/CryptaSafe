import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/firebase_auth_service.dart';
import 'setup_screen.dart';
import 'auth_screen.dart';
import 'login_screen.dart';
import 'calculator_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _fadeController;
  late AnimationController _unlockController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  final _authService = AuthService();
  final _firebaseAuth = FirebaseAuthService();

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _unlockController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _scaleAnim = CurvedAnimation(
        parent: _scaleController, curve: Curves.elasticOut);
    _fadeAnim = CurvedAnimation(
        parent: _fadeController, curve: Curves.easeIn);

    _startAnimation();
  }

  Future<void> _startAnimation() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _scaleController.forward();

    await Future.delayed(const Duration(milliseconds: 600));
    _fadeController.forward();

    await Future.delayed(const Duration(milliseconds: 800));
    _unlockController.forward();

    // Check routing while animation finishes
    final isVaultSetup = await _authService.isVaultSetup();
    final isFirebaseLoggedIn = _firebaseAuth.isLoggedIn;

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    Widget destination;

    if (!isVaultSetup) {
      // First time — go to vault setup
      destination = const SetupScreen();
    } else if (!isFirebaseLoggedIn) {
      // Vault set up but not signed into Firebase — show auth screen
      destination = const AuthScreen();
    } else {
      // Everything ready — go to calculator (disguise home)
      // User enters 1337# to reach vault login
      destination = const CalculatorScreen();
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => destination,
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _fadeController.dispose();
    _unlockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated lock icon
            ScaleTransition(
              scale: _scaleAnim,
              child: AnimatedBuilder(
                animation: _unlockController,
                builder: (_, __) => Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.blueGrey[800],
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Icon(
                    _unlockController.value > 0.5
                        ? Icons.lock_open_rounded
                        : Icons.lock_rounded,
                    size: 52,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // App name fade in
            FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                children: [
                  const Text(
                    'CryptaSafe',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your private vault',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 60),

            FadeTransition(
              opacity: _fadeAnim,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.blueGrey[400],
                    shape: BoxShape.circle,
                  ),
                )),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
