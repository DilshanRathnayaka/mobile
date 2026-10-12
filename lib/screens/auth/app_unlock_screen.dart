import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/portfolio_provider.dart';
import '../../providers/security_provider.dart';
import '../../providers/session_provider.dart';
import 'auth_screen.dart';

class AppUnlockScreen extends ConsumerStatefulWidget {
  const AppUnlockScreen({super.key});

  @override
  ConsumerState<AppUnlockScreen> createState() => _AppUnlockScreenState();
}

class _AppUnlockScreenState extends ConsumerState<AppUnlockScreen> {
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _promptBiometricUnlock();
    });
  }

  Future<void> _promptBiometricUnlock() async {
    if (_isAuthenticating) return;
    setState(() => _isAuthenticating = true);

    try {
      final success = await ref.read(securityProvider.notifier).unlockApp();
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authentication failed or cancelled. Please retry.'),
            backgroundColor: AppColors.loss,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAuthenticating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = AppColors.background(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primaryGlow,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 2),
                  ),
                  child: const Icon(Icons.lock_outline, size: 40, color: AppColors.primary),
                ),
                const SizedBox(height: 24),
                Text(
                  'Asset Manager Locked',
                  style: TextStyle(color: textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Biometric authentication is required to access your financial portfolio',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 36),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isAuthenticating ? null : _promptBiometricUnlock,
                  icon: const Icon(Icons.fingerprint, size: 24, color: Colors.white),
                  label: _isAuthenticating
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Unlock with Biometrics', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () async {
                    resetUserSessionState(ref);
                    await ref.read(supabaseServiceProvider).signOut();
                    if (context.mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const AuthScreen()),
                        (r) => false,
                      );
                    }
                  },
                  child: Text('Sign Out of Account', style: TextStyle(color: textSecondary, fontSize: 13)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
