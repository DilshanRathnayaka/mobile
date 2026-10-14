import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/formatters.dart';
import '../data/models/employment_model.dart';
import '../providers/employment_provider.dart';
import '../widgets/skeleton_loading.dart';

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
            tooltip: 'Run Monthly Salary Scheduler (Bank Credit & DCA)',
            icon: const Icon(Icons.bolt_rounded, color: Color(0xFF00E676)),
            onPressed: _triggerMonthlySalary,
          ),
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
          loading: () => const SalaryEpfSkeleton(),
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
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            job.activeDesignation,
                            style: TextStyle(color: textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (job.activeDesignation != job.designation) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGlow,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.primary.withAlpha(80)),
                            ),
                            child: const Text('PROMOTED', style: TextStyle(color: AppColors.primary, fontSize: 8.5, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
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

          // Probation Status Banner (if currently under probation)
          if (job.isInProbation()) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: job.hasEpfEtfDuringProbation ? AppColors.primary.withAlpha(20) : const Color(0xFFF59E0B).withAlpha(20),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: job.hasEpfEtfDuringProbation ? AppColors.primary.withAlpha(80) : const Color(0xFFF59E0B),
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    job.hasEpfEtfDuringProbation ? Icons.info_outline : Icons.warning_amber_rounded,
                    color: job.hasEpfEtfDuringProbation ? AppColors.primary : const Color(0xFFF59E0B),
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.hasEpfEtfDuringProbation
                              ? 'Currently on Probation (${job.probationMonths} Mos) • EPF Active'
                              : 'Currently on Probation • EPF/ETF Exempt (100% Take-Home)',
                          style: TextStyle(
                            color: job.hasEpfEtfDuringProbation ? AppColors.primary : const Color(0xFFF59E0B),
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          () {
                            final epfText = job.hasEpfEtfDuringProbation
                                ? 'EPF (20%) and ETF (3%) contributions active from join date.'
                                : 'No 8% EPF deducted. You receive full basic pay until confirmed on ${Formatters.date(job.effectiveProbationEndDate)}.';
                            if (!job.hasFixedAllowanceDuringProbation && job.fixedAllowance > 0) {
                              return '$epfText Fixed allowance (+${_formatLkr(job.fixedAllowance)}) starts after permanent confirmation.';
                            }
                            return epfText;
                          }(),
                          style: TextStyle(color: textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Monthly Breakdown Table
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _salaryRow('Basic Salary (EPF Base)', _formatLkr(job.activeBasicSalary), textPrimary, textSecondary),
                if (job.activeFixedAllowance > 0 || job.fixedAllowance > 0) ...[
                  const SizedBox(height: 6),
                  if (job.isInProbation() && !job.hasFixedAllowanceDuringProbation)
                    _salaryRow('Fixed Allowance (Non-EPF)', 'Rs. 0.00 (Permanent Only)', AppColors.gold, textSecondary)
                  else
                    _salaryRow('Fixed Allowance (Non-EPF)', '+${_formatLkr(job.activeFixedAllowance)}', AppColors.profit, textSecondary),
                  const SizedBox(height: 6),
                  _salaryRow('Gross Salary (Total)', _formatLkr(job.effectiveGrossSalary), textPrimary, textSecondary),
                ],
                const SizedBox(height: 6),
                _salaryRow(
                  'Employee EPF (8% of Basic)',
                  job.isEpfApplicable() ? '-${_formatLkr(job.monthlyEmployeeEpf8)}' : 'Rs. 0.00 (Exempt during probation)',
                  job.isEpfApplicable() ? AppColors.loss : const Color(0xFFF59E0B),
                  textSecondary,
                ),
                Divider(color: borderColor.withAlpha(60), height: 16),
                _salaryRow('Real Net Take-Home (Bank)', _formatLkr(job.monthlyNetSalary), AppColors.profit, textPrimary, isBold: true),
                Divider(color: borderColor.withAlpha(60), height: 16),
                _salaryRow(
                  'Company EPF (12% of Basic)',
                  job.isEpfApplicable() ? '+${_formatLkr(job.monthlyEmployerEpf12)}' : 'Rs. 0.00 (Exempt)',
                  job.isEpfApplicable() ? AppColors.primary : textMuted,
                  textSecondary,
                ),
                const SizedBox(height: 6),
                _salaryRow(
                  'Company ETF (3% of Basic)',
                  job.isEpfApplicable() ? '+${_formatLkr(job.monthlyEmployerEtf3)}' : 'Rs. 0.00 (Exempt)',
                  job.isEpfApplicable() ? AppColors.gold : textMuted,
                  textSecondary,
                ),
                const SizedBox(height: 6),
                _salaryRow(
                  'Total EPF Fund (20% of Basic)',
                  job.isEpfApplicable() ? _formatLkr(job.monthlyTotalEpf20) : 'Rs. 0.00',
                  job.isEpfApplicable() ? const Color(0xFF9D7CFF) : textMuted,
                  textSecondary,
                  isBold: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 2.1 Career Progression & Promotions Section
          _buildPromotionsSection(context, job, surfaceColor, borderColor, textPrimary, textSecondary, textMuted),
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

  // 2.1 Career Progression & Promotions Timeline
  Widget _buildPromotionsSection(
    BuildContext context,
    EmploymentModel job,
    Color surfaceColor,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
  ) {
    final promotions = job.sortedPromotions;
    final upcoming = job.upcomingPromotions;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor.withAlpha(80)),
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
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGlow,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.workspace_premium_outlined,
                        color: AppColors.primary,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Career Progression',
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            promotions.isEmpty
                                ? 'Track increments & promotions'
                                : '${promotions.length} milestone${promotions.length > 1 ? "s" : ""}'
                                    '${upcoming.isNotEmpty ? " • ${upcoming.length} upcoming" : ""}',
                            style: TextStyle(color: textMuted, fontSize: 10),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _openAddPromotionDialog(context, job),
                icon: const Icon(Icons.add, size: 13),
                label: const Text('Add Promo', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          if (promotions.isEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background(context).withAlpha(120),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor.withAlpha(70)),
              ),
              child: Row(
                children: [
                  Icon(Icons.trending_up, color: AppColors.primary.withAlpha(180), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Expecting a promotion or salary hike in the future? Schedule it here to preview future take-home pay and auto-apply when the date arrives.',
                      style: TextStyle(color: textSecondary, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            ...promotions.map((p) => _buildPromotionItem(
                  context,
                  job,
                  p,
                  textPrimary,
                  textSecondary,
                  textMuted,
                  borderColor,
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildPromotionItem(
    BuildContext context,
    EmploymentModel job,
    PromotionModel promo,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
    Color borderColor,
  ) {
    final isUpcoming = promo.isUpcoming;
    final isActive = !isUpcoming && (job.activePromotion()?.id == promo.id);
    final basicDiff = promo.basicSalary - job.basicSalary;
    final pctHike = job.basicSalary > 0 ? (basicDiff / job.basicSalary) * 100 : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isUpcoming
              ? const Color(0xFF3B82F6).withAlpha(120)
              : isActive
                  ? AppColors.profit.withAlpha(120)
                  : borderColor.withAlpha(70),
          width: (isUpcoming || isActive) ? 1.2 : 1.0,
        ),
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
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: isUpcoming
                            ? const Color(0xFF3B82F6).withAlpha(30)
                            : isActive
                                ? AppColors.profitBg
                                : textMuted.withAlpha(25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isUpcoming
                                ? Icons.schedule
                                : isActive
                                    ? Icons.verified
                                    : Icons.check_circle_outline,
                            size: 11,
                            color: isUpcoming
                                ? const Color(0xFF3B82F6)
                                : isActive
                                    ? AppColors.profit
                                    : textMuted,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            isUpcoming
                                ? 'UPCOMING'
                                : isActive
                                    ? 'ACTIVE'
                                    : 'PAST TIER',
                            style: TextStyle(
                              color: isUpcoming
                                  ? const Color(0xFF3B82F6)
                                  : isActive
                                      ? AppColors.profit
                                      : textMuted,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Eff: ${Formatters.date(promo.effectiveDate)}',
                        style: TextStyle(color: textMuted, fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(Icons.edit_outlined, size: 15, color: textMuted),
                    onPressed: () => _openAddPromotionDialog(context, job, promoToEdit: promo),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.delete_outline, size: 15, color: AppColors.loss),
                    onPressed: () => _confirmDeletePromotion(context, job.id, promo),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      promo.designation,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (promo.notes.isNotEmpty)
                      Text(
                        promo.notes,
                        style: TextStyle(color: textSecondary, fontSize: 10.5, fontStyle: FontStyle.italic),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatLkr(promo.basicSalary),
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (pctHike != 0)
                    Text(
                      '${pctHike > 0 ? "+" : ""}${pctHike.toStringAsFixed(1)}% hike',
                      style: TextStyle(
                        color: pctHike > 0 ? AppColors.profit : AppColors.loss,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (promo.fixedAllowance > 0) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('+ Fixed Allowance', style: TextStyle(color: textMuted, fontSize: 10.5)),
                Text('+${_formatLkr(promo.fixedAllowance)}', style: TextStyle(color: textSecondary, fontSize: 10.5, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
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
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 2,
              runSpacing: 2,
              children: [
                TextButton.icon(
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  onPressed: () => _openAddPromotionDialog(context, job),
                  icon: const Icon(Icons.workspace_premium_outlined, color: AppColors.primary, size: 14),
                  label: Text(
                    job.promotions.isEmpty ? '+ Promo' : '${job.promotions.length} Promo${job.promotions.length > 1 ? "s" : ""}',
                    style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
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
    bool isProbation = jobToEdit?.isProbation ?? false;
    int probationMonths = jobToEdit?.probationMonths ?? 6;
    bool hasEpfEtfDuringProbation = jobToEdit?.hasEpfEtfDuringProbation ?? true;
    bool hasFixedAllowanceDuringProbation = jobToEdit?.hasFixedAllowanceDuringProbation ?? false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          final textPrimary = AppColors.textPrimary(modalCtx);
          final textSecondary = AppColors.textSecondary(modalCtx);
          final textMuted = AppColors.textMuted(modalCtx);
          final borderColor = AppColors.border(modalCtx);
          final surfaceLight = AppColors.surfaceLight(modalCtx);

          final curBasic = double.tryParse(basicSalaryCtrl.text.trim()) ?? 0.0;
          final curAllowance = double.tryParse(allowanceCtrl.text.trim()) ?? 0.0;
          final curProbationAllowance = (isProbation && !hasFixedAllowanceDuringProbation) ? 0.0 : curAllowance;
          final curGross = curBasic + curProbationAllowance;
          final isEpfExempt = isProbation && !hasEpfEtfDuringProbation;
          final curEmpEpf = isEpfExempt ? 0.0 : curBasic * 0.08;
          final curNet = curGross - curEmpEpf;
          final curCompEpf = isEpfExempt ? 0.0 : curBasic * 0.12;
          final curCompEtf = isEpfExempt ? 0.0 : curBasic * 0.03;

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

                  // Probation Period Configuration Card
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isProbation ? AppColors.gold.withAlpha(20) : surfaceLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isProbation ? AppColors.gold : borderColor,
                        width: isProbation ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.verified_user_outlined,
                              color: isProbation ? AppColors.gold : textSecondary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Probation Period Setting',
                                    style: TextStyle(
                                      color: textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    'Configure temporary probation status & EPF policy',
                                    style: TextStyle(color: textMuted, fontSize: 10.5),
                                  ),
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: isProbation,
                              activeThumbColor: AppColors.gold,
                              onChanged: (val) {
                                setModalState(() {
                                  isProbation = val;
                                });
                              },
                            ),
                          ],
                        ),
                        if (isProbation) ...[
                          const SizedBox(height: 10),
                          Divider(height: 1, color: borderColor.withAlpha(80)),
                          const SizedBox(height: 10),
                          // Probation Months Selector
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Probation Duration:',
                                    style: TextStyle(color: textSecondary, fontSize: 12),
                                  ),
                                  Text(
                                    '$probationMonths Months',
                                    style: const TextStyle(
                                      color: AppColors.gold,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [3, 6, 12].map((months) {
                                  final isSelected = probationMonths == months;
                                  return Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 2.5),
                                      child: InkWell(
                                        onTap: () {
                                          setModalState(() {
                                            probationMonths = months;
                                          });
                                        },
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 7),
                                          decoration: BoxDecoration(
                                            color: isSelected ? AppColors.gold : surfaceLight,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: isSelected ? AppColors.gold : borderColor,
                                            ),
                                          ),
                                          child: Text(
                                            '$months Mo',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: isSelected ? Colors.black : textPrimary,
                                              fontSize: 11,
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // EPF/ETF during probation toggle
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.surface(modalCtx),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: borderColor.withAlpha(80)),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  hasEpfEtfDuringProbation ? Icons.check_circle : Icons.money_off_csred_rounded,
                                  color: hasEpfEtfDuringProbation ? AppColors.profit : AppColors.gold,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        hasEpfEtfDuringProbation
                                            ? 'EPF/ETF Deducted During Probation'
                                            : 'EPF/ETF Exempt During Probation',
                                        style: TextStyle(
                                          color: textPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        hasEpfEtfDuringProbation
                                            ? 'Standard 8% employee deduction applies.'
                                            : 'No EPF/ETF deducted. Employee takes home 100% gross pay until confirmed.',
                                        style: TextStyle(
                                          color: textMuted,
                                          fontSize: 10.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch.adaptive(
                                  value: hasEpfEtfDuringProbation,
                                  activeThumbColor: AppColors.primary,
                                  onChanged: (val) {
                                    setModalState(() {
                                      hasEpfEtfDuringProbation = val;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Fixed Allowance during probation toggle
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.surface(modalCtx),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: borderColor.withAlpha(80)),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  hasFixedAllowanceDuringProbation ? Icons.payments_outlined : Icons.money_off_rounded,
                                  color: hasFixedAllowanceDuringProbation ? AppColors.profit : AppColors.gold,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        hasFixedAllowanceDuringProbation
                                            ? 'Fixed Allowance Paid in Probation'
                                            : 'Allowance Starts After Confirmation',
                                        style: TextStyle(
                                          color: textPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        hasFixedAllowanceDuringProbation
                                            ? 'Full fixed allowance is added during probation months.'
                                            : 'Rs. 0 allowance in probation. Allowance begins only once permanent.',
                                        style: TextStyle(
                                          color: textMuted,
                                          fontSize: 10.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch.adaptive(
                                  value: hasFixedAllowanceDuringProbation,
                                  activeThumbColor: AppColors.profit,
                                  onChanged: (val) {
                                    setModalState(() {
                                      hasFixedAllowanceDuringProbation = val;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

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
                                child: Text(
                                  isEpfExempt ? 'Probation Exempt' : 'Exact Full Amount',
                                  style: TextStyle(color: isEpfExempt ? AppColors.gold : AppColors.profit, fontSize: 9.5, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          if (isEpfExempt) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.gold.withAlpha(30),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: const [
                                  Icon(Icons.info_outline, size: 14, color: AppColors.gold),
                                  SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Probation EPF Exemption Active: Take-home equals 100% Gross Salary',
                                      style: TextStyle(color: AppColors.gold, fontSize: 10.5, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (isProbation && !hasFixedAllowanceDuringProbation && curAllowance > 0) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.gold.withAlpha(30),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline, size: 14, color: AppColors.gold),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Allowance Policy: Rs. ${Formatters.fullLkr(curAllowance)} allowance withheld until permanent confirmation.',
                                      style: const TextStyle(color: AppColors.gold, fontSize: 10.5, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          _salaryRow('Basic Salary (EPF Base)', Formatters.fullLkr(curBasic), textPrimary, textSecondary),
                          if (curAllowance > 0) ...[
                            const SizedBox(height: 4),
                            if (isProbation && !hasFixedAllowanceDuringProbation)
                              _salaryRow('Fixed Allowance (Probation)', 'LKR 0 (Starts Permanent)', AppColors.gold, textSecondary)
                            else
                              _salaryRow('Fixed Allowance (Non-EPF)', '+${Formatters.fullLkr(curAllowance)}', AppColors.profit, textSecondary),
                          ],
                          const SizedBox(height: 4),
                          _salaryRow('Gross Salary (Current Period)', Formatters.fullLkr(curGross), textPrimary, textSecondary),
                          const SizedBox(height: 4),
                          _salaryRow(
                            isEpfExempt ? 'Employee EPF (Exempt - 0%)' : 'Employee EPF (8% of Basic)',
                            isEpfExempt ? 'LKR 0 (Exempt)' : '-${Formatters.fullLkr(curEmpEpf)}',
                            isEpfExempt ? AppColors.gold : AppColors.loss,
                            textSecondary,
                          ),
                          Divider(color: borderColor.withAlpha(80), height: 16),
                          _salaryRow('Real Net Take-Home (Bank)', Formatters.fullLkr(curNet), AppColors.profit, textPrimary, isBold: true),
                          Divider(color: borderColor.withAlpha(80), height: 16),
                          _salaryRow(
                            isEpfExempt ? 'Company EPF (Exempt - 0%)' : 'Company EPF (12% of Basic)',
                            isEpfExempt ? 'LKR 0 (Exempt)' : '+${Formatters.fullLkr(curCompEpf)}',
                            AppColors.primary,
                            textSecondary,
                          ),
                          const SizedBox(height: 4),
                          _salaryRow(
                            isEpfExempt ? 'Company ETF (Exempt - 0%)' : 'Company ETF (3% of Basic)',
                            isEpfExempt ? 'LKR 0 (Exempt)' : '+${Formatters.fullLkr(curCompEtf)}',
                            AppColors.gold,
                            textSecondary,
                          ),
                          const SizedBox(height: 4),
                          _salaryRow(
                            'Total EPF Fund (20% of Basic)',
                            isEpfExempt ? 'LKR 0 (Exempt)' : Formatters.fullLkr(curBasic * 0.20),
                            const Color(0xFF9D7CFF),
                            textSecondary,
                            isBold: true,
                          ),
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
                              isProbation: isProbation,
                              probationMonths: probationMonths,
                              hasEpfEtfDuringProbation: hasEpfEtfDuringProbation,
                              hasFixedAllowanceDuringProbation: hasFixedAllowanceDuringProbation,
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
                              isProbation: isProbation,
                              probationMonths: probationMonths,
                              hasEpfEtfDuringProbation: hasEpfEtfDuringProbation,
                              hasFixedAllowanceDuringProbation: hasFixedAllowanceDuringProbation,
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

  /// Triggers Spring Boot monthly salary scheduler, bank crediting, and DCA allocations
  Future<void> _triggerMonthlySalary() async {
    final now = DateTime.now();
    final currentYearMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        title: Row(
          children: const [
            Icon(Icons.bolt_rounded, color: Color(0xFF00E676)),
            SizedBox(width: 8),
            Text('Run Salary Engine', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          'This will execute the Spring Boot monthly salary engine for $currentYearMonth:\n\n'
          '• Check probation status & EPF/ETF exemptions\n'
          '• Calculate precise Take-Home net salary\n'
          '• Auto-credit funds to Primary Bank Account\n'
          '• Allocate automated Monthly DCA targets\n\n'
          'Run salary calculation now?',
          style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.textMuted(context))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Execute Engine', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              SizedBox(width: 12),
              Text('Processing monthly salary and allocations...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      final result = await ref.read(employmentListProvider.notifier).processMonthlySalary(yearMonth: currentYearMonth);
      if (mounted) {
        messenger.clearSnackBars();
        if (result != null && result['status'] == 'SUCCESS') {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: AppColors.surface(context),
              title: Row(
                children: const [
                  Icon(Icons.check_circle_rounded, color: AppColors.profit),
                  SizedBox(width: 8),
                  Text('Salary Credited', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Month: ${result['yearMonth']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(
                    'Net Pay: ${Formatters.fullLkr((result['netSalary'] as num?)?.toDouble() ?? 0.0)}',
                    style: const TextStyle(color: AppColors.profit, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text('Bank Credited: ${result['bankCredited'] == true ? "Yes (${result['targetBankName'] ?? 'Primary Account'})" : "Already Credited"}'),
                  const SizedBox(height: 4),
                  Text('DCA Allocations: ${(result['allocations'] as List?)?.length ?? 0} targets executed'),
                  if (result['message'] != null) ...[
                    const SizedBox(height: 8),
                    Text(result['message'].toString(), style: TextStyle(color: AppColors.textMuted(context), fontSize: 11)),
                  ]
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Done'),
                ),
              ],
            ),
          );
        } else {
          messenger.showSnackBar(
            SnackBar(
              content: Text(result?['message'] ?? 'Salary processed or already up to date for $currentYearMonth'),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      }
    }
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

  // Dialog: Add or Edit Promotion / Scheduled Increment
  void _openAddPromotionDialog(
    BuildContext context,
    EmploymentModel job, {
    PromotionModel? promoToEdit,
  }) {
    final designationCtrl = TextEditingController(
      text: promoToEdit?.designation ?? job.activeDesignation,
    );
    final basicSalaryCtrl = TextEditingController(
      text: promoToEdit != null
          ? promoToEdit.basicSalary.toStringAsFixed(0)
          : (job.activeBasicSalary > 0
              ? job.activeBasicSalary.toStringAsFixed(0)
              : job.monthlySalary.toStringAsFixed(0)),
    );
    final allowanceCtrl = TextEditingController(
      text: promoToEdit != null
          ? (promoToEdit.fixedAllowance > 0 ? promoToEdit.fixedAllowance.toStringAsFixed(0) : '')
          : (job.activeFixedAllowance > 0 ? job.activeFixedAllowance.toStringAsFixed(0) : ''),
    );
    final notesCtrl = TextEditingController(text: promoToEdit?.notes ?? '');

    DateTime effectiveDate = promoToEdit?.effectiveDate ?? DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          final textPrimary = AppColors.textPrimary(modalCtx);
          final textSecondary = AppColors.textSecondary(modalCtx);
          final textMuted = AppColors.textMuted(modalCtx);
          final borderColor = AppColors.border(modalCtx);
          final surfaceLight = AppColors.surfaceLight(modalCtx);

          final curBasic = double.tryParse(basicSalaryCtrl.text.trim()) ?? 0.0;
          final curAllowance = double.tryParse(allowanceCtrl.text.trim()) ?? 0.0;
          final curGross = curBasic + curAllowance;
          final curEmpEpf = curBasic * 0.08;
          final curNet = curGross - curEmpEpf;
          final curCompEpf = curBasic * 0.12;
          final curCompEtf = curBasic * 0.03;
          final curTotalEpf = curBasic * 0.20;

          final baseBasic = promoToEdit != null ? job.basicSalary : job.activeBasicSalary;
          final diffBasic = curBasic - baseBasic;
          final hikePct = baseBasic > 0 ? (diffBasic / baseBasic) * 100 : 0.0;

          final now = DateTime.now();
          final isFutureScheduled = effectiveDate.isAfter(DateTime(now.year, now.month, now.day));

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
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGlow,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.workspace_premium_outlined,
                              color: AppColors.primary,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            promoToEdit != null ? 'Edit Promotion' : 'Add Promotion / Increment',
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Timing notice: Past vs Future Scheduled
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isFutureScheduled
                          ? const Color(0xFF3B82F6).withAlpha(20)
                          : AppColors.profitBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isFutureScheduled
                            ? const Color(0xFF3B82F6).withAlpha(100)
                            : AppColors.profit.withAlpha(100),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          isFutureScheduled ? Icons.schedule_rounded : Icons.check_circle_outline,
                          color: isFutureScheduled ? const Color(0xFF3B82F6) : AppColors.profit,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isFutureScheduled
                                    ? 'Scheduled Future Promotion / Increment'
                                    : 'Immediate Active Promotion',
                                style: TextStyle(
                                  color: isFutureScheduled
                                      ? const Color(0xFF3B82F6)
                                      : AppColors.profit,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isFutureScheduled
                                    ? 'This promotion will stay scheduled until ${Formatters.date(effectiveDate)}. On that date, active designation and salary will automatically update.'
                                    : 'This promotion took effect on ${Formatters.date(effectiveDate)}. Active designation and live slip reflect this increment immediately.',
                                style: TextStyle(color: textSecondary, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Job Title / New Designation
                  Text('New Designation / Role Title', style: TextStyle(color: textSecondary, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: designationCtrl,
                    style: TextStyle(color: textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'e.g. Senior Software Engineer / Lead / Manager',
                      hintStyle: TextStyle(color: textMuted),
                      prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                      filled: true,
                      fillColor: surfaceLight,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Effective Date Selector
                  Text('Effective Promotion Date', style: TextStyle(color: textSecondary, fontSize: 12)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: modalCtx,
                        initialDate: effectiveDate,
                        firstDate: job.startDate,
                        lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
                      );
                      if (picked != null) {
                        setModalState(() => effectiveDate = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: surfaceLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.primary),
                              const SizedBox(width: 10),
                              Text(
                                Formatters.date(effectiveDate),
                                style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isFutureScheduled ? const Color(0xFF3B82F6).withAlpha(25) : AppColors.profitBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isFutureScheduled ? 'Future Date' : 'Past / Today',
                              style: TextStyle(
                                color: isFutureScheduled ? const Color(0xFF3B82F6) : AppColors.profit,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Basic Salary & Allowance Inputs
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('New Basic Salary (EPF Base)', style: TextStyle(color: textSecondary, fontSize: 12)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: basicSalaryCtrl,
                              keyboardType: TextInputType.number,
                              style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                              onChanged: (_) => setModalState(() {}),
                              decoration: InputDecoration(
                                prefixText: 'Rs. ',
                                prefixStyle: const TextStyle(fontWeight: FontWeight.bold),
                                hintText: '250000',
                                hintStyle: TextStyle(color: textMuted),
                                filled: true,
                                fillColor: surfaceLight,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Fixed Allowance (Non-EPF)', style: TextStyle(color: textSecondary, fontSize: 12)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: allowanceCtrl,
                              keyboardType: TextInputType.number,
                              style: TextStyle(color: textPrimary, fontSize: 14),
                              onChanged: (_) => setModalState(() {}),
                              decoration: InputDecoration(
                                prefixText: 'Rs. ',
                                prefixStyle: const TextStyle(fontWeight: FontWeight.bold),
                                hintText: '0',
                                hintStyle: TextStyle(color: textMuted),
                                filled: true,
                                fillColor: surfaceLight,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Reason / Appraisal Notes
                  Text('Promotion Reason / Notes (Optional)', style: TextStyle(color: textSecondary, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: notesCtrl,
                    style: TextStyle(color: textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'e.g. Annual Appraisal 2026 / Performance Merit / Team Lead promotion',
                      hintStyle: TextStyle(color: textMuted),
                      prefixIcon: const Icon(Icons.notes, size: 20),
                      filled: true,
                      fillColor: surfaceLight,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Live Projected Hike & EPF Impact Preview
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withAlpha(60)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'PROJECTED IMPACT & HIKE',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                            if (hikePct != 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: hikePct > 0 ? AppColors.profitBg : AppColors.loss.withAlpha(25),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${hikePct > 0 ? "+" : ""}${hikePct.toStringAsFixed(1)}% Basic Hike',
                                  style: TextStyle(
                                    color: hikePct > 0 ? AppColors.profit : AppColors.loss,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _salaryRow('New Gross Earnings', _formatLkr(curGross), textPrimary, textSecondary),
                        const SizedBox(height: 4),
                        _salaryRow('Employee EPF (8%)', '-${_formatLkr(curEmpEpf)}', AppColors.loss, textSecondary),
                        Divider(color: borderColor.withAlpha(80), height: 14),
                        _salaryRow('Projected Net Take-Home', _formatLkr(curNet), AppColors.profit, textPrimary, isBold: true),
                        Divider(color: borderColor.withAlpha(80), height: 14),
                        _salaryRow('Company EPF (12%)', '+${_formatLkr(curCompEpf)}', AppColors.primary, textSecondary),
                        const SizedBox(height: 4),
                        _salaryRow('Company ETF (3%)', '+${_formatLkr(curCompEtf)}', AppColors.gold, textSecondary),
                        const SizedBox(height: 4),
                        _salaryRow('Total EPF Monthly Fund (20%)', _formatLkr(curTotalEpf), const Color(0xFF9D7CFF), textSecondary, isBold: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Confirm / Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        final desig = designationCtrl.text.trim();
                        final basic = double.tryParse(basicSalaryCtrl.text.trim()) ?? 0.0;
                        final allowance = double.tryParse(allowanceCtrl.text.trim()) ?? 0.0;
                        final notes = notesCtrl.text.trim();

                        if (desig.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter designation / role title.')),
                          );
                          return;
                        }

                        if (basic <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter a valid basic salary.')),
                          );
                          return;
                        }

                        final messenger = ScaffoldMessenger.of(context);
                        final nav = Navigator.of(ctx);

                        bool ok;
                        if (promoToEdit != null) {
                          final updated = promoToEdit.copyWith(
                            designation: desig,
                            basicSalary: basic,
                            fixedAllowance: allowance,
                            effectiveDate: effectiveDate,
                            notes: notes,
                          );
                          ok = await ref.read(employmentListProvider.notifier).updatePromotion(
                                employmentId: job.id,
                                promotion: updated,
                              );
                        } else {
                          ok = await ref.read(employmentListProvider.notifier).addPromotion(
                                employmentId: job.id,
                                designation: desig,
                                basicSalary: basic,
                                fixedAllowance: allowance,
                                effectiveDate: effectiveDate,
                                notes: notes,
                              );
                        }

                        if (ctx.mounted) {
                          nav.pop();
                        }

                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(ok
                                ? (isFutureScheduled
                                    ? 'Promotion scheduled for ${Formatters.date(effectiveDate)}!'
                                    : 'Promotion saved and activated!')
                                : 'Failed to save promotion. Please try again.'),
                            backgroundColor: ok ? AppColors.profit : AppColors.loss,
                          ),
                        );
                      },
                      child: Text(
                        promoToEdit != null ? 'Update Promotion' : (isFutureScheduled ? 'Schedule Promotion' : 'Apply Promotion'),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
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

  // Dialog: Confirm Delete Promotion
  void _confirmDeletePromotion(
    BuildContext context,
    String employmentId,
    PromotionModel promo,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        title: Text('Delete Promotion', style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to delete the promotion milestone "${promo.designation}" (${_formatLkr(promo.basicSalary)}) effective ${Formatters.date(promo.effectiveDate)}?',
          style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary(context))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.loss),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final nav = Navigator.of(ctx);

              final ok = await ref.read(employmentListProvider.notifier).deletePromotion(
                    employmentId: employmentId,
                    promotionId: promo.id,
                  );

              if (ctx.mounted) {
                nav.pop();
              }

              messenger.showSnackBar(
                SnackBar(
                  content: Text(ok ? 'Promotion deleted.' : 'Failed to delete promotion.'),
                  backgroundColor: ok ? AppColors.profit : AppColors.loss,
                ),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
