import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/portfolio_provider.dart';
import '../../providers/security_provider.dart';
import '../../providers/session_provider.dart';
import '../../providers/theme_provider.dart';
import '../main_screen.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isSignUp = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _proceedToMainScreen() {
    resetUserSessionState(ref);
    ref.read(portfolioSummaryProvider.notifier).refresh();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainScreen()),
    );
  }

  Future<void> _check2FaAndProceed() async {
    final supabase = ref.read(supabaseServiceProvider);
    final mfaStatus = await supabase.getMfaStatus();

    // If user has verified TOTP factor and current level is AAL1, require MFA challenge
    if (mfaStatus.isEnrolled && !mfaStatus.isAal2) {
      if (mounted) {
        final factor = mfaStatus.primaryTotpFactor;
        if (factor != null) {
          _showRealMfaChallengeModal(factor.id);
          return;
        }
      }
    }

    _proceedToMainScreen();
  }

  void _showRealMfaChallengeModal(String factorId) {
    final codeCtrl = TextEditingController();
    final surfaceColor = AppColors.surface(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    bool verifying = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: surfaceColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.security, color: AppColors.primary, size: 24),
                  const SizedBox(width: 10),
                  Text('Google Authenticator 2FA', style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Enter the 6-digit verification code from Google Authenticator to elevate your session to AAL2:',
                style: TextStyle(color: textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: codeCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                autofocus: true,
                style: TextStyle(color: textPrimary, fontSize: 20, letterSpacing: 8, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.surfaceLight(context),
                  hintText: '000000',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: verifying
                    ? null
                    : () async {
                        final code = codeCtrl.text.trim();
                        if (code.length != 6) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter valid 6-digit code'), backgroundColor: AppColors.loss),
                          );
                          return;
                        }

                        setModalState(() => verifying = true);
                        try {
                          final supabase = ref.read(supabaseServiceProvider);
                          await supabase.challengeAndVerifyMfaTotp(factorId: factorId, code: code);
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                          }
                          _proceedToMainScreen();
                        } catch (e) {
                          setModalState(() => verifying = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text('Verification rejected: $e'), backgroundColor: AppColors.loss),
                            );
                          }
                        }
                      },
                child: verifying
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Verify & Enter Terminal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await ref.read(supabaseServiceProvider).signOut();
                  },
                  child: Text('Cancel & Sign Out', style: TextStyle(color: textSecondary, fontSize: 12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final emailCtrl = TextEditingController(text: _emailController.text.trim());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        title: Text('Reset Password', style: TextStyle(color: AppColors.textPrimary(context))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter your account email to receive a password recovery link:',
                style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(color: AppColors.textPrimary(context)),
              decoration: InputDecoration(
                labelText: 'Email Address',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary(context))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              final email = emailCtrl.text.trim();
              if (email.isNotEmpty) {
                Navigator.pop(ctx);
                try {
                  await ref.read(supabaseServiceProvider).resetPasswordForEmail(email);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Password reset instructions sent to your email!'), backgroundColor: AppColors.profit),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.loss),
                    );
                  }
                }
              }
            },
            child: const Text('Send Reset Link', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleBiometricLogin() async {
    final supabase = ref.read(supabaseServiceProvider);
    if (!supabase.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in with password first to establish a session'), backgroundColor: AppColors.loss),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final success = await ref.read(securityProvider.notifier).authenticateWithBiometrics();
      if (success) {
        if (mounted) {
          await _check2FaAndProceed();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Biometric authentication failed or cancelled'), backgroundColor: AppColors.loss),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAuth() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final supabaseService = ref.read(supabaseServiceProvider);
    final email = _emailController.text.trim();
    // Preserve password whitespace rather than trimming
    final password = _passwordController.text;

    try {
      if (_isSignUp) {
        final res = await supabaseService.signUp(email, password);
        if (mounted) {
          if (res?.session == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Account created! Please check your email inbox to confirm your account before signing in.'),
                backgroundColor: AppColors.profit,
                duration: Duration(seconds: 5),
              ),
            );
            setState(() => _isSignUp = false);
            return;
          }
        }
      } else {
        await supabaseService.signIn(email, password);
      }

      if (mounted) {
        resetUserSessionState(ref);
        await _check2FaAndProceed();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Authentication error: $e'), backgroundColor: AppColors.loss),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = AppColors.background(context);
    final surfaceColor = AppColors.surface(context);
    final surfaceLight = AppColors.surfaceLight(context);
    final borderColor = AppColors.border(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final textMuted = AppColors.textMuted(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final security = ref.watch(securityProvider);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              color: textSecondary,
            ),
            onPressed: () => ref.read(themeModeProvider.notifier).toggleTheme(),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Brand Icon
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, Color(0xFFFF9500)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withAlpha(80),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.trending_up,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title
                  Text(
                    'Asset Manager',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Institutional-grade DCA & Portfolio Tracking',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 36),

                  // Segmented Switch (Sign In vs Create Account)
                  Container(
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _isSignUp = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: !_isSignUp ? surfaceLight : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Sign In',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: !_isSignUp ? textPrimary : textMuted,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _isSignUp = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _isSignUp ? surfaceLight : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Create Account',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _isSignUp ? textPrimary : textMuted,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Email
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(color: textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      labelStyle: TextStyle(color: textSecondary),
                      prefixIcon: Icon(Icons.email_outlined, color: textMuted),
                      filled: true,
                      fillColor: surfaceColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                    ),
                    validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                  ),
                  const SizedBox(height: 16),

                  // Password
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    style: TextStyle(color: textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: TextStyle(color: textSecondary),
                      prefixIcon: Icon(Icons.lock_outline, color: textMuted),
                      filled: true,
                      fillColor: surfaceColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                    ),
                    validator: (v) => (v == null || v.length < 6) ? 'Password must be at least 6 characters' : null,
                  ),

                  // Forgot Password
                  if (!_isSignUp) ...[
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _showForgotPasswordDialog,
                        child: const Text('Forgot Password?', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 20),
                  ],

                  // Primary Submit Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isLoading ? null : _handleAuth,
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(
                            _isSignUp ? 'Sign Up' : 'Sign In',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),

                  // Biometric Unlock (Only when already configured)
                  if (!_isSignUp && security.isBiometricsEnabled) ...[
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(child: Divider(color: borderColor)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('OR', style: TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        Expanded(child: Divider(color: borderColor)),
                      ],
                    ),
                    const SizedBox(height: 18),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isLoading ? null : _handleBiometricLogin,
                      icon: const Icon(Icons.fingerprint, size: 22),
                      label: const Text(
                        'Unlock with Biometrics',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
