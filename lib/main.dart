import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/setup_screen.dart';
import 'screens/login_screen.dart';
import 'screens/auth_screen.dart';
import 'services/auth_service.dart';
import 'services/firebase_auth_service.dart';
import 'services/sms_wipe_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Check for SMS wipe triggered while app was closed
  final smsWipeService = SmsWipeService();
  await smsWipeService.checkAndExecutePendingWipe();

  // Check if onboarding has been shown before
  final showOnboarding = await OnboardingScreen.shouldShow();

  runApp(CryptaSafeApp(showOnboarding: showOnboarding));
}

class CryptaSafeApp extends StatelessWidget {
  final bool showOnboarding;
  const CryptaSafeApp({Key? key, required this.showOnboarding}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calculator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blueGrey,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Colors.blueGrey,
          surface: Color(0xFF111111),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey[900],
          elevation: 0,
        ),
      ),
      home: showOnboarding
          ? const OnboardingScreen()
          : const SplashScreen(),
    );
  }
}
