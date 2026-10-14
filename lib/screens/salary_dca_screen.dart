import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/formatters.dart';
import '../data/models/salary_report_model.dart';
import '../providers/currency_provider.dart';
import '../providers/portfolio_provider.dart';
import '../widgets/skeleton_loading.dart';

class SalaryDcaScreen extends ConsumerWidget {
  const SalaryDcaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salaryReportAsync = ref.watch(salaryReportProvider);
    final currency = ref.watch(currencyProvider);

    final bgColor = AppColors.background(context);
    final surfaceColor = AppColors.surface(context);
    final borderColor = AppColors.border(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final textMuted = AppColors.textMuted(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text(
          'Salary Allocation & DCA Inflows',
          style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: salaryReportAsync.when(
        loading: () => const SalaryDcaSkeleton(),
        error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: AppColors.loss))),
        data: (report) {
          final recommendedDca = report.userSalary * (report.targetAllocationPercent / 100);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 1. Monthly Budget Summary Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF18171E), const Color(0xFF100F14)]
                        : [const Color(0xFFFFFFFF), const Color(0xFFF9F9FC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: isDark ? AppColors.primary.withAlpha(50) : borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'MONTHLY DCA TARGET',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGlow,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${report.targetAllocationPercent.toStringAsFixed(0)}% Target',
                            style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      Formatters.currency(recommendedDca, currency),
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Recommended monthly crypto DCA investment',
                      style: TextStyle(color: textSecondary, fontSize: 12),
                    ),
                    Divider(color: borderColor, height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Monthly Salary', style: TextStyle(color: textMuted, fontSize: 11)),
                            const SizedBox(height: 2),
                            Text(Formatters.currency(report.userSalary, currency), style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Total Capital Deposited', style: TextStyle(color: textMuted, fontSize: 11)),
                            const SizedBox(height: 2),
                            Text(Formatters.currency(report.totalDepositedToCrypto, currency), style: const TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Action button to record new month allocation
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: surfaceColor,
                  foregroundColor: textPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: borderColor),
                  ),
                ),
                onPressed: () => _showRecordDialog(context, ref, report.userSalary, currency),
                icon: const Icon(Icons.add, color: AppColors.primary),
                label: const Text('Record This Month\'s Salary Inflow'),
              ),
              const SizedBox(height: 24),

              // Monthly History
              Text(
                'Allocation History',
                style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              if (report.allocations.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Center(
                    child: Text('No salary allocations logged yet', style: TextStyle(color: textSecondary)),
                  ),
                )
              else
                ...report.allocations.map((a) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGlow,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.calendar_month, color: AppColors.primary, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  a.yearMonth,
                                  style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                                if (a.notes.isNotEmpty)
                                  Text(
                                    a.notes,
                                    style: TextStyle(color: textMuted, fontSize: 11),
                                  ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                Formatters.currency(a.allocatedAmount, currency),
                                style: const TextStyle(color: AppColors.profit, fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${a.allocationPercentage.toStringAsFixed(1)}% of salary',
                                style: TextStyle(color: textSecondary, fontSize: 11),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 18),
                            onPressed: () => _showRecordDialog(context, ref, report.userSalary, currency, existing: a),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppColors.loss, size: 18),
                            onPressed: () => _confirmDelete(context, ref, a.yearMonth),
                          ),
                        ],
                      ),
                    )),
            ],
          );
        },
      ),
    );
  }

  void _showRecordDialog(
    BuildContext context,
    WidgetRef ref,
    double defaultSalary,
    CurrencyInfo currency, {
    SalaryAllocationItem? existing,
  }) {
    final isEdit = existing != null;
    final surfaceColor = AppColors.surface(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);

    final ymController = TextEditingController(
      text: existing?.yearMonth ??
          '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}',
    );
    final initSal = existing != null
        ? (existing.originalCurrency == currency.code && existing.originalSalaryAmount != null
            ? existing.originalSalaryAmount!
            : existing.salaryAmount * currency.rateToUsd)
        : (defaultSalary > 0 ? defaultSalary * currency.rateToUsd : 2000.0);

    final initAlloc = existing != null
        ? (existing.originalCurrency == currency.code && existing.originalAllocatedAmount != null
            ? existing.originalAllocatedAmount!
            : existing.allocatedAmount * currency.rateToUsd)
        : 300.0;

    final salaryCtrl = TextEditingController(text: initSal.toStringAsFixed(currency.code == 'LKR' ? 0 : 2));
    final allocatedCtrl = TextEditingController(text: initAlloc.toStringAsFixed(currency.code == 'LKR' ? 0 : 2));
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surfaceColor,
        title: Text(isEdit ? 'Edit Salary Allocation' : 'Log Salary Allocation',
            style: TextStyle(color: textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ymController,
              enabled: !isEdit,
              decoration: InputDecoration(
                labelText: 'Month (YYYY-MM)',
                labelStyle: TextStyle(color: textSecondary),
              ),
              style: TextStyle(color: textPrimary),
            ),
            TextField(
              controller: salaryCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Salary (${currency.code})',
                labelStyle: TextStyle(color: textSecondary),
              ),
              style: TextStyle(color: textPrimary),
            ),
            TextField(
              controller: allocatedCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Allocated to Crypto (${currency.code})',
                labelStyle: TextStyle(color: textSecondary),
              ),
              style: TextStyle(color: textPrimary),
            ),
            TextField(
              controller: notesCtrl,
              decoration: InputDecoration(
                labelText: 'Notes',
                labelStyle: TextStyle(color: textSecondary),
              ),
              style: TextStyle(color: textPrimary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              final ym = ymController.text.trim();
              if (ym.isEmpty) return;
              final inputSal = double.tryParse(salaryCtrl.text) ?? 0.0;
              final inputAlloc = double.tryParse(allocatedCtrl.text) ?? 0.0;

              final rate = currency.rateToUsd > 0 ? currency.rateToUsd : 1.0;
              final baseSalary = inputSal / rate;
              final baseAlloc = inputAlloc / rate;

              final success = await ref.read(salaryReportProvider.notifier).saveAllocation({
                'yearMonth': ym,
                'salaryAmount': baseSalary,
                'allocatedAmount': baseAlloc,
                'originalCurrency': currency.code,
                'originalSalaryAmount': inputSal,
                'originalAllocatedAmount': inputAlloc,
                'fxToBase': 1.0 / rate,
                'notes': notesCtrl.text.trim(),
              });

              if (ctx.mounted) {
                if (success) {
                  Navigator.of(ctx).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to save allocation. Please retry.'), backgroundColor: AppColors.loss),
                  );
                }
              }
            },
            child: Text(isEdit ? 'Update' : 'Save', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String yearMonth) async {
    final surfaceColor = AppColors.surface(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surfaceColor,
        title: Text('Delete Allocation', style: TextStyle(color: textPrimary)),
        content: Text('Are you sure you want to delete the allocation for $yearMonth?',
            style: TextStyle(color: textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.loss),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(salaryReportProvider.notifier).deleteAllocation(yearMonth);
    }
  }
}
