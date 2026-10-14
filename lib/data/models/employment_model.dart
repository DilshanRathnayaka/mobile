import 'dart:convert';

/// Represents a promotion or salary increment event in an employee's career
class PromotionModel {
  final String id;
  final String designation; // New role/title
  final double basicSalary; // New basic pay after promotion
  final double fixedAllowance; // New fixed allowances after promotion
  final DateTime effectiveDate; // Date the promotion takes effect
  final String notes; // Reason / remarks (e.g. "Annual appraisal promotion", "Band 4 to 5")
  final DateTime createdAt;

  PromotionModel({
    required this.id,
    required this.designation,
    required this.basicSalary,
    this.fixedAllowance = 0.0,
    required this.effectiveDate,
    this.notes = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Whether this promotion is scheduled for a future date
  bool get isUpcoming => effectiveDate.isAfter(DateTime.now());

  double get monthlySalary => basicSalary + fixedAllowance;

  Map<String, dynamic> toJson() => {
        'id': id,
        'designation': designation,
        'basic_salary': basicSalary,
        'fixed_allowance': fixedAllowance,
        'monthly_salary': monthlySalary,
        'effective_date': effectiveDate.toIso8601String().split('T').first,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
      };

  factory PromotionModel.fromJson(Map<String, dynamic> json) {
    final bSalary = (json['basic_salary'] as num?)?.toDouble() ??
        (json['basicSalary'] as num?)?.toDouble() ??
        0.0;
    final fAllowance = (json['fixed_allowance'] as num?)?.toDouble() ??
        (json['fixedAllowance'] as num?)?.toDouble() ??
        0.0;
    final effDateStr = json['effective_date']?.toString() ?? json['effectiveDate']?.toString();
    final createdStr = json['created_at']?.toString() ?? json['createdAt']?.toString();

    return PromotionModel(
      id: json['id']?.toString() ?? '',
      designation: json['designation']?.toString() ?? '',
      basicSalary: bSalary,
      fixedAllowance: fAllowance,
      effectiveDate: DateTime.tryParse(effDateStr ?? '') ?? DateTime.now(),
      notes: json['notes']?.toString() ?? '',
      createdAt: DateTime.tryParse(createdStr ?? '') ?? DateTime.now(),
    );
  }

  PromotionModel copyWith({
    String? id,
    String? designation,
    double? basicSalary,
    double? fixedAllowance,
    DateTime? effectiveDate,
    String? notes,
    DateTime? createdAt,
  }) {
    return PromotionModel(
      id: id ?? this.id,
      designation: designation ?? this.designation,
      basicSalary: basicSalary ?? this.basicSalary,
      fixedAllowance: fixedAllowance ?? this.fixedAllowance,
      effectiveDate: effectiveDate ?? this.effectiveDate,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class EmploymentModel {
  final String id;
  final String userId;
  final String companyName;
  final String designation;
  final double basicSalary;       // Basic pay on which EPF (8% emp, 12% comp) and ETF (3%) are legally calculated
  final double fixedAllowance;    // Fixed allowances (added to take-home, not subject to EPF/ETF)
  final double monthlySalary;     // Total monthly gross = basicSalary + fixedAllowance
  final int salaryDay; // 1 - 31
  final DateTime startDate; // Join date
  final DateTime? endDate; // Resignation date (null if active)
  final bool isCurrent;
  final String notes;
  final String currency;

  // 📝 Probation Period Settings
  final bool isProbation; // Whether a probation period applies
  final int probationMonths; // e.g. 3 or 6 months
  final DateTime? probationEndDate; // Optional explicit probation end date
  final bool hasEpfEtfDuringProbation; // true = EPF/ETF paid during probation; false = exempt during probation
  final bool hasFixedAllowanceDuringProbation; // true = fixed allowances received during probation; false = only after permanent confirmation

  // 🎯 Career Growth: Promotions & Salary Increments
  final List<PromotionModel> promotions;

  const EmploymentModel({
    required this.id,
    required this.userId,
    required this.companyName,
    required this.designation,
    this.basicSalary = 0.0,
    this.fixedAllowance = 0.0,
    required this.monthlySalary,
    this.salaryDay = 25,
    required this.startDate,
    this.endDate,
    this.isCurrent = true,
    this.notes = '',
    this.currency = 'LKR',
    this.isProbation = false,
    this.probationMonths = 3,
    this.probationEndDate,
    this.hasEpfEtfDuringProbation = true,
    this.hasFixedAllowanceDuringProbation = true,
    this.promotions = const [],
  });

  bool get isResigned => endDate != null || !isCurrent;

  DateTime get effectiveEndDate => endDate ?? DateTime.now();

  /// Effective probation end date
  DateTime get effectiveProbationEndDate =>
      probationEndDate ??
      DateTime(startDate.year, startDate.month + probationMonths, startDate.day);

  /// Checks if employee is currently in probation as of a specific date
  bool isInProbation([DateTime? asOfDate]) {
    if (!isProbation) return false;
    final date = asOfDate ?? DateTime.now();
    return date.isBefore(effectiveProbationEndDate);
  }

  /// Whether EPF/ETF is currently applicable
  bool isEpfApplicable([DateTime? asOfDate]) {
    if (!isInProbation(asOfDate)) return true; // Confirmed employees always have EPF/ETF
    return hasEpfEtfDuringProbation;
  }

  /// Returns the current active designation taking past promotions into account
  String get activeDesignation {
    final promo = activePromotion();
    return promo != null ? promo.designation : designation;
  }

  /// Returns the current active basic salary taking past promotions into account
  double get activeBasicSalary {
    final promo = activePromotion();
    return promo != null ? promo.basicSalary : effectiveBasicSalary;
  }

  /// Returns the current active fixed allowance taking past promotions and probation into account
  double get activeFixedAllowance {
    if (isInProbation() && !hasFixedAllowanceDuringProbation) {
      return 0.0;
    }
    final promo = activePromotion();
    return promo != null ? promo.fixedAllowance : fixedAllowance;
  }

  /// Returns the latest promotion that has taken effect as of [asOfDate] (defaults to now)
  PromotionModel? activePromotion([DateTime? asOfDate]) {
    if (promotions.isEmpty) return null;
    final target = asOfDate ?? DateTime.now();
    final effectivePromos = promotions
        .where((p) => !p.effectiveDate.isAfter(target))
        .toList()
      ..sort((a, b) => a.effectiveDate.compareTo(b.effectiveDate));
    return effectivePromos.isNotEmpty ? effectivePromos.last : null;
  }

  /// Returns all promotions sorted newest first (for UI display)
  List<PromotionModel> get sortedPromotions {
    final list = List<PromotionModel>.from(promotions);
    list.sort((a, b) => b.effectiveDate.compareTo(a.effectiveDate));
    return list;
  }

  /// Returns future scheduled promotions
  List<PromotionModel> get upcomingPromotions {
    final now = DateTime.now();
    final list = promotions.where((p) => p.effectiveDate.isAfter(now)).toList();
    list.sort((a, b) => a.effectiveDate.compareTo(b.effectiveDate));
    return list;
  }

  /// Effective fixed allowance taking probation policy into account
  double effectiveFixedAllowance([DateTime? asOfDate]) {
    if (isInProbation(asOfDate) && !hasFixedAllowanceDuringProbation) {
      return 0.0;
    }
    final promo = activePromotion(asOfDate);
    return promo != null ? promo.fixedAllowance : fixedAllowance;
  }

  /// Effective basic salary for EPF/ETF statutory deductions
  double get effectiveBasicSalary => basicSalary > 0
      ? basicSalary
      : (monthlySalary - fixedAllowance > 0 ? monthlySalary - fixedAllowance : monthlySalary);

  /// Effective total gross earnings (Basic + Fixed Allowance)
  double get effectiveGrossSalary => (basicSalary > 0 || fixedAllowance > 0 || promotions.isNotEmpty)
      ? (activeBasicSalary + activeFixedAllowance)
      : monthlySalary;

  /// Total completed or active months worked under this employment
  int get monthsWorked {
    final end = effectiveEndDate;
    if (end.isBefore(startDate)) return 0;

    int months = (end.year - startDate.year) * 12 + (end.month - startDate.month);
    if (end.day < startDate.day) {
      months -= 1;
    }
    return months < 1 ? 1 : months;
  }

  /// Total days worked
  int get daysWorked {
    final end = effectiveEndDate;
    if (end.isBefore(startDate)) return 0;
    return end.difference(startDate).inDays;
  }

  /// Friendly duration label (e.g. "2 Yrs 4 Mos" or "7 Mos")
  String get durationText {
    final days = daysWorked;
    final years = days ~/ 365;
    final remainingMonths = ((days % 365) ~/ 30);

    if (years > 0 && remainingMonths > 0) {
      return '$years ${years == 1 ? "Yr" : "Yrs"} $remainingMonths ${remainingMonths == 1 ? "Mo" : "Mos"}';
    } else if (years > 0) {
      return '$years ${years == 1 ? "Year" : "Years"}';
    } else {
      final months = monthsWorked;
      return '$months ${months == 1 ? "Month" : "Months"}';
    }
  }

  /// Sri Lankan Legal EPF & ETF Breakdown:
  /// Employee EPF: 8% (Deducted from basic pay) - 0 if during probation and not applicable
  double get monthlyEmployeeEpf8 => isEpfApplicable() ? (activeBasicSalary * 0.08) : 0.0;

  /// Employer EPF: 12% (Paid by company on basic pay) - 0 if during probation and not applicable
  double get monthlyEmployerEpf12 => isEpfApplicable() ? (activeBasicSalary * 0.12) : 0.0;

  /// Total Monthly EPF: 20% (Accumulated in CBSL Fund)
  double get monthlyTotalEpf20 => isEpfApplicable() ? (activeBasicSalary * 0.20) : 0.0;

  /// Employer ETF: 3% (Paid by company to ETF Board on basic pay)
  double get monthlyEmployerEtf3 => isEpfApplicable() ? (activeBasicSalary * 0.03) : 0.0;

  /// Net Take-Home Salary credited to bank: (Gross - 8% Employee EPF)
  /// e.g. If EPF exempt in probation: full gross. If confirmed: Gross - 8% EPF.
  double get monthlyNetSalary => effectiveGrossSalary - monthlyEmployeeEpf8;

  /// Number of probation months completed (capped at monthsWorked)
  int get completedProbationMonths {
    if (!isProbation) return 0;
    return probationMonths.clamp(0, monthsWorked);
  }

  int get confirmedMonths {
    if (!isProbation) return monthsWorked;
    return (monthsWorked - completedProbationMonths).clamp(0, monthsWorked);
  }

  /// Cumulative lifetime totals for this job
  double get lifetimeGrossEarned {
    if (promotions.isEmpty) {
      if (!isProbation) return monthsWorked * (effectiveBasicSalary + fixedAllowance);
      final probationGross = completedProbationMonths *
          (effectiveBasicSalary + (hasFixedAllowanceDuringProbation ? fixedAllowance : 0.0));
      final confirmedGross = confirmedMonths * (effectiveBasicSalary + fixedAllowance);
      return probationGross + confirmedGross;
    }

    final totalMonths = monthsWorked;
    double totalGross = 0.0;
    for (int i = 0; i < totalMonths; i++) {
      final monthDate = DateTime(startDate.year, startDate.month + i, startDate.day.clamp(1, 28));
      final inProb = isInProbation(monthDate);
      if (inProb) {
        final allow = hasFixedAllowanceDuringProbation ? fixedAllowance : 0.0;
        totalGross += (effectiveBasicSalary + allow);
      } else {
        final promo = activePromotion(monthDate);
        final bSalary = promo != null ? promo.basicSalary : effectiveBasicSalary;
        final fAllow = promo != null ? promo.fixedAllowance : fixedAllowance;
        totalGross += (bSalary + fAllow);
      }
    }
    return totalGross;
  }

  double get lifetimeEmployeeEpf {
    if (promotions.isEmpty) {
      if (hasEpfEtfDuringProbation || !isProbation) {
        return monthsWorked * (effectiveBasicSalary * 0.08);
      }
      return confirmedMonths * (effectiveBasicSalary * 0.08);
    }

    final totalMonths = monthsWorked;
    double totalEmpEpf = 0.0;
    for (int i = 0; i < totalMonths; i++) {
      final monthDate = DateTime(startDate.year, startDate.month + i, startDate.day.clamp(1, 28));
      if (isEpfApplicable(monthDate)) {
        final promo = activePromotion(monthDate);
        final bSalary = promo != null ? promo.basicSalary : effectiveBasicSalary;
        totalEmpEpf += (bSalary * 0.08);
      }
    }
    return totalEmpEpf;
  }

  double get lifetimeEmployerEpf {
    if (promotions.isEmpty) {
      if (hasEpfEtfDuringProbation || !isProbation) {
        return monthsWorked * (effectiveBasicSalary * 0.12);
      }
      return confirmedMonths * (effectiveBasicSalary * 0.12);
    }

    final totalMonths = monthsWorked;
    double totalCompEpf = 0.0;
    for (int i = 0; i < totalMonths; i++) {
      final monthDate = DateTime(startDate.year, startDate.month + i, startDate.day.clamp(1, 28));
      if (isEpfApplicable(monthDate)) {
        final promo = activePromotion(monthDate);
        final bSalary = promo != null ? promo.basicSalary : effectiveBasicSalary;
        totalCompEpf += (bSalary * 0.12);
      }
    }
    return totalCompEpf;
  }

  double get lifetimeTotalEpf => lifetimeEmployeeEpf + lifetimeEmployerEpf;

  double get lifetimeEmployerEtf {
    if (promotions.isEmpty) {
      if (hasEpfEtfDuringProbation || !isProbation) {
        return monthsWorked * (effectiveBasicSalary * 0.03);
      }
      return confirmedMonths * (effectiveBasicSalary * 0.03);
    }

    final totalMonths = monthsWorked;
    double totalEtf = 0.0;
    for (int i = 0; i < totalMonths; i++) {
      final monthDate = DateTime(startDate.year, startDate.month + i, startDate.day.clamp(1, 28));
      if (isEpfApplicable(monthDate)) {
        final promo = activePromotion(monthDate);
        final bSalary = promo != null ? promo.basicSalary : effectiveBasicSalary;
        totalEtf += (bSalary * 0.03);
      }
    }
    return totalEtf;
  }

  double get lifetimeNetSalary {
    if (promotions.isEmpty) {
      final probationGrossPerMonth =
          effectiveBasicSalary + (hasFixedAllowanceDuringProbation ? fixedAllowance : 0.0);
      final probationEmpEpfPerMonth =
          hasEpfEtfDuringProbation ? (effectiveBasicSalary * 0.08) : 0.0;
      final probationNet = completedProbationMonths * (probationGrossPerMonth - probationEmpEpfPerMonth);

      final confirmedGrossPerMonth = effectiveBasicSalary + fixedAllowance;
      final confirmedEmpEpfPerMonth = effectiveBasicSalary * 0.08;
      final confirmedNet = confirmedMonths * (confirmedGrossPerMonth - confirmedEmpEpfPerMonth);

      if (!isProbation) {
        return monthsWorked * (confirmedGrossPerMonth - confirmedEmpEpfPerMonth);
      }
      return probationNet + confirmedNet;
    }

    final totalMonths = monthsWorked;
    double totalNet = 0.0;
    for (int i = 0; i < totalMonths; i++) {
      final monthDate = DateTime(startDate.year, startDate.month + i, startDate.day.clamp(1, 28));
      final inProb = isInProbation(monthDate);

      double bSalary;
      double fAllow;
      if (inProb) {
        bSalary = effectiveBasicSalary;
        fAllow = hasFixedAllowanceDuringProbation ? fixedAllowance : 0.0;
      } else {
        final promo = activePromotion(monthDate);
        bSalary = promo != null ? promo.basicSalary : effectiveBasicSalary;
        fAllow = promo != null ? promo.fixedAllowance : fixedAllowance;
      }

      final gross = bSalary + fAllow;
      final empEpf = isEpfApplicable(monthDate) ? (bSalary * 0.08) : 0.0;
      totalNet += (gross - empEpf);
    }
    return totalNet;
  }

  /// Days until the next salary payout date
  int? get daysUntilNextSalary {
    if (isResigned) return null;

    final now = DateTime.now();
    DateTime payDate = DateTime(now.year, now.month, salaryDay.clamp(1, 28));

    if (payDate.isBefore(DateTime(now.year, now.month, now.day))) {
      payDate = DateTime(now.year, now.month + 1, salaryDay.clamp(1, 28));
    }

    return payDate.difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'company_name': companyName,
        'designation': designation,
        'basic_salary': effectiveBasicSalary,
        'fixed_allowance': fixedAllowance,
        'monthly_salary': effectiveGrossSalary,
        'salary_day': salaryDay,
        'start_date': startDate.toIso8601String().split('T').first,
        'end_date': endDate?.toIso8601String().split('T').first,
        'is_current': isCurrent,
        'notes': notes,
        'currency': currency,
        'is_probation': isProbation,
        'probation_months': probationMonths,
        'probation_end_date': probationEndDate?.toIso8601String().split('T').first,
        'has_epf_etf_during_probation': hasEpfEtfDuringProbation,
        'has_fixed_allowance_during_probation': hasFixedAllowanceDuringProbation,
        'promotions': promotions.map((p) => p.toJson()).toList(),
        'promotions_json': jsonEncode(promotions.map((p) => p.toJson()).toList()),
      };

  factory EmploymentModel.fromJson(Map<String, dynamic> json) {
    final bSalary = (json['basic_salary'] as num?)?.toDouble() ?? 0.0;
    final allowance = (json['fixed_allowance'] as num?)?.toDouble() ?? 0.0;
    final rawGross = (json['monthly_salary'] as num?)?.toDouble() ?? (bSalary + allowance);
    final finalBasic = bSalary > 0 ? bSalary : (rawGross - allowance > 0 ? rawGross - allowance : rawGross);
    final finalGross = (bSalary > 0 || allowance > 0) ? (finalBasic + allowance) : rawGross;

    final isProb = (json['is_probation'] as bool?) ?? (json['isProbation'] as bool?) ?? false;
    final probMonths = (json['probation_months'] as num?)?.toInt() ?? (json['probationMonths'] as num?)?.toInt() ?? 3;
    final probEndDateStr = json['probation_end_date']?.toString() ?? json['probationEndDate']?.toString();
    final hasEpfProb = (json['has_epf_etf_during_probation'] as bool?) ??
        (json['hasEpfEtfDuringProbation'] as bool?) ??
        true;
    final hasAllowanceProb = (json['has_fixed_allowance_during_probation'] as bool?) ??
        (json['hasFixedAllowanceDuringProbation'] as bool?) ??
        true;

    List<PromotionModel> promoList = [];
    if (json['promotions'] != null) {
      if (json['promotions'] is List) {
        promoList = (json['promotions'] as List)
            .map((item) => PromotionModel.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
      } else if (json['promotions'] is String && (json['promotions'] as String).isNotEmpty) {
        try {
          final decoded = jsonDecode(json['promotions'] as String);
          if (decoded is List) {
            promoList = decoded
                .map((item) => PromotionModel.fromJson(Map<String, dynamic>.from(item as Map)))
                .toList();
          }
        } catch (_) {}
      }
    } else if (json['promotions_json'] != null) {
      try {
        final decoded = jsonDecode(json['promotions_json'].toString());
        if (decoded is List) {
          promoList = decoded
              .map((item) => PromotionModel.fromJson(Map<String, dynamic>.from(item as Map)))
              .toList();
        }
      } catch (_) {}
    }

    return EmploymentModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      companyName: json['company_name']?.toString() ?? '',
      designation: json['designation']?.toString() ?? '',
      basicSalary: finalBasic,
      fixedAllowance: allowance,
      monthlySalary: finalGross,
      salaryDay: (json['salary_day'] as num?)?.toInt() ?? 25,
      startDate: DateTime.tryParse(json['start_date']?.toString() ?? '') ?? DateTime.now(),
      endDate: json['end_date'] != null ? DateTime.tryParse(json['end_date'].toString()) : null,
      isCurrent: (json['is_current'] as bool?) ?? (json['end_date'] == null),
      notes: json['notes']?.toString() ?? '',
      currency: json['currency']?.toString() ?? 'LKR',
      isProbation: isProb,
      probationMonths: probMonths,
      probationEndDate: probEndDateStr != null ? DateTime.tryParse(probEndDateStr) : null,
      hasEpfEtfDuringProbation: hasEpfProb,
      hasFixedAllowanceDuringProbation: hasAllowanceProb,
      promotions: promoList,
    );
  }

  EmploymentModel copyWith({
    String? id,
    String? userId,
    String? companyName,
    String? designation,
    double? basicSalary,
    double? fixedAllowance,
    double? monthlySalary,
    int? salaryDay,
    DateTime? startDate,
    DateTime? endDate,
    bool? isCurrent,
    String? notes,
    String? currency,
    bool? isProbation,
    int? probationMonths,
    DateTime? probationEndDate,
    bool? hasEpfEtfDuringProbation,
    bool? hasFixedAllowanceDuringProbation,
    List<PromotionModel>? promotions,
  }) {
    return EmploymentModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      companyName: companyName ?? this.companyName,
      designation: designation ?? this.designation,
      basicSalary: basicSalary ?? this.basicSalary,
      fixedAllowance: fixedAllowance ?? this.fixedAllowance,
      monthlySalary: monthlySalary ?? this.monthlySalary,
      salaryDay: salaryDay ?? this.salaryDay,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isCurrent: isCurrent ?? this.isCurrent,
      notes: notes ?? this.notes,
      currency: currency ?? this.currency,
      isProbation: isProbation ?? this.isProbation,
      probationMonths: probationMonths ?? this.probationMonths,
      probationEndDate: probationEndDate ?? this.probationEndDate,
      hasEpfEtfDuringProbation: hasEpfEtfDuringProbation ?? this.hasEpfEtfDuringProbation,
      hasFixedAllowanceDuringProbation: hasFixedAllowanceDuringProbation ?? this.hasFixedAllowanceDuringProbation,
      promotions: promotions ?? this.promotions,
    );
  }
}

class CareerSummary {
  final List<EmploymentModel> employments;
  final double totalCareerGross;
  final double totalCareerNet;
  final double totalEpfBalance;
  final double totalEtfBalance;
  final double totalEmployeeEpfDeducted;
  final double totalEmployerEpfContributed;
  final EmploymentModel? activeJob;
  final int totalCareerMonths;

  const CareerSummary({
    required this.employments,
    required this.totalCareerGross,
    required this.totalCareerNet,
    required this.totalEpfBalance,
    required this.totalEtfBalance,
    required this.totalEmployeeEpfDeducted,
    required this.totalEmployerEpfContributed,
    this.activeJob,
    required this.totalCareerMonths,
  });

  EmploymentModel? get activeEmployment => activeJob;
  double get totalAccumulatedEpf20 => totalEpfBalance;
  double get totalAccumulatedEtf3 => totalEtfBalance;

  factory CareerSummary.fromEmployments(List<EmploymentModel> list) {
    double gross = 0;
    double net = 0;
    double epfTotal = 0;
    double etfTotal = 0;
    double empEpf = 0;
    double compEpf = 0;
    int months = 0;
    EmploymentModel? active;

    for (final job in list) {
      gross += job.lifetimeGrossEarned;
      net += job.lifetimeNetSalary;
      epfTotal += job.lifetimeTotalEpf;
      etfTotal += job.lifetimeEmployerEtf;
      empEpf += job.lifetimeEmployeeEpf;
      compEpf += job.lifetimeEmployerEpf;
      months += job.monthsWorked;

      if (!job.isResigned && active == null) {
        active = job;
      }
    }

    return CareerSummary(
      employments: list,
      totalCareerGross: gross,
      totalCareerNet: net,
      totalEpfBalance: epfTotal,
      totalEtfBalance: etfTotal,
      totalEmployeeEpfDeducted: empEpf,
      totalEmployerEpfContributed: compEpf,
      activeJob: active,
      totalCareerMonths: months,
    );
  }

  factory CareerSummary.empty() => const CareerSummary(
        employments: [],
        totalCareerGross: 0,
        totalCareerNet: 0,
        totalEpfBalance: 0,
        totalEtfBalance: 0,
        totalEmployeeEpfDeducted: 0,
        totalEmployerEpfContributed: 0,
        activeJob: null,
        totalCareerMonths: 0,
      );
}
