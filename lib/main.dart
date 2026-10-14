import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/app_backend_config.dart';
import 'core/constants/supabase_config.dart';
import 'core/storage/secure_local_storage.dart';
import 'core/theme/app_theme.dart';
import 'data/services/spring_boot_service.dart';
import 'providers/security_provider.dart';
import 'providers/session_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/auth/app_unlock_screen.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await purgeLegacyFinancialLocalStorage();

  if (AppBackendConfig.isSpringBoot) {
    debugPrint('[AppBackendConfig] Active Backend: SPRING BOOT (${AppBackendConfig.springBootBaseUrl})');
    final sbService = SpringBootService();
    await sbService.init();
  } else if (SupabaseConfig.isConfigured) {
    debugPrint('[AppBackendConfig] Active Backend: SUPABASE (${SupabaseConfig.supabaseUrl})');
    try {
      await Supabase.initialize(
        url: SupabaseConfig.supabaseUrl,
        // ignore: deprecated_member_use
        anonKey: SupabaseConfig.supabaseAnonKey,
        authOptions: FlutterAuthClientOptions(
          localStorage: SecureLocalStorage(),
        ),
      );
    } catch (e) {
      debugPrint('[Supabase] Init error: $e');
    }
  }

  runApp(
    const ProviderScope(
      child: CryptoAssetManagerApp(),
    ),
  );
}

class CryptoAssetManagerApp extends ConsumerStatefulWidget {
  const CryptoAssetManagerApp({super.key});

  @override
  ConsumerState<CryptoAssetManagerApp> createState() => _CryptoAssetManagerAppState();
}

class _CryptoAssetManagerAppState extends ConsumerState<CryptoAssetManagerApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Listen to Supabase auth state transitions only when Supabase is active
    if (AppBackendConfig.isSupabase && SupabaseConfig.isConfigured) {
      try {
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
          if (data.event == AuthChangeEvent.signedOut) {
            resetUserSessionState(ref);
          }
        });
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      ref.read(securityProvider.notifier).onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      ref.read(securityProvider.notifier).onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Crypto Asset Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final security = ref.watch(securityProvider);

    bool isAuthenticated = false;
    try {
      if (SupabaseConfig.isConfigured) {
        isAuthenticated = Supabase.instance.client.auth.currentUser != null;
      }
    } catch (_) {}

    if (!isAuthenticated) {
      return const AuthScreen();
    }

    if (security.isAppLocked) {
      return const AppUnlockScreen();
    }

    return const MainScreen();
  }
}
