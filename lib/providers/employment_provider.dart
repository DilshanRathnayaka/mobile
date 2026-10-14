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
    bool hasFixedAllowanceDuringProbation = true,
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
      hasFixedAllowanceDuringProbation: hasFixedAllowanceDuringProbation,
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
    bool hasFixedAllowanceDuringProbation = true,
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
      hasFixedAllowanceDuringProbation: hasFixedAllowanceDuringProbation,
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

  /// Adds a new promotion / salary increment to an employment record
  Future<bool> addPromotion({
    required String employmentId,
    required String designation,
    required double basicSalary,
    double fixedAllowance = 0.0,
    required DateTime effectiveDate,
    String notes = '',
  }) async {
    final list = state.valueOrNull;
    if (list == null) return false;
    final empIdx = list.indexWhere((e) => e.id == employmentId);
    if (empIdx == -1) return false;

    final emp = list[empIdx];
    final newPromotion = PromotionModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      designation: designation.trim(),
      basicSalary: basicSalary,
      fixedAllowance: fixedAllowance,
      effectiveDate: effectiveDate,
      notes: notes.trim(),
    );

    final updatedPromotions = [...emp.promotions, newPromotion];
    final updatedEmp = emp.copyWith(promotions: updatedPromotions);

    final success = await _service.saveEmploymentPromotions(employment: updatedEmp);
    if (success) {
      await refresh();
    }
    return success;
  }

  /// Deletes a promotion by its ID
  Future<bool> deletePromotion({
    required String employmentId,
    required String promotionId,
  }) async {
    final list = state.valueOrNull;
    if (list == null) return false;
    final empIdx = list.indexWhere((e) => e.id == employmentId);
    if (empIdx == -1) return false;

    final emp = list[empIdx];
    final updatedPromotions = emp.promotions.where((p) => p.id != promotionId).toList();
    final updatedEmp = emp.copyWith(promotions: updatedPromotions);

    final success = await _service.saveEmploymentPromotions(employment: updatedEmp);
    if (success) {
      await refresh();
    }
    return success;
  }

  /// Updates an existing promotion
  Future<bool> updatePromotion({
    required String employmentId,
    required PromotionModel promotion,
  }) async {
    final list = state.valueOrNull;
    if (list == null) return false;
    final empIdx = list.indexWhere((e) => e.id == employmentId);
    if (empIdx == -1) return false;

    final emp = list[empIdx];
    final updatedPromotions =
        emp.promotions.map((p) => p.id == promotion.id ? promotion : p).toList();
    final updatedEmp = emp.copyWith(promotions: updatedPromotions);

    final success = await _service.saveEmploymentPromotions(employment: updatedEmp);
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
    final res = await _service.processMonthlySalaryForSupabase(yearMonth: yearMonth);
    if (res != null) {
      await refresh();
    }
    return res;
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
