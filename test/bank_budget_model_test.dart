import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/models/bank_budget_model.dart';

void main() {
  group('BankBudgetModel & Monthly Reports Tests', () {
    test('BankAccountModel correctly serializes and holds initial balance', () {
      final account = BankAccountModel(
        id: 'bank-1',
        userId: 'user-1',
        bankName: 'Sampath Bank',
        accountNumber: '1002345678',
        initialBalance: 250000.0,
        initialBalanceDate: DateTime(2026, 10, 1),
        currency: 'LKR',
        autoCreditSalary: true,
        salaryStartMonth: '2026-11',
      );

      final json = account.toJson();
      expect(json['bank_name'], 'Sampath Bank');
      expect(json['initial_balance'], 250000.0);
      expect(json['auto_credit_salary'], true);
      expect(json['salary_start_month'], '2026-11');

      final deserialized = BankAccountModel.fromJson(json);
      expect(deserialized.bankName, 'Sampath Bank');
      expect(deserialized.initialBalance, 250000.0);
      expect(deserialized.autoCreditSalary, true);
    });

    test('CashRecordModel correctly differentiates Income, Expense, and Investments', () {
      final income = CashRecordModel(
        id: 'c1',
        userId: 'u1',
        type: 'INCOME',
        category: 'Salary',
        amount: 150000.0,
        recordDate: DateTime(2026, 10, 25),
        yearMonth: '2026-10',
      );

      final expense = CashRecordModel(
        id: 'c2',
        userId: 'u1',
        type: 'EXPENSE',
        category: 'Food & Dining',
        amount: 35000.0,
        recordDate: DateTime(2026, 10, 26),
        yearMonth: '2026-10',
      );

      final invest = CashRecordModel(
        id: 'c3',
        userId: 'u1',
        type: 'INVESTMENT_TRANSFER',
        category: 'Crypto DCA',
        amount: 25000.0,
        recordDate: DateTime(2026, 10, 27),
        yearMonth: '2026-10',
      );

      expect(income.isIncome, isTrue);
      expect(income.isExpense, isFalse);
      expect(expense.isExpense, isTrue);
      expect(invest.isInvestment, isTrue);
    });

    test('MonthlyCashflowReport aggregates category breakdowns and net savings', () {
      final report = MonthlyCashflowReport(
        yearMonth: '2026-10',
        totalIncome: 200000.0,
        totalExpense: 80000.0,
        totalInvested: 40000.0,
        incomeByCategory: {'Salary': 160000.0, 'Freelance': 40000.0},
        expenseByCategory: {'Housing': 50000.0, 'Food': 30000.0},
        investmentByCategory: {'Crypto DCA': 20000.0, 'Fixed Deposit': 20000.0},
      );

      expect(report.netCashflow, 80000.0); // 200k - 80k - 40k = 80k
      expect(report.savingsRate, 60.0); // (200k - 80k)/200k = 60%
      expect(report.displayName, 'Oct 2026');
      expect(report.incomeByCategory['Salary'], 160000.0);
      expect(report.expenseByCategory['Housing'], 50000.0);
    });

    test('MonthlyBudgetPlanModel calculates custom percentage allocations', () {
      final plan = MonthlyBudgetPlanModel.defaults();
      expect(plan.savingsPercentage, 20.0);
      expect(plan.cryptoPercentage, 15.0);
      expect(plan.otherInvestPercentage, 15.0);
      expect(plan.expensesPercentage, 50.0);

      final updated = plan.copyWith(
        savingsPercentage: 25.0,
        cryptoPercentage: 25.0,
        otherInvestPercentage: 10.0,
        expensesPercentage: 40.0,
      );

      expect(updated.savingsPercentage + updated.cryptoPercentage + updated.otherInvestPercentage + updated.expensesPercentage, 100.0);
    });
  });
}
