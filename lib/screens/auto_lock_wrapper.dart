import 'dart:async';
import 'package:flutter/material.dart';
import 'login_screen.dart';

// Global flag to pause auto-lock during file picker or other system dialogs
bool autoLockPaused = false;

class AutoLockWrapper extends StatefulWidget {
  final Widget child;
  final int timeoutMinutes;

  const AutoLockWrapper({
    Key? key,
    required this.child,
    this.timeoutMinutes = 2,
  }) : super(key: key);

  @override
  State<AutoLockWrapper> createState() => _AutoLockWrapperState();
}

class _AutoLockWrapperState extends State<AutoLockWrapper>
    with WidgetsBindingObserver {
  Timer? _lockTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resetTimer();
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // If paused (file picker open), don't lock on background
    if (autoLockPaused) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _lockVault();
    } else if (state == AppLifecycleState.resumed) {
      _resetTimer();
    }
  }

  void _resetTimer() {
    _lockTimer?.cancel();
    _lockTimer = Timer(
      Duration(minutes: widget.timeoutMinutes),
      () {
        // Don't lock if paused (file picker open)
        if (!autoLockPaused) _lockVault();
      },
    );
  }

  void _lockVault() {
    _lockTimer?.cancel();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _resetTimer(),
      onPointerMove: (_) => _resetTimer(),
      child: widget.child,
    );
  }
}
