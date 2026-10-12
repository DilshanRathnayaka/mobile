import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/models/employment_model.dart';

void main() {
  group('EmploymentModel & EPF / ETF Tests', () {
    test('Calculates Sri Lankan EPF and ETF breakdown correctly for active job', () {
      final job = EmploymentModel(
        id: 'job-1',
        userId: 'user-1',
        companyName: 'WSO2 Sri Lanka',
        designation: 'Senior Software Engineer',
        monthlySalary: 200000.0, // Rs. 200,000 basic
        salaryDay: 25,
        startDate: DateTime.now().subtract(const Duration(days: 60)), // ~2 months ago
        endDate: null,
        isCurrent: true,
      );

      // Monthly breakdown
      expect(job.monthlyEmployeeEpf8, equals(16000.0)); // 8% = 16,000
      expect(job.monthlyEmployerEpf12, equals(24000.0)); // 12% = 24,000
      expect(job.monthlyTotalEpf20, equals(40000.0)); // 20% = 40,000
      expect(job.monthlyEmployerEtf3, equals(6000.0)); // 3% = 6,000
      expect(job.monthlyNetSalary, equals(184000.0)); // 200,000 - 16,000 = 184,000
      expect(job.isResigned, isFalse);
    });

    test('Correctly calculates EPF on Basic pay when Fixed Allowance is present (80k basic + 10k allowance = 83.6k take home)', () {
      final job = EmploymentModel(
        id: 'job-allowance',
        userId: 'user-1',
        companyName: 'Tech Corp',
        designation: 'Software Engineer',
        basicSalary: 80000.0,    // Basic: Rs. 80,000.00
        fixedAllowance: 10000.0, // Allowance: Rs. 10,000.00
        monthlySalary: 90000.0,  // Gross: Rs. 90,000.00
        salaryDay: 25,
        startDate: DateTime(2024, 1, 1),
        endDate: null,
        isCurrent: true,
      );

      // EPF is strictly 8% of BASIC pay (80,000 * 0.08 = 6,400.00)
      expect(job.monthlyEmployeeEpf8, equals(6400.0));
      // Employer EPF 12% of basic (80,000 * 0.12 = 9,600.00)
      expect(job.monthlyEmployerEpf12, equals(9600.0));
      // Total EPF 20% (16,000.00)
      expect(job.monthlyTotalEpf20, equals(16000.0));
      // Employer ETF 3% of basic (80,000 * 0.03 = 2,400.00)
      expect(job.monthlyEmployerEtf3, equals(2400.0));
      // Gross salary: 80,000 + 10,000 = 90,000.00
      expect(job.effectiveGrossSalary, equals(90000.0));
      // Real Take-Home: Gross (90,000) - EPF (6,400) = Rs. 83,600.00!
      expect(job.monthlyNetSalary, equals(83600.0));
    });

    test('Freezes calculations when employment is resigned (end_date set)', () {
      final startDate = DateTime(2023, 1, 1);
      final resignDate = DateTime(2023, 7, 1); // exactly 6 months

      final resignedJob = EmploymentModel(
        id: 'job-resigned',
        userId: 'user-1',
        companyName: 'Previous Tech Corp',
        designation: 'Associate Engineer',
        monthlySalary: 100000.0,
        salaryDay: 25,
        startDate: startDate,
        endDate: resignDate,
        isCurrent: false,
      );

      expect(resignedJob.isResigned, isTrue);
      expect(resignedJob.monthsWorked, equals(6));
      expect(resignedJob.lifetimeGrossEarned, equals(600000.0)); // 6 * 100,000
      expect(resignedJob.lifetimeTotalEpf, equals(120000.0)); // 6 * 20,000
      expect(resignedJob.lifetimeEmployerEtf, equals(18000.0)); // 6 * 3,000
      expect(resignedJob.lifetimeNetSalary, equals(552000.0)); // 6 * 92,000 (100k gross - 8k emp epf)
    });

    test('CareerSummary correctly aggregates past resigned and new active employments', () {
      final job1 = EmploymentModel(
        id: 'job-1',
        userId: 'user-1',
        companyName: 'First Company',
        designation: 'Intern / Junior',
        monthlySalary: 100000.0,
        salaryDay: 25,
        startDate: DateTime(2022, 1, 1),
        endDate: DateTime(2023, 1, 1), // 12 months
        isCurrent: false,
      );

      final job2 = EmploymentModel(
        id: 'job-2',
        userId: 'user-1',
        companyName: 'Current Company',
        designation: 'Tech Lead',
        monthlySalary: 300000.0,
        salaryDay: 28,
        startDate: DateTime.now().subtract(const Duration(days: 30)),
        endDate: null,
        isCurrent: true,
      );

      final summary = CareerSummary.fromEmployments([job1, job2]);

      expect(summary.employments.length, equals(2));
      expect(summary.activeJob, isNotNull);
      expect(summary.activeJob!.companyName, equals('Current Company'));
      // Past job 1 contributes 12 months of EPF (12 * 20,000 = 240,000)
      expect(job1.lifetimeTotalEpf, equals(240000.0));
      expect(summary.totalEpfBalance, greaterThanOrEqualTo(240000.0));
      expect(summary.totalCareerMonths, greaterThanOrEqualTo(13));
    });
  });
}
