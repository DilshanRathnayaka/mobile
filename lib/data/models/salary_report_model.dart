class SalaryAllocationItem {
  final String yearMonth;
  final double salaryAmount;
  final double allocatedAmount;
  final double allocationPercentage;
  final String notes;
  final String originalCurrency;
  final double? originalSalaryAmount;
  final double? originalAllocatedAmount;
  final double fxToBase;

  SalaryAllocationItem({
    required this.yearMonth,
    required this.salaryAmount,
    required this.allocatedAmount,
    required this.allocationPercentage,
    required this.notes,
    this.originalCurrency = 'USD',
    this.originalSalaryAmount,
    this.originalAllocatedAmount,
    this.fxToBase = 1.0,
  });

  factory SalaryAllocationItem.fromJson(Map<String, dynamic> json) {
    return SalaryAllocationItem(
      yearMonth: json['yearMonth'] ?? json['year_month'] ?? '',
      salaryAmount: (json['salaryAmount'] ?? json['salary_amount'] as num?)?.toDouble() ?? 0.0,
      allocatedAmount: (json['allocatedAmount'] ?? json['allocated_amount'] as num?)?.toDouble() ?? 0.0,
      allocationPercentage: (json['allocationPercentage'] ?? json['allocation_percentage'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'] ?? '',
      originalCurrency: json['originalCurrency'] ?? json['original_currency'] ?? 'USD',
      originalSalaryAmount: (json['originalSalaryAmount'] ?? json['original_salary_amount'] as num?)?.toDouble(),
      originalAllocatedAmount: (json['originalAllocatedAmount'] ?? json['original_allocated_amount'] as num?)?.toDouble(),
      fxToBase: (json['fxToBase'] ?? json['fx_to_base'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

class SalaryReportModel {
  final double userSalary;
  final double targetAllocationPercent;
  final double totalDepositedToCrypto;
  final List<SalaryAllocationItem> allocations;

  SalaryReportModel({
    required this.userSalary,
    required this.targetAllocationPercent,
    required this.totalDepositedToCrypto,
    required this.allocations,
  });

  factory SalaryReportModel.fromJson(Map<String, dynamic> json) {
    return SalaryReportModel(
      userSalary: (json['userSalary'] ?? json['user_salary'] as num?)?.toDouble() ?? 0.0,
      targetAllocationPercent: (json['targetAllocationPercent'] ?? json['target_allocation_percent'] as num?)?.toDouble() ?? 10.0,
      totalDepositedToCrypto: (json['totalDepositedToCrypto'] ?? json['total_deposited_to_crypto'] as num?)?.toDouble() ?? 0.0,
      allocations: (json['allocations'] as List<dynamic>? ?? [])
          .map((a) => SalaryAllocationItem.fromJson(a))
          .toList(),
    );
  }

  factory SalaryReportModel.empty() {
    return SalaryReportModel(
      userSalary: 0,
      targetAllocationPercent: 10,
      totalDepositedToCrypto: 0,
      allocations: [],
    );
  }
}
