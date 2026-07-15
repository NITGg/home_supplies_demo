import 'package:flutter/material.dart';
import '../utils/biometric_auth_service.dart';
import '../utils/secure_storage_service.dart';

class BiometricLockScreen extends StatefulWidget {
  final VoidCallback onPassed;
  final VoidCallback onLogout;

  const BiometricLockScreen({
    super.key,
    required this.onPassed,
    required this.onLogout,
  });

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen>
    with WidgetsBindingObserver {
  static const _maxFailures = 5;

  bool _isPrompting = false;
  bool _disposed = false;
  int _failures = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _prompt());
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-trigger the prompt whenever the app comes back to foreground
  /// while this lock screen is still visible (e.g. user backgrounded
  /// after dismissing the sheet).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_isPrompting) {
      _prompt();
    }
  }

  Future<void> _prompt() async {
    if (_disposed || !mounted || _isPrompting) return;

    _isPrompting = true;
    try {
      final result =
      await BiometricManager().verifyBiometric(context: context);

      if (_disposed || !mounted) return;

      switch (result) {
        case BiometricVerifyResult.passed:
          widget.onPassed();
          return; // caller replaces widget tree — we're done

        case BiometricVerifyResult.canceled:
        // User dismissed — schedule an immediate re-prompt.
        // The brief delay lets the platform sheet fully close so the
        // next authenticate() call opens a fresh sheet.
          await Future.delayed(const Duration(milliseconds: 400));
          _isPrompting = false;
          _prompt(); // tail-recurse (not a loop, so mounted is re-checked)
          return;

        case BiometricVerifyResult.failed:
          _failures++;
          if (_failures >= _maxFailures) {
            await SecureStorageService().clearAll();
            if (mounted) widget.onLogout();
            return;
          }
          await Future.delayed(const Duration(milliseconds: 400));
          _isPrompting = false;
          _prompt();
          return;
      }
    } catch (_) {
      // Never let an exception leave this screen unlocked.
      _isPrompting = false;
      if (mounted) _prompt();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'تأكيد الهوية | Verify Identity',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 32),
                _isPrompting
                    ? const CircularProgressIndicator.adaptive()
                    : FilledButton.icon(
                  onPressed: _prompt,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Verify | تأكيد'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}