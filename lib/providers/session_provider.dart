import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/mfa_status_model.dart';
import 'cashflow_provider.dart';
import 'employment_provider.dart';
import 'portfolio_provider.dart';

/// Provider for current user's Supabase MFA state
final mfaStatusProvider = FutureProvider.autoDispose<MfaStatusModel>((ref) async {
  final supabase = ref.watch(supabaseServiceProvider);
  return await supabase.getMfaStatus();
});

/// Safely resets all account-specific caches and providers on sign out
void resetUserSessionState(WidgetRef ref) {
  ref.invalidate(portfolioSummaryProvider);
  ref.invalidate(transactionsProvider);
  ref.invalidate(salaryReportProvider);
  ref.invalidate(cashflowProvider);
  ref.invalidate(employmentListProvider);
  ref.invalidate(mfaStatusProvider);
}

void resetUserSessionStateWithRef(Ref ref) {
  ref.invalidate(portfolioSummaryProvider);
  ref.invalidate(transactionsProvider);
  ref.invalidate(salaryReportProvider);
  ref.invalidate(cashflowProvider);
  ref.invalidate(employmentListProvider);
  ref.invalidate(mfaStatusProvider);
}
