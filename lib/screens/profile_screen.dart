import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_colors.dart';
import '../providers/currency_provider.dart';
import '../providers/portfolio_provider.dart';
import '../providers/security_provider.dart';
import '../providers/session_provider.dart';
import '../providers/theme_provider.dart';
import 'auth/auth_screen.dart';
import '../widgets/skeleton_loading.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supabaseService = ref.watch(supabaseServiceProvider);
    final user = supabaseService.currentUser;
    final selectedCurrency = ref.watch(currencyProvider);
    final security = ref.watch(securityProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final mfaStatusAsync = ref.watch(mfaStatusProvider);

    final bgColor = AppColors.background(context);
    final surfaceColor = AppColors.surface(context);
    final surfaceLight = AppColors.surfaceLight(context);
    final borderColor = AppColors.border(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final textMuted = AppColors.textMuted(context);

    final email = user?.email ?? 'trader@assetmanager.app';

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text(
          'Account & Security Settings',
          style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. User Identity Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF16161B), const Color(0xFF0F0F13)]
                    : [const Color(0xFFFFFFFF), const Color(0xFFF9F9FC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? AppColors.primary.withAlpha(50) : borderColor),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.primaryGlow,
                  child: Text(
                    email.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              email,
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.verified, color: AppColors.profit, size: 16),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Secured with Supabase Cloud Auth',
                        style: TextStyle(color: textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 2. Base Currency Preference
          _sectionHeader('CURRENCY & VALUATION', textMuted),
          Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryGlow,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.currency_exchange, color: AppColors.primary, size: 20),
              ),
              title: Text('Primary Display Currency', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text(
                '${selectedCurrency.name} (${selectedCurrency.code}) - Rate: 1 USDT = ${selectedCurrency.rateToUsd} ${selectedCurrency.code}',
                style: TextStyle(color: textSecondary, fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () => _showCurrencyPickerModal(context, ref),
            ),
          ),
          const SizedBox(height: 24),

          // 3. Institutional Security & MFA
          _sectionHeader('SECURITY & AUTHENTICATION', textMuted),
          Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                // Real Google Authenticator TOTP Factor
                mfaStatusAsync.when(
                  loading: () => const ShimmerEffect(
                    child: ListTile(
                      leading: SkeletonBox(width: 40, height: 40, borderRadius: 10),
                      title: SkeletonBox(width: 140, height: 14),
                      subtitle: Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: SkeletonBox(width: 200, height: 10),
                      ),
                    ),
                  ),
                  error: (e, _) => ListTile(
                    leading: const Icon(Icons.error_outline, color: AppColors.loss),
                    title: const Text('2FA Status Unavailable'),
                    subtitle: Text('$e', style: const TextStyle(fontSize: 11)),
                  ),
                  data: (mfa) {
                    final isEnrolled = mfa.isEnrolled;
                    return Column(
                      children: [
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isEnrolled ? AppColors.profit.withAlpha(30) : AppColors.primaryGlow,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.security, color: isEnrolled ? AppColors.profit : AppColors.primary, size: 20),
                          ),
                          title: Text('Google Authenticator (2FA)', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text(
                            isEnrolled
                                ? 'Enrolled & Active (AAL2 Assurance Required)'
                                : 'Protect financial writes with 6-digit TOTP codes',
                            style: TextStyle(color: isEnrolled ? AppColors.profit : textSecondary, fontSize: 12),
                          ),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isEnrolled ? surfaceLight : AppColors.primary,
                              foregroundColor: isEnrolled ? textPrimary : Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () {
                              if (isEnrolled) {
                                _showUnenrollMfaModal(context, ref, mfa.primaryTotpFactor!.id);
                              } else {
                                _showEnrollMfaModal(context, ref);
                              }
                            },
                            child: Text(
                              isEnrolled ? 'Manage' : 'Setup 2FA',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                Divider(color: borderColor, height: 1),

                // Biometrics / Face ID Lock (Local Device-Level Protection)
                SwitchListTile(
                  activeThumbColor: AppColors.primary,
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGlow,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.fingerprint, color: AppColors.primary, size: 20),
                  ),
                  title: Text('Biometric / Face ID App Lock', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text(
                    'Locks app when closed or in background for >30 seconds',
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                  value: security.isBiometricsEnabled,
                  onChanged: (val) async {
                    final messenger = ScaffoldMessenger.of(context);
                    final errorMsg = await ref.read(securityProvider.notifier).toggleBiometrics(val);
                    if (!context.mounted) return;
                    if (errorMsg != null) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(errorMsg),
                          backgroundColor: AppColors.loss,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    } else if (val) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Face ID / Biometric Lock enabled successfully!'),
                          backgroundColor: AppColors.profit,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 4. App Preferences & Theme
          _sectionHeader('PREFERENCES & THEME', textMuted),
          Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  activeThumbColor: AppColors.primary,
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGlow,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(isDark ? Icons.dark_mode : Icons.light_mode, color: AppColors.primary, size: 20),
                  ),
                  title: Text('Dark Terminal Mode', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text(isDark ? 'Obsidian Black Terminal' : 'High-End Slate White', style: TextStyle(color: textSecondary, fontSize: 12)),
                  value: isDark,
                  onChanged: (_) => ref.read(themeModeProvider.notifier).toggleTheme(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // 5. Sign Out Button (With Complete Cache Invalidation)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.loss.withAlpha(30),
              foregroundColor: AppColors.loss,
              side: const BorderSide(color: AppColors.loss, width: 1),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: surfaceColor,
                  title: Text('Sign Out', style: TextStyle(color: textPrimary)),
                  content: Text('Are you sure you want to sign out? Cached financial records will be wiped from this device.',
                      style: TextStyle(color: textSecondary)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: textSecondary))),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.loss),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Log Out', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );

              if (confirm == true && context.mounted) {
                // Wipe all user providers from memory
                resetUserSessionState(ref);
                await ref.read(supabaseServiceProvider).signOut();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const AuthScreen()),
                    (route) => false,
                  );
                }
              }
            },
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Sign Out of Account', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  // Real Supabase MFA Enrollment Modal
  void _showEnrollMfaModal(BuildContext context, WidgetRef ref) async {
    final surfaceColor = AppColors.surface(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final codeCtrl = TextEditingController();

    try {
      final supabase = ref.read(supabaseServiceProvider);
      final enrollRes = await supabase.enrollMfaTotp();
      final secret = enrollRes.totp?.secret ?? '';

      if (!context.mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: surfaceColor,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setModalState) => Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Enroll Google Authenticator', style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '1. Copy this setup key and add it to your Google Authenticator app:',
                  style: TextStyle(color: textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight(context),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary.withAlpha(80)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          secret,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18, color: AppColors.primary),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: secret));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Setup key copied to clipboard!'), duration: Duration(seconds: 2)),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text('2. Enter the 6-digit code generated by Google Authenticator:', style: TextStyle(color: textSecondary, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: codeCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: TextStyle(color: textPrimary, fontSize: 18, letterSpacing: 6, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.surfaceLight(context),
                    hintText: '123456',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    final code = codeCtrl.text.trim();
                    if (code.length != 6) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter valid 6-digit code'), backgroundColor: AppColors.loss),
                      );
                      return;
                    }

                    try {
                      await supabase.challengeAndVerifyMfaTotp(factorId: enrollRes.id, code: code);
                      ref.invalidate(mfaStatusProvider);
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Google Authenticator 2FA Activated!'), backgroundColor: AppColors.profit),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Verification rejected: $e'), backgroundColor: AppColors.loss),
                        );
                      }
                    }
                  },
                  child: const Text('Verify & Activate 2FA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('MFA Enrollment error: $e'), backgroundColor: AppColors.loss),
        );
      }
    }
  }

  // Manage / Unenroll MFA Modal
  void _showUnenrollMfaModal(BuildContext context, WidgetRef ref, String factorId) {
    final surfaceColor = AppColors.surface(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: surfaceColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Manage 2FA Factor', style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('Google Authenticator is currently protecting your financial account.', style: TextStyle(color: textSecondary, fontSize: 13)),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.loss,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await ref.read(supabaseServiceProvider).unenrollMfaTotp(factorId);
                  ref.invalidate(mfaStatusProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('2FA factor unenrolled'), backgroundColor: AppColors.profit),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.loss),
                    );
                  }
                }
              },
              child: const Text('Unenroll Authenticator Factor', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // Currency Picker Modal
  void _showCurrencyPickerModal(BuildContext context, WidgetRef ref) {
    final surfaceColor = AppColors.surface(context);
    final textPrimary = AppColors.textPrimary(context);
    final borderColor = AppColors.border(context);
    final selected = ref.read(currencyProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: surfaceColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Select Display Currency',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Divider(color: borderColor, height: 16),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
                  itemCount: SupportedCurrencies.all.length,
                  separatorBuilder: (context, index) => Divider(color: borderColor.withAlpha(80), height: 1),
                  itemBuilder: (context, index) {
                    final c = SupportedCurrencies.all[index];
                    final isSelected = c.code == selected.code;
                    final isUsdt = c.code == 'USDT';

                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isUsdt ? const Color(0xFF26A17B).withAlpha(18) : AppColors.primary.withAlpha(18))
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isUsdt ? const Color(0xFF26A17B) : AppColors.primary)
                                : (isUsdt ? const Color(0xFF26A17B).withAlpha(25) : AppColors.surfaceLight(context)),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? (isUsdt ? const Color(0xFF26A17B) : AppColors.primary)
                                  : (isUsdt ? const Color(0xFF26A17B).withAlpha(80) : borderColor),
                              width: 1.2,
                            ),
                          ),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  isUsdt ? '₮' : c.symbol.trim(),
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : (isUsdt ? const Color(0xFF26A17B) : textPrimary),
                                    fontSize: isUsdt ? 20 : 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                '${c.name} (${c.code})',
                                style: TextStyle(
                                  color: textPrimary,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                  fontSize: 14.5,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isUsdt) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF26A17B).withAlpha(25),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFF26A17B).withAlpha(100), width: 0.8),
                                ),
                                child: const Text(
                                  'BASE STABLECOIN',
                                  style: TextStyle(
                                    color: Color(0xFF26A17B),
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            isUsdt
                                ? 'Pegged 1:1 with USD • Primary Base Currency'
                                : 'Base Rate: 1 USD ≈ ${c.rateToUsd} ${c.code}',
                            style: TextStyle(
                              color: isUsdt ? const Color(0xFF26A17B) : AppColors.textSecondary(context),
                              fontSize: 11,
                              fontWeight: isUsdt ? FontWeight.w500 : FontWeight.normal,
                            ),
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_circle_rounded, color: isUsdt ? const Color(0xFF26A17B) : AppColors.primary, size: 20)
                            : null,
                        onTap: () {
                          ref.read(currencyProvider.notifier).setCurrency(c);
                          Navigator.pop(ctx);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
