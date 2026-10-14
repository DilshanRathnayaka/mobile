import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_backend_config.dart';
import '../data/models/employment_model.dart';
import '../data/services/supabase_service.dart';
import 'portfolio_provider.dart';

final employmentListProvider =
    StateNotifierProvider<EmploymentNotifier, AsyncValue<List<EmploymentModel>>>((ref) {
  final service = ref.watch(supabaseServiceProvider);
  return EmploymentNotifier(service);
});

class EmploymentNotifier extends StateNotifier<AsyncValue<List<EmploymentModel>>> {
  final SupabaseService _service;

  EmploymentNotifier(this._service) : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final list = await _service.getEmployments();
      state = AsyncValue.data(list);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<bool> addEmployment({
    required String companyName,
    required String designation,
    double basicSalary = 0.0,
    double fixedAllowance = 0.0,
    double? monthlySalary,
    int salaryDay = 25,
    required DateTime startDate,
    DateTime? endDate,
    bool isCurrent = true,
    String notes = '',
    String currency = 'LKR',
    bool isProbation = false,
    int probationMonths = 3,
    DateTime? probationEndDate,
    bool hasEpfEtfDuringProbation = true,
  }) async {
    final newItem = await _service.addEmployment(
      companyName: companyName,
      designation: designation,
      basicSalary: basicSalary,
      fixedAllowance: fixedAllowance,
      monthlySalary: monthlySalary,
      salaryDay: salaryDay,
      startDate: startDate,
      endDate: endDate,
      isCurrent: isCurrent,
      notes: notes,
      currency: currency,
      isProbation: isProbation,
      probationMonths: probationMonths,
      probationEndDate: probationEndDate,
      hasEpfEtfDuringProbation: hasEpfEtfDuringProbation,
    );

    if (newItem != null) {
      await refresh();
      return true;
    }
    return false;
  }

  Future<bool> updateEmployment({
    required String id,
    required String companyName,
    required String designation,
    double basicSalary = 0.0,
    double fixedAllowance = 0.0,
    double? monthlySalary,
    required int salaryDay,
    required DateTime startDate,
    DateTime? endDate,
    required bool isCurrent,
    String notes = '',
    String currency = 'LKR',
    bool isProbation = false,
    int probationMonths = 3,
    DateTime? probationEndDate,
    bool hasEpfEtfDuringProbation = true,
  }) async {
    final success = await _service.updateEmployment(
      id: id,
      companyName: companyName,
      designation: designation,
      basicSalary: basicSalary,
      fixedAllowance: fixedAllowance,
      monthlySalary: monthlySalary,
      salaryDay: salaryDay,
      startDate: startDate,
      endDate: endDate,
      isCurrent: isCurrent,
      notes: notes,
      currency: currency,
      isProbation: isProbation,
      probationMonths: probationMonths,
      probationEndDate: probationEndDate,
      hasEpfEtfDuringProbation: hasEpfEtfDuringProbation,
    );

    if (success) {
      await refresh();
    }
    return success;
  }

  Future<bool> markResigned({
    required String id,
    required DateTime resignationDate,
  }) async {
    final success = await _service.markJobResigned(
      id: id,
      resignationDate: resignationDate,
    );

    if (success) {
      await refresh();
    }
    return success;
  }

  Future<bool> deleteEmployment(String id) async {
    final success = await _service.deleteEmployment(id);
    if (success) {
      await refresh();
    }
    return success;
  }

  /// Triggers backend monthly salary processing (probation, EPF/ETF, bank credit, DCA)
  Future<Map<String, dynamic>?> processMonthlySalary({String? yearMonth}) async {
    if (AppBackendConfig.isSpringBoot) {
      final res = await _service.springBootService.triggerMonthlySalaryProcessing(yearMonth: yearMonth);
      if (res != null) {
        await refresh();
      }
      return res;
    }
    return null;
  }
}

/// Derived Career Summary Provider (Aggregates EPF, ETF, and Lifetime Earnings)
final careerSummaryProvider = Provider<CareerSummary>((ref) {
  final asyncEmployments = ref.watch(employmentListProvider);
  return asyncEmployments.when(
    data: (list) => CareerSummary.fromEmployments(list),
    loading: () => CareerSummary.empty(),
    error: (err, stack) => CareerSummary.empty(),
  );
});
