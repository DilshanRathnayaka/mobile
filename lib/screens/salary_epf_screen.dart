import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/formatters.dart';
import '../data/models/employment_model.dart';
import '../providers/employment_provider.dart';

class SalaryEpfScreen extends ConsumerStatefulWidget {
  const SalaryEpfScreen({super.key});

  @override
  ConsumerState<SalaryEpfScreen> createState() => _SalaryEpfScreenState();
}

class _SalaryEpfScreenState extends ConsumerState<SalaryEpfScreen> {
  @override
  Widget build(BuildContext context) {
    final employmentsAsync = ref.watch(employmentListProvider);
    final career = ref.watch(careerSummaryProvider);

    final bgColor = AppColors.background(context);
    final surfaceColor = AppColors.surface(context);
    final surfaceLight = AppColors.surfaceLight(context);
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
          'Career, Salary & EPF/ETF',
          style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Add Employment',
            icon: const Icon(Icons.add_business_outlined, color: AppColors.primary),
            onPressed: () => _openJobDialog(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: surfaceColor,
        onRefresh: () => ref.read(employmentListProvider.notifier).refresh(),
        child: employmentsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (err, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: AppColors.loss, size: 48),
                const SizedBox(height: 12),
                Text('Error loading career records: $err', style: TextStyle(color: textPrimary)),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: () => ref.read(employmentListProvider.notifier).refresh(),
                  child: const Text('Retry', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
          data: (jobs) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 1. CBSL EPF & ETF Total Retirement Fund Hero Card
                _buildEpfHeroCard(context, career, isDark),
                const SizedBox(height: 18),

                // 2. Active Job & Live Monthly Salary Slip (if active job exists)
                if (career.activeJob != null) ...[
                  _buildActiveJobCard(context, career.activeJob!, surfaceColor, borderColor, textPrimary, textSecondary, textMuted),
                  const SizedBox(height: 20),
                ] else if (jobs.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.gold.withAlpha(80)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: AppColors.gold, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'No Active Job Set',
                                style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'All past jobs are marked as resigned. Tap "Add New Job" to track your current employment.',
                                style: TextStyle(color: textSecondary, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // 3. Career Timeline Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'CAREER TIMELINE & JOBS',
                        style: TextStyle(
                          color: textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _openJobDialog(context),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Job', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 4. List of Career Jobs
                if (jobs.isEmpty)
                  _buildEmptyState(context, surfaceColor, borderColor, textPrimary, textSecondary)
                else
                  ...jobs.map((job) => _buildJobCard(
                        context,
                        job,
                        surfaceColor,
                        surfaceLight,
                        borderColor,
                        textPrimary,
                        textSecondary,
                        textMuted,
                      )),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }

  // 1. CBSL EPF & ETF Government Funds Hero Card
  Widget _buildEpfHeroCard(BuildContext context, CareerSummary career, bool isDark) {
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final borderColor = AppColors.border(context);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF13131A), const Color(0xFF0C0C10)]
              : [const Color(0xFFFFFFFF), const Color(0xFFF7F7FB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primary.withAlpha(70), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withAlpha(120) : Colors.black.withAlpha(20),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'GOVERNMENT FUNDS (EPF & ETF)',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryGlow,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Sri Lanka CBSL',
                  style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Total CBSL EPF Accumulated Fund (20%)
          Text('Total EPF Balance (20% Fund)', style: TextStyle(color: textSecondary, fontSize: 12)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _formatLkr(career.totalEpfBalance),
              style: TextStyle(color: textPrimary, fontSize: 32, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 14),

          // Sub-metrics: Employee 8% vs Employer 12%
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.loss.withAlpha(18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your 8% Deductions', style: TextStyle(color: textSecondary, fontSize: 10)),
                      const SizedBox(height: 3),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _formatLkr(career.totalEmployeeEpfDeducted),
                          style: const TextStyle(color: AppColors.loss, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.profit.withAlpha(18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Company 12% Gift', style: TextStyle(color: textSecondary, fontSize: 10)),
                      const SizedBox(height: 3),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _formatLkr(career.totalEmployerEpfContributed),
                          style: const TextStyle(color: AppColors.profit, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          Divider(color: borderColor, height: 26),

          // Bottom metrics: ETF 3% and Lifetime Gross Earned
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total ETF Balance (3%)', style: TextStyle(color: textSecondary, fontSize: 11)),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _formatLkr(career.totalEtfBalance),
                        style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Career Gross Earned', style: TextStyle(color: textSecondary, fontSize: 11)),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        _formatLkr(career.totalCareerGross),
                        style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 2. Current Active Job & Live Salary Slip Card
  Widget _buildActiveJobCard(
    BuildContext context,
    EmploymentModel job,
    Color surfaceColor,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
  ) {
    final daysUntil = job.daysUntilNextSalary;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            job.companyName,
                            style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.profitBg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('ACTIVE', style: TextStyle(color: AppColors.profit, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(job.designation, style: TextStyle(color: textSecondary, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (daysUntil != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary.withAlpha(80)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        daysUntil == 0 ? 'Pay Day Today!' : '$daysUntil Days Left',
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      Text('Day ${job.salaryDay}', style: TextStyle(color: textMuted, fontSize: 10)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Monthly Breakdown Table
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _salaryRow('Basic Salary (EPF Base)', _formatLkr(job.effectiveBasicSalary), textPrimary, textSecondary),
                if (job.fixedAllowance > 0) ...[
                  const SizedBox(height: 6),
                  _salaryRow('Fixed Allowance (Non-EPF)', '+${_formatLkr(job.fixedAllowance)}', AppColors.profit, textSecondary),
                  const SizedBox(height: 6),
                  _salaryRow('Gross Salary (Total)', _formatLkr(job.effectiveGrossSalary), textPrimary, textSecondary),
                ],
                const SizedBox(height: 6),
                _salaryRow('Employee EPF (8% of Basic)', '-${_formatLkr(job.monthlyEmployeeEpf8)}', AppColors.loss, textSecondary),
                Divider(color: borderColor.withAlpha(60), height: 16),
                _salaryRow('Real Net Take-Home (Bank)', _formatLkr(job.monthlyNetSalary), AppColors.profit, textPrimary, isBold: true),
                Divider(color: borderColor.withAlpha(60), height: 16),
                _salaryRow('Company EPF (12% of Basic)', '+${_formatLkr(job.monthlyEmployerEpf12)}', AppColors.primary, textSecondary),
                const SizedBox(height: 6),
                _salaryRow('Company ETF (3% of Basic)', '+${_formatLkr(job.monthlyEmployerEtf3)}', AppColors.gold, textSecondary),
                const SizedBox(height: 6),
                _salaryRow('Total EPF Fund (20% of Basic)', _formatLkr(job.monthlyTotalEpf20), const Color(0xFF9D7CFF), textSecondary, isBold: true),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Joined: ${Formatters.date(job.startDate)} • ${job.durationText}',
                  style: TextStyle(color: textMuted, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    onPressed: () => _confirmResign(context, job),
                    icon: const Icon(Icons.exit_to_app, color: AppColors.loss, size: 15),
                    label: const Text('Resign', style: TextStyle(color: AppColors.loss, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: Icon(Icons.edit_outlined, color: textMuted, size: 16),
                    onPressed: () => _openJobDialog(context, jobToEdit: job),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 3. Job Card in Timeline (Active or Resigned)
  Widget _buildJobCard(
    BuildContext context,
    EmploymentModel job,
    Color surfaceColor,
    Color surfaceLight,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
  ) {
    final isResigned = job.isResigned;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isResigned ? borderColor.withAlpha(50) : borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isResigned ? textMuted.withAlpha(20) : AppColors.primaryGlow,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isResigned ? Icons.history : Icons.business,
                        color: isResigned ? textMuted : AppColors.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            job.companyName,
                            style: TextStyle(
                              color: textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            job.designation,
                            style: TextStyle(color: textSecondary, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isResigned ? textMuted.withAlpha(25) : AppColors.profitBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isResigned ? 'RESIGNED' : 'ACTIVE',
                  style: TextStyle(
                    color: isResigned ? textMuted : AppColors.profit,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Timeline Dates
          Row(
            children: [
              Icon(Icons.calendar_month, color: textMuted, size: 14),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '${Formatters.date(job.startDate)} ➔ ${job.endDate != null ? Formatters.date(job.endDate!) : "Present"} (${job.durationText})',
                  style: TextStyle(color: textSecondary, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Career Output from this Job
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: surfaceLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Gross Earned', style: TextStyle(color: textMuted, fontSize: 10)),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _formatLkr(job.lifetimeGrossEarned),
                          style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text('EPF Accumulated', style: TextStyle(color: textMuted, fontSize: 10)),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: Text(
                          _formatLkr(job.lifetimeTotalEpf),
                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('ETF Accumulated', style: TextStyle(color: textMuted, fontSize: 10)),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          _formatLkr(job.lifetimeEmployerEtf),
                          style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Actions Row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!isResigned)
                TextButton(
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  onPressed: () => _confirmResign(context, job),
                  child: const Text('Set Resignation Date', style: TextStyle(color: AppColors.loss, fontSize: 11)),
                ),
              IconButton(
                icon: Icon(Icons.edit_outlined, color: textMuted, size: 16),
                onPressed: () => _openJobDialog(context, jobToEdit: job),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.loss, size: 16),
                onPressed: () => _confirmDelete(context, job.id),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    Color surfaceColor,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.work_outline, size: 48, color: AppColors.primary),
            const SizedBox(height: 12),
            Text('No Employment Records Yet', style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              'Add your current or past jobs to automatically track lifetime salary, CBSL EPF (20%), and ETF (3%).',
              textAlign: TextAlign.center,
              style: TextStyle(color: textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _openJobDialog(context),
              icon: const Icon(Icons.add, color: Colors.white, size: 18),
              label: const Text('Add First Job', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _salaryRow(String label, String value, Color valColor, Color lblColor, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: lblColor,
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text(
            value,
            style: TextStyle(
              color: valColor,
              fontSize: isBold ? 14 : 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  String _formatLkr(double amount, {bool showCents = true}) {
    return Formatters.fullLkr(amount, showCents: showCents);
  }

  // Dialog: Add or Edit Employment
  void _openJobDialog(BuildContext context, {EmploymentModel? jobToEdit}) {
    final companyCtrl = TextEditingController(text: jobToEdit?.companyName ?? '');
    final designationCtrl = TextEditingController(text: jobToEdit?.designation ?? '');
    final basicSalaryCtrl = TextEditingController(
      text: jobToEdit != null
          ? (jobToEdit.basicSalary > 0
              ? jobToEdit.basicSalary.toStringAsFixed(0)
              : jobToEdit.monthlySalary.toStringAsFixed(0))
          : '',
    );
    final allowanceCtrl = TextEditingController(
      text: jobToEdit != null && jobToEdit.fixedAllowance > 0
          ? jobToEdit.fixedAllowance.toStringAsFixed(0)
          : '',
    );
    final salaryDayCtrl = TextEditingController(text: jobToEdit != null ? jobToEdit.salaryDay.toString() : '25');
    final notesCtrl = TextEditingController(text: jobToEdit?.notes ?? '');

    DateTime joinDate = jobToEdit?.startDate ?? DateTime.now();
    DateTime? resignDate = jobToEdit?.endDate;
    bool isCurrentJob = jobToEdit?.isCurrent ?? true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          final textPrimary = AppColors.textPrimary(modalCtx);
          final textSecondary = AppColors.textSecondary(modalCtx);
          final borderColor = AppColors.border(modalCtx);

          final curBasic = double.tryParse(basicSalaryCtrl.text.trim()) ?? 0.0;
          final curAllowance = double.tryParse(allowanceCtrl.text.trim()) ?? 0.0;
          final curGross = curBasic + curAllowance;
          final curEmpEpf = curBasic * 0.08;
          final curNet = curGross - curEmpEpf;
          final curCompEpf = curBasic * 0.12;
          final curCompEtf = curBasic * 0.03;

          return Padding(
            padding: EdgeInsets.only(
              top: 20,
              left: 20,
              right: 20,
              bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        jobToEdit != null ? 'Edit Employment' : 'Add New Job',
                        style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Company Name
                  Text('Company Name', style: TextStyle(color: textSecondary, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: companyCtrl,
                    style: TextStyle(color: textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'e.g. Sysco Labs, IFS, Virtusa...',
                      filled: true,
                      fillColor: AppColors.surfaceLight(modalCtx),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Designation
                  Text('Designation / Role', style: TextStyle(color: textSecondary, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: designationCtrl,
                    style: TextStyle(color: textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'e.g. Software Engineer, Tech Lead...',
                      filled: true,
                      fillColor: AppColors.surfaceLight(modalCtx),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Basic Salary (EPF Base)
                  Text('Basic Monthly Salary (LKR) *', style: TextStyle(color: textSecondary, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text('EPF (8% employee + 12% employer) & ETF (3%) are legally deducted from this', style: TextStyle(color: AppColors.textMuted(modalCtx), fontSize: 10.5)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: basicSalaryCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
                    onChanged: (_) => setModalState(() {}),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.account_balance, color: AppColors.primary),
                      hintText: 'e.g. 80000',
                      filled: true,
                      fillColor: AppColors.surfaceLight(modalCtx),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Fixed Allowance (Non-EPF) & Salary Day Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Fixed Allowances (LKR)', style: TextStyle(color: textSecondary, fontSize: 12)),
                            const SizedBox(height: 2),
                            Text('Non-EPF additions', style: TextStyle(color: AppColors.textMuted(modalCtx), fontSize: 10)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: allowanceCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
                              onChanged: (_) => setModalState(() {}),
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.add_circle_outline, color: AppColors.profit),
                                hintText: 'e.g. 10000',
                                filled: true,
                                fillColor: AppColors.surfaceLight(modalCtx),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Salary Day', style: TextStyle(color: textSecondary, fontSize: 12)),
                            const SizedBox(height: 2),
                            Text('Day of Month (1-28)', style: TextStyle(color: AppColors.textMuted(modalCtx), fontSize: 10)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: salaryDayCtrl,
                              keyboardType: TextInputType.number,
                              style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                hintText: '25',
                                filled: true,
                                fillColor: AppColors.surfaceLight(modalCtx),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Dynamic Live Salary Breakdown Preview
                  if (curBasic > 0) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGlow,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.primary.withAlpha(90), width: 1.2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'REAL SALARY BREAKDOWN',
                                style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.profitBg,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('Exact Full Amount', style: TextStyle(color: AppColors.profit, fontSize: 9.5, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _salaryRow('Gross Salary (Basic + Allowance)', Formatters.fullLkr(curGross), textPrimary, textSecondary),
                          const SizedBox(height: 4),
                          _salaryRow('Employee EPF (8% of Basic)', '-${Formatters.fullLkr(curEmpEpf)}', AppColors.loss, textSecondary),
                          Divider(color: borderColor.withAlpha(80), height: 16),
                          _salaryRow('Real Net Take-Home (Bank)', Formatters.fullLkr(curNet), AppColors.profit, textPrimary, isBold: true),
                          Divider(color: borderColor.withAlpha(80), height: 16),
                          _salaryRow('Company EPF (12% of Basic)', '+${Formatters.fullLkr(curCompEpf)}', AppColors.primary, textSecondary),
                          const SizedBox(height: 4),
                          _salaryRow('Company ETF (3% of Basic)', '+${Formatters.fullLkr(curCompEtf)}', AppColors.gold, textSecondary),
                          const SizedBox(height: 4),
                          _salaryRow('Total EPF Fund (20% of Basic)', Formatters.fullLkr(curBasic * 0.20), const Color(0xFF9D7CFF), textSecondary, isBold: true),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Join Date Picker Tile
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today, color: AppColors.primary, size: 20),
                    title: Text('Join Date (Start): ${Formatters.date(joinDate)}', style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                    trailing: const Text('Change', style: TextStyle(color: AppColors.primary, fontSize: 12)),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: modalCtx,
                        initialDate: joinDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setModalState(() => joinDate = picked);
                      }
                    },
                  ),

                  // Current Job Checkbox
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('This is my current active job', style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: Text('Salary and EPF/ETF will compound continuously until resignation.', style: TextStyle(color: textSecondary, fontSize: 11)),
                    value: isCurrentJob,
                    activeColor: AppColors.primary,
                    onChanged: (val) {
                      setModalState(() {
                        isCurrentJob = val ?? true;
                        if (isCurrentJob) {
                          resignDate = null;
                        }
                      });
                    },
                  ),

                  // Resignation Date Tile (if not current job)
                  if (!isCurrentJob) ...[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event_busy, color: AppColors.loss, size: 20),
                      title: Text(
                        resignDate != null
                            ? 'Resignation Date: ${Formatters.date(resignDate!)}'
                            : 'Set Resignation Date (Required for past jobs)',
                        style: TextStyle(color: resignDate != null ? textPrimary : AppColors.loss, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      trailing: const Text('Select', style: TextStyle(color: AppColors.loss, fontSize: 12)),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: modalCtx,
                          initialDate: resignDate ?? DateTime.now(),
                          firstDate: joinDate,
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setModalState(() => resignDate = picked);
                        }
                      },
                    ),
                  ],

                  // Notes
                  const SizedBox(height: 8),
                  TextField(
                    controller: notesCtrl,
                    style: TextStyle(color: textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Optional notes, contract type, remarks...',
                      filled: true,
                      fillColor: AppColors.surfaceLight(modalCtx),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Submit Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final company = companyCtrl.text.trim();
                      final desig = designationCtrl.text.trim();
                      final basic = double.tryParse(basicSalaryCtrl.text.trim()) ?? 0.0;
                      final allowance = double.tryParse(allowanceCtrl.text.trim()) ?? 0.0;
                      final sDay = int.tryParse(salaryDayCtrl.text.trim()) ?? 25;

                      if (company.isEmpty || desig.isEmpty || basic <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please fill all required company, role, and basic salary fields.'), backgroundColor: AppColors.loss),
                        );
                        return;
                      }

                      if (!isCurrentJob && resignDate == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select a resignation date for past employment.'), backgroundColor: AppColors.loss),
                        );
                        return;
                      }

                      final messenger = ScaffoldMessenger.of(context);
                      final nav = Navigator.of(ctx);

                      if (jobToEdit != null) {
                        await ref.read(employmentListProvider.notifier).updateEmployment(
                              id: jobToEdit.id,
                              companyName: company,
                              designation: desig,
                              basicSalary: basic,
                              fixedAllowance: allowance,
                              monthlySalary: basic + allowance,
                              salaryDay: sDay.clamp(1, 28),
                              startDate: joinDate,
                              endDate: isCurrentJob ? null : resignDate,
                              isCurrent: isCurrentJob,
                              notes: notesCtrl.text.trim(),
                            );
                      } else {
                        await ref.read(employmentListProvider.notifier).addEmployment(
                              companyName: company,
                              designation: desig,
                              basicSalary: basic,
                              fixedAllowance: allowance,
                              monthlySalary: basic + allowance,
                              salaryDay: sDay.clamp(1, 28),
                              startDate: joinDate,
                              endDate: isCurrentJob ? null : resignDate,
                              isCurrent: isCurrentJob,
                              notes: notesCtrl.text.trim(),
                            );
                      }

                      if (ctx.mounted) {
                        nav.pop();
                      }
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(jobToEdit != null ? 'Employment updated successfully!' : 'Job added to career timeline!'),
                          backgroundColor: AppColors.profit,
                        ),
                      );
                    },
                    child: Text(
                      jobToEdit != null ? 'Save Changes' : 'Confirm Employment',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Dialog: Resign from Job
  void _confirmResign(BuildContext context, EmploymentModel job) {
    DateTime resignDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setDialogState) {
          final textPrimary = AppColors.textPrimary(modalCtx);
          final textSecondary = AppColors.textSecondary(modalCtx);

          return AlertDialog(
            backgroundColor: AppColors.surface(context),
            title: Text('Resign from ${job.companyName}', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Once you set a resignation date, salary earnings, EPF (20%), and ETF (3%) will freeze on this date and will not generate further payments.',
                  style: TextStyle(color: textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_busy, color: AppColors.loss),
                  title: Text('Last Working Day: ${Formatters.date(resignDate)}', style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                  trailing: const Text('Change', style: TextStyle(color: AppColors.loss, fontSize: 12)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: modalCtx,
                      initialDate: resignDate,
                      firstDate: job.startDate,
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setDialogState(() => resignDate = picked);
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: TextStyle(color: textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.loss),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final nav = Navigator.of(ctx);

                  await ref.read(employmentListProvider.notifier).markResigned(
                        id: job.id,
                        resignationDate: resignDate,
                      );
                  if (ctx.mounted) {
                    nav.pop();
                  }
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Resignation recorded for ${job.companyName}. Calculations frozen at ${Formatters.date(resignDate)}.'),
                      backgroundColor: AppColors.loss,
                    ),
                  );
                },
                child: const Text('Confirm Resignation', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  // Dialog: Delete Job
  void _confirmDelete(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        title: Text('Delete Job Record', style: TextStyle(color: AppColors.textPrimary(context))),
        content: Text('Are you sure you want to delete this employment entry from your career history?', style: TextStyle(color: AppColors.textSecondary(context))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary(context))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.loss),
            onPressed: () {
              ref.read(employmentListProvider.notifier).deleteEmployment(id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
