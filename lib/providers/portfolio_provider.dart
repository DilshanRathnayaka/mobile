import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/portfolio_summary_model.dart';
import '../data/models/transaction_model.dart';
import '../data/models/salary_report_model.dart';
import '../data/services/supabase_service.dart';

final supabaseServiceProvider = Provider<SupabaseService>((ref) => SupabaseService());

// Balance visibility toggle (e.g. $5,850 vs ****)
final isBalanceHiddenProvider = StateProvider<bool>((ref) => false);

// Portfolio Summary Provider
final portfolioSummaryProvider =
    StateNotifierProvider<PortfolioNotifier, AsyncValue<PortfolioSummaryModel>>((ref) {
  return PortfolioNotifier(ref.watch(supabaseServiceProvider));
});

class PortfolioNotifier extends StateNotifier<AsyncValue<PortfolioSummaryModel>> {
  final SupabaseService _service;

  PortfolioNotifier(this._service) : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final summary = await _service.getPortfolioSummary();
      state = AsyncValue.data(summary);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

// Transactions Provider
final transactionsProvider =
    StateNotifierProvider<TransactionsNotifier, AsyncValue<List<TransactionModel>>>((ref) {
  return TransactionsNotifier(ref.watch(supabaseServiceProvider), ref);
});

class TransactionsNotifier extends StateNotifier<AsyncValue<List<TransactionModel>>> {
  final SupabaseService _service;
  final Ref _ref;

  TransactionsNotifier(this._service, this._ref) : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final list = await _service.getTransactions();
      state = AsyncValue.data(list);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<bool> addTransaction(Map<String, dynamic> data) async {
    final success = await _service.createTransaction(data);
    if (success) {
      await refresh();
      _ref.read(portfolioSummaryProvider.notifier).refresh();
    }
    return success;
  }

  Future<bool> updateTransaction(String id, Map<String, dynamic> data) async {
    final success = await _service.updateTransaction(id, data);
    if (success) {
      await refresh();
      _ref.read(portfolioSummaryProvider.notifier).refresh();
    }
    return success;
  }

  Future<bool> deleteTransaction(String id) async {
    final success = await _service.deleteTransaction(id);
    if (success) {
      await refresh();
      _ref.read(portfolioSummaryProvider.notifier).refresh();
    }
    return success;
  }
}

// Salary Report Provider
final salaryReportProvider =
    StateNotifierProvider<SalaryReportNotifier, AsyncValue<SalaryReportModel>>((ref) {
  return SalaryReportNotifier(ref.watch(supabaseServiceProvider), ref);
});

class SalaryReportNotifier extends StateNotifier<AsyncValue<SalaryReportModel>> {
  final SupabaseService _service;
  final Ref _ref;

  SalaryReportNotifier(this._service, this._ref) : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final report = await _service.getSalaryReport();
      state = AsyncValue.data(report);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<bool> saveAllocation(Map<String, dynamic> data) async {
    final success = await _service.saveSalaryAllocation(data);
    if (success) {
      await refresh();
      _ref.read(transactionsProvider.notifier).refresh();
      _ref.read(portfolioSummaryProvider.notifier).refresh();
    }
    return success;
  }

  Future<bool> deleteAllocation(String yearMonth) async {
    final success = await _service.deleteSalaryAllocation(yearMonth);
    if (success) {
      await refresh();
      _ref.read(transactionsProvider.notifier).refresh();
      _ref.read(portfolioSummaryProvider.notifier).refresh();
    }
    return success;
  }
}
