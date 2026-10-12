import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Keychain / Keystore backed LocalStorage adapter for Supabase Flutter SDK.
/// Performs safe one-time migration of legacy plaintext sessions.
class SecureLocalStorage extends LocalStorage {
  final FlutterSecureStorage _storage;
  static const _migrationKey = 'sb_session_migrated_to_secure_v1';
  static const _persistedSessionKey = 'supabase.auth.token';

  SecureLocalStorage()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(),
          iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
        );

  @override
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final migrated = prefs.getBool(_migrationKey) ?? false;
      if (!migrated) {
        // Look for legacy session key
        for (final k in prefs.getKeys()) {
          if (k.startsWith('sb-') || k.contains('auth-token') || k == _persistedSessionKey) {
            final oldVal = prefs.getString(k);
            if (oldVal != null && oldVal.isNotEmpty) {
              await _storage.write(key: _persistedSessionKey, value: oldVal);
              await prefs.remove(k);
            }
          }
        }
        await prefs.setBool(_migrationKey, true);
      }
    } catch (e) {
      debugPrint('[SecureLocalStorage] Migration notice: $e');
    }
  }

  @override
  Future<bool> hasAccessToken() async {
    try {
      final token = await _storage.read(key: _persistedSessionKey);
      return token != null && token.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> accessToken() async {
    try {
      return await _storage.read(key: _persistedSessionKey);
    } catch (e) {
      debugPrint('[SecureLocalStorage] Read session error: $e');
      return null;
    }
  }

  @override
  Future<void> removePersistedSession() async {
    try {
      await _storage.delete(key: _persistedSessionKey);
    } catch (e) {
      debugPrint('[SecureLocalStorage] Remove session error: $e');
    }
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    try {
      await _storage.write(key: _persistedSessionKey, value: persistSessionString);
    } catch (e) {
      debugPrint('[SecureLocalStorage] Persist session error: $e');
    }
  }
}
