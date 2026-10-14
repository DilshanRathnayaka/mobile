
enum BackendType { supabase, springBoot }

class AppBackendConfig {
  /// Defines active backend: 'SUPABASE' or 'SPRING_BOOT'
  /// Can be set at build/run time via:
  ///   flutter run --dart-define=BACKEND_TYPE=SPRING_BOOT
  ///   flutter run --dart-define=BACKEND_TYPE=SUPABASE
  /// Or changed by modifying `_configuredBackend` below.
  static const String _envBackend = String.fromEnvironment(
    'BACKEND_TYPE',
    defaultValue: '',
  );

  // Default fallback backend when no --dart-define is specified.
  // Set to BackendType.springBoot to connect to the Spring Boot backend
  static const BackendType _configuredBackend = BackendType.springBoot;

  /// Custom override for runtime switching (e.g. settings screen or dev mode)
  static BackendType? _runtimeOverride;

  static BackendType get activeBackend {
    if (_runtimeOverride != null) return _runtimeOverride!;

    if (_envBackend.toUpperCase() == 'SPRING_BOOT' ||
        _envBackend.toUpperCase() == 'SPRINGBOOT') {
      return BackendType.springBoot;
    } else if (_envBackend.toUpperCase() == 'SUPABASE') {
      return BackendType.supabase;
    }

    return _configuredBackend;
  }

  static void setBackend(BackendType type) {
    _runtimeOverride = type;
  }

  static bool get isSpringBoot => activeBackend == BackendType.springBoot;
  static bool get isSupabase => activeBackend == BackendType.supabase;

  /// Base URL for the Spring Boot REST API
  /// Can be passed via: --dart-define=SPRING_BOOT_URL=https://assetmanager-api.duckdns.org/api/v1
  static const String _envSpringUrl = String.fromEnvironment(
    'SPRING_BOOT_URL',
    defaultValue: '',
  );

  static String get springBootBaseUrl {
    if (_envSpringUrl.isNotEmpty) return _envSpringUrl;

    return 'https://assetmanager-api.duckdns.org/api/v1';
  }

  static String get backendDisplayName {
    return isSpringBoot
        ? 'Spring Boot 3 (MySQL)'
        : 'Supabase Cloud (PostgreSQL)';
  }
}
