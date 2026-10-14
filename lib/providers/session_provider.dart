import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/mfa_status_model.dart';
import 'bank_budget_provider.dart';
import 'cashflow_provider.dart';
import 'employment_provider.dart';
import 'portfolio_provider.dart';

/// Provider for current user's Supabase MFA state
final mfaStatusProvider = FutureProvider.autoDispose<MfaStatusModel>((ref) async {
  final supabase = ref.watch(supabaseServiceProvider);
  return await supabase.getMfaStatus();
});

/// Completely purges any legacy un-scoped financial data from local storage
Future<void> purgeLegacyFinancialLocalStorage() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('local_bank_account_data');
    await prefs.remove('local_cash_records_data');
    await prefs.remove('local_budget_plan_data');
    await prefs.remove('user_cashflow_records');
    await prefs.remove('dismissed_auto_salary_months');
  } catch (_) {}
}

/// Safely resets all account-specific caches and providers on sign out / account switch
void resetUserSessionState(WidgetRef ref) {
  purgeLegacyFinancialLocalStorage();
  ref.invalidate(portfolioSummaryProvider);
  ref.invalidate(transactionsProvider);
  ref.invalidate(salaryReportProvider);
  ref.invalidate(cashflowProvider);
  ref.invalidate(employmentListProvider);
  ref.invalidate(bankBudgetProvider);
  ref.invalidate(mfaStatusProvider);
}

void resetUserSessionStateWithRef(Ref ref) {
  purgeLegacyFinancialLocalStorage();
  ref.invalidate(portfolioSummaryProvider);
  ref.invalidate(transactionsProvider);
  ref.invalidate(salaryReportProvider);
  ref.invalidate(cashflowProvider);
  ref.invalidate(employmentListProvider);
  ref.invalidate(bankBudgetProvider);
  ref.invalidate(mfaStatusProvider);
}
