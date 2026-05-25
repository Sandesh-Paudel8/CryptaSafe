import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'calculator_screen.dart';

const _kOnboardingDone = 'cryptasafe_onboarding_done';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  static Future<bool> shouldShow() async {
    const storage = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    );
    final done = await storage.read(key: _kOnboardingDone);
    return done != 'true';
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  final _pages = const [
    _OnboardingPage(
      icon: Icons.lock_rounded,
      title: 'Military-grade encryption',
      description:
          'All your files and notes are encrypted with AES-256 and PBKDF2 key derivation. Only you can unlock them.',
      color: Color(0xFF37474F),
    ),
    _OnboardingPage(
      icon: Icons.cloud_done_outlined,
      title: 'Encrypted cloud backup',
      description:
          'Back up your encrypted files to the cloud. Your data is always encrypted before it leaves your device.',
      color: Color(0xFF1565C0),
    ),
    _OnboardingPage(
      icon: Icons.calculate_outlined,
      title: 'Hidden in plain sight',
      description:
          'The app looks like a calculator. Enter your secret code to reveal your vault. Nobody will know it\'s there.',
      color: Color(0xFF2E7D32),
    ),
    _OnboardingPage(
      icon: Icons.shield_outlined,
      title: 'Remote wipe & recovery',
      description:
          'Lost your phone? Send a secret SMS to wipe the vault. Add trusted contacts to help you recover access.',
      color: Color(0xFF6A1B9A),
    ),
  ];

  Future<void> _finish() async {
    const storage = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    );
    await storage.write(key: _kOnboardingDone, value: 'true');
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const CalculatorScreen()),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  onPressed: _finish,
                  child: Text('Skip',
                      style: TextStyle(color: Colors.grey[500])),
                ),
              ),
            ),

            // Pages
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _pages.length,
                itemBuilder: (_, i) => _pages[i],
              ),
            ),

            // Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == i ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == i
                        ? Colors.blueGrey[400]
                        : Colors.grey[700],
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),

            const SizedBox(height: 24),

            // Next / Get started button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_currentPage < _pages.length - 1) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      _finish();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey[700],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    _currentPage < _pages.length - 1
                        ? 'Next'
                        : 'Get started',
                    style: const TextStyle(
                        fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(36),
              border: Border.all(color: color.withOpacity(0.4), width: 1.5),
            ),
            child: Icon(icon, size: 60, color: color),
          ),
          const SizedBox(height: 40),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[400],
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
