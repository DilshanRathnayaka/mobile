import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecuritySettings {
  final bool isBiometricsEnabled;
  final bool isAppLocked;
  final DateTime? lastBackgroundedTime;

  const SecuritySettings({
    required this.isBiometricsEnabled,
    this.isAppLocked = false,
    this.lastBackgroundedTime,
  });

  SecuritySettings copyWith({
    bool? isBiometricsEnabled,
    bool? isAppLocked,
    DateTime? lastBackgroundedTime,
  }) {
    return SecuritySettings(
      isBiometricsEnabled: isBiometricsEnabled ?? this.isBiometricsEnabled,
      isAppLocked: isAppLocked ?? this.isAppLocked,
      lastBackgroundedTime: lastBackgroundedTime ?? this.lastBackgroundedTime,
    );
  }
}

final securityProvider = StateNotifierProvider<SecurityNotifier, SecuritySettings>((ref) {
  return SecurityNotifier();
});

class SecurityNotifier extends StateNotifier<SecuritySettings> {
  static const _biometricKey = 'sec_biometrics_enabled_v2';
  static const int lockTimeoutSeconds = 30;

  final LocalAuthentication _localAuth = LocalAuthentication();

  SecurityNotifier()
      : super(const SecuritySettings(
          isBiometricsEnabled: false,
          isAppLocked: false,
        )) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bioEnabled = prefs.getBool(_biometricKey) ?? false;
      state = state.copyWith(
        isBiometricsEnabled: bioEnabled,
        // If biometrics is enabled, cold launch requires unlock
        isAppLocked: bioEnabled,
      );
    } catch (_) {}
  }

  Future<String?> toggleBiometrics(bool enabled) async {
    if (enabled) {
      // Must successfully verify Face ID / biometrics before enabling
      final (success, errorMsg) = await authenticateWithBiometricsDetailed(
        reason: 'Authenticate with Face ID or biometrics to enable app lock',
      );
      if (!success) {
        return errorMsg ?? 'Biometric authentication was cancelled or not recognized.';
      }
    }
    state = state.copyWith(isBiometricsEnabled: enabled, isAppLocked: false);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_biometricKey, enabled);
    } catch (_) {}
    return null;
  }

  /// Called when the app moves to the background
  void onAppPaused() {
    if (state.isBiometricsEnabled) {
      state = state.copyWith(lastBackgroundedTime: DateTime.now());
    }
  }

  /// Called when the app resumes. Checks 30s timeout and locks if exceeded.
  void onAppResumed() {
    if (state.isBiometricsEnabled && state.lastBackgroundedTime != null) {
      final diff = DateTime.now().difference(state.lastBackgroundedTime!);
      if (diff.inSeconds >= lockTimeoutSeconds) {
        state = state.copyWith(isAppLocked: true);
      }
    }
  }

  /// Detailed biometric authentication returning status and human-readable error message.
  Future<(bool, String?)> authenticateWithBiometricsDetailed({
    String reason = 'Authenticate to access Asset Manager',
  }) async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();

      if (!canCheck && !isSupported) {
        return (false, 'This device does not support biometric or Face ID authentication.');
      }

      final success = await _localAuth.authenticate(
        localizedReason: reason,
        biometricOnly: false, // Critical: permits Face Unlock (Class 2/3) and device credentials
        persistAcrossBackgrounding: true,
      );

      if (success) {
        return (true, null);
      } else {
        return (false, 'Biometric verification failed or was cancelled.');
      }
    } on LocalAuthException catch (e) {
      debugPrint('[SecurityNotifier] LocalAuthException: ${e.code} - ${e.description}');
      switch (e.code) {
        case LocalAuthExceptionCode.noCredentialsSet:
        case LocalAuthExceptionCode.noBiometricsEnrolled:
          return (false, 'No Face ID or screen lock enrolled. Please set up Face ID or PIN in phone settings.');
        case LocalAuthExceptionCode.temporaryLockout:
        case LocalAuthExceptionCode.biometricLockout:
          return (false, 'Biometrics temporarily locked due to failed attempts.');
        case LocalAuthExceptionCode.noBiometricHardware:
          return (false, 'This device does not have biometric hardware.');
        case LocalAuthExceptionCode.userCanceled:
          return (false, 'Authentication cancelled.');
        default:
          return (false, e.description ?? 'Biometric authentication failed.');
      }
    } catch (e) {
      debugPrint('[SecurityNotifier] Biometric error: $e');
      return (false, 'Authentication failed: $e');
    }
  }

  /// Attempts native biometrics / Face ID prompt. STRICTLY FAILS CLOSED.
  Future<bool> authenticateWithBiometrics({
    String reason = 'Authenticate with Face ID or biometrics to unlock Asset Manager',
  }) async {
    final (success, _) = await authenticateWithBiometricsDetailed(reason: reason);
    return success;
  }

  /// Unlocks the app after verified biometric challenge
  Future<bool> unlockApp() async {
    if (!state.isAppLocked) return true;
    final success = await authenticateWithBiometrics();
    if (success) {
      state = state.copyWith(isAppLocked: false, lastBackgroundedTime: null);
      return true;
    }
    return false;
  }
}
