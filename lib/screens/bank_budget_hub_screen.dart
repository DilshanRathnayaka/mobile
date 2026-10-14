import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/formatters.dart';
import '../data/models/bank_budget_model.dart';
import '../data/models/employment_model.dart';
import '../providers/bank_budget_provider.dart';
import '../providers/employment_provider.dart';
import 'salary_epf_screen.dart';
import '../widgets/skeleton_loading.dart';

class BankBudgetHubScreen extends ConsumerStatefulWidget {
  const BankBudgetHubScreen({super.key});

  @override
  ConsumerState<BankBudgetHubScreen> createState() => _BankBudgetHubScreenState();
}

class _BankBudgetHubScreenState extends ConsumerState<BankBudgetHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _recordFilter = 'ALL'; // 'ALL', 'INCOME', 'EXPENSE', 'INVESTMENT_TRANSFER'
  String? _selectedReportYm; // Currently inspected month in Reports tab
  String _reportScope = 'MONTHLY'; // 'MONTHLY', 'QUARTERLY', 'HALF_YEAR', 'ALL_TIME'
  double _simExpenseCutPct = 10.0; // 0.0, 10.0, 20.0, 30.0
  double _simIncomeBoostPct = 0.0; // 0.0, 5.0, 10.0, 15.0

  // Exact Sri Lankan Rupee (LKR) Formatter down to the exact cent (e.g. Rs. 150,250.75)
  static String _lkr(num amount) => Formatters.fullLkr(amount, showCents: true);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabSelection);
  }

  void _handleTabSelection() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final budgetAsync = ref.watch(bankBudgetProvider);
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
          'Bank, Salary & Budget Hub (LKR)',
          style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Configure Starting Balance (LKR)',
            icon: const Icon(Icons.account_balance_outlined, color: AppColors.primary),
            onPressed: () {
              budgetAsync.whenData((summary) {
                _showInitialBalanceDialog(context, summary.account);
              });
            },
          ),
          IconButton(
            tooltip: 'Career & EPF Details',
            icon: const Icon(Icons.badge_outlined, color: Color(0xFF9D7CFF)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SalaryEpfScreen()),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: textMuted,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Allocation'),
            Tab(text: 'Reports & KPIs'),
          ],
        ),
      ),
      body: budgetAsync.when(
        loading: () => const BankBudgetSkeleton(),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: AppColors.loss, size: 48),
              const SizedBox(height: 12),
              Text('Error loading budget records: $err', style: TextStyle(color: textPrimary)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(bankBudgetProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (summary) {
          return TabBarView(
            controller: _tabController,
            children: [
              // Tab 1: Overview & Cash Ledger
              _buildOverviewTab(context, summary, career, isDark, surfaceColor, borderColor, textPrimary, textSecondary, textMuted),
              // Tab 2: Salary Allocation Planner
              _buildAllocationTab(context, summary, career, isDark, surfaceColor, borderColor, textPrimary, textSecondary, textMuted),
              // Tab 3: Monthly Comparative Reports & Visual Insights
              _buildReportsTab(context, summary, isDark, surfaceColor, surfaceLight, borderColor, textPrimary, textSecondary, textMuted),
            ],
          );
        },
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add, color: Colors.black),
              label: const Text('Add Record (Rs.)', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              onPressed: () => _showAddRecordSheet(context),
            )
          : null,
    );
  }

  // ==========================================
  // TAB 1: OVERVIEW TAB
  // ==========================================
  Widget _buildOverviewTab(
    BuildContext context,
    BankBudgetSummary summary,
    CareerSummary career,
    bool isDark,
    Color surfaceColor,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
  ) {
    final filteredRecords = summary.records.where((r) {
      if (_recordFilter == 'ALL') return true;
      return r.type == _recordFilter;
    }).toList();

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: surfaceColor,
      onRefresh: () => ref.read(bankBudgetProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // 1. Bank Account Balance Card
          _buildBankBalanceCard(context, summary, career, isDark, borderColor, textPrimary, textMuted),
          const SizedBox(height: 14),

          // 2. Action buttons row
          Row(
            children: [
              Expanded(
                child: _buildQuickActionButton(
                  icon: Icons.arrow_downward_rounded,
                  label: '+ Income',
                  color: AppColors.profit,
                  onTap: () => _showAddRecordSheet(context, defaultType: 'INCOME'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQuickActionButton(
                  icon: Icons.arrow_upward_rounded,
                  label: '- Expense',
                  color: AppColors.loss,
                  onTap: () => _showAddRecordSheet(context, defaultType: 'EXPENSE'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQuickActionButton(
                  icon: Icons.pie_chart_outline_rounded,
                  label: 'Invest',
                  color: const Color(0xFF9D7CFF),
                  onTap: () => _showAddRecordSheet(context, defaultType: 'INVESTMENT_TRANSFER'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 3. Mini KPI Strip
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  'Total Inflow',
                  '+${_lkr(summary.totalIncomeAllTime)}',
                  AppColors.profit,
                  Icons.trending_up,
                  surfaceColor,
                  borderColor,
                  textMuted,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  'Total Outflow',
                  '-${_lkr(summary.totalExpenseAllTime)}',
                  AppColors.loss,
                  Icons.trending_down,
                  surfaceColor,
                  borderColor,
                  textMuted,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  'Invested',
                  _lkr(summary.totalInvestedAllTime),
                  const Color(0xFF9D7CFF),
                  Icons.account_balance,
                  surfaceColor,
                  borderColor,
                  textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 4. Filter Chips
          Row(
            children: [
              Expanded(
                child: Text('Cash Activity', style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildFilterChip('All', 'ALL'),
                    const SizedBox(width: 4),
                    _buildFilterChip('In', 'INCOME'),
                    const SizedBox(width: 4),
                    _buildFilterChip('Out', 'EXPENSE'),
                    const SizedBox(width: 4),
                    _buildFilterChip('Inv', 'INVESTMENT_TRANSFER'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 5. Records List
          if (filteredRecords.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  Icon(Icons.receipt_long_outlined, size: 48, color: textMuted),
                  const SizedBox(height: 12),
                  Text('No cash records found', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Tap "+ Income" or "- Expense" to log your first transaction in LKR with exact cents.',
                      style: TextStyle(color: textMuted, fontSize: 12), textAlign: TextAlign.center),
                ],
              ),
            )
          else
            ...filteredRecords.map((r) => _buildRecordTile(context, r, surfaceColor, borderColor, textPrimary, textMuted)),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildBankBalanceCard(
    BuildContext context,
    BankBudgetSummary summary,
    CareerSummary career,
    bool isDark,
    Color borderColor,
    Color textPrimary,
    Color textMuted,
  ) {
    final nextMonthStr = DateFormat('yyyy-MM').format(DateTime(DateTime.now().year, DateTime.now().month + 1, 1));
    final hasNextMonthSalaryAlready = summary.records.any(
      (r) => r.yearMonth == nextMonthStr && r.category == 'Salary' && r.isIncome,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF141924), const Color(0xFF0F1218)]
              : [const Color(0xFFF0F4FF), const Color(0xFFE6EEFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF3861FB).withAlpha(80), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3861FB).withAlpha(20),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
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
                        color: const Color(0xFF3861FB).withAlpha(30),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.account_balance_rounded, color: Color(0xFF3861FB), size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            summary.account.bankName,
                            style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (summary.account.accountNumber.isNotEmpty)
                            Text(
                              'A/C: ${summary.account.accountNumber}',
                              style: TextStyle(color: textMuted, fontSize: 11),
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
              InkWell(
                onTap: () => _showInitialBalanceDialog(context, summary.account),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_outlined, size: 12, color: textPrimary),
                      const SizedBox(width: 4),
                      Text('Edit Baseline', style: TextStyle(color: textPrimary, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'CURRENT AVAILABLE BANK BALANCE (LKR)',
            style: TextStyle(color: Color(0xFF3861FB), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _lkr(summary.currentBalance),
              style: TextStyle(
                color: summary.currentBalance >= 0 ? textPrimary : AppColors.loss,
                fontSize: 30,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Starting: ${_lkr(summary.account.initialBalance)}',
                    style: TextStyle(color: textMuted, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Net: ${summary.currentBalance - summary.account.initialBalance >= 0 ? "+" : ""}${_lkr(summary.currentBalance - summary.account.initialBalance)}',
                    style: TextStyle(
                      color: summary.currentBalance - summary.account.initialBalance >= 0 ? AppColors.profit : AppColors.loss,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Active Employer & Auto-credit info
          if (career.activeEmployment != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF00D182).withAlpha(15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF00D182).withAlpha(40)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_rounded, color: Color(0xFF00D182), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Auto-credited Monthly Salary (${career.activeEmployment!.companyName}): ${_lkr(career.activeEmployment!.monthlyNetSalary)}',
                      style: TextStyle(color: textPrimary, fontSize: 11),
                    ),
                  ),
                  if (!hasNextMonthSalaryAlready)
                    InkWell(
                      onTap: () => _simulateNextMonthSalary(context, nextMonthStr),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00D182).withAlpha(40),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Simulate Next Mo', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF00D182))),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(70)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(
    String label,
    String value,
    Color color,
    IconData icon,
    Color surfaceColor,
    Color borderColor,
    Color textMuted,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(label, style: TextStyle(color: textMuted, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String filterKey) {
    final isSelected = _recordFilter == filterKey;
    return InkWell(
      onTap: () => setState(() => _recordFilter = filterKey),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppColors.primary : Colors.grey.withAlpha(80)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.grey,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildRecordTile(
    BuildContext context,
    CashRecordModel record,
    Color surfaceColor,
    Color borderColor,
    Color textPrimary,
    Color textMuted,
  ) {
    final Color badgeColor;
    final IconData icon;
    final String sign;

    if (record.isIncome) {
      badgeColor = AppColors.profit;
      icon = Icons.south_west_rounded;
      sign = '+';
    } else if (record.isExpense) {
      badgeColor = AppColors.loss;
      icon = Icons.north_east_rounded;
      sign = '-';
    } else {
      badgeColor = const Color(0xFF9D7CFF);
      icon = Icons.savings_rounded;
      sign = '→';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: badgeColor.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: badgeColor, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        record.category,
                        style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (record.isAutoGenerated) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3861FB).withAlpha(30),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('AUTO', style: TextStyle(color: Color(0xFF3861FB), fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${DateFormat('dd MMM yyyy').format(record.recordDate)}${record.notes.isNotEmpty ? " • ${record.notes}" : ""}',
                  style: TextStyle(color: textMuted, fontSize: 11),
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
                '$sign${_lkr(record.amount)}',
                style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
              InkWell(
                onTap: () => _confirmDeleteRecord(context, record),
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(Icons.delete_outline, size: 14, color: textMuted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: ALLOCATION PLANNER (SAVINGS/CRYPTO/OTHER)
  // ==========================================
  Widget _buildAllocationTab(
    BuildContext context,
    BankBudgetSummary summary,
    CareerSummary career,
    bool isDark,
    Color surfaceColor,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
  ) {
    final activeJob = career.activeJob ?? career.activeEmployment;
    final hasSalary = activeJob != null && activeJob.monthlyNetSalary > 0;

    if (!hasSalary) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.primary, size: 42),
                ),
                const SizedBox(height: 20),
                Text(
                  'No Active Salary Profile Found',
                  style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'To calculate your personal monthly budget allocation under International Money Management Rules (such as the 50/30/20 standard), please add your active employment and take-home salary in Career & EPF/ETF.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textSecondary, fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.profitBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.profit.withAlpha(50)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.verified_user_outlined, color: AppColors.profit, size: 16),
                      SizedBox(width: 8),
                      Text(
                        '100% Real Data • Zero Dummy Estimates',
                        style: TextStyle(color: AppColors.profit, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size(230, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SalaryEpfScreen()),
                    );
                  },
                  icon: const Icon(Icons.add_business_rounded, color: Colors.white, size: 18),
                  label: const Text(
                    'Configure Career & Salary',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final totalMonthlyInflow = activeJob.monthlyNetSalary;

    // International Money Management Framework (50/30/20 Rule Standard)
    // 1. Needs & Living Essentials (Default 50%) -> mapped to summary.plan.expensesPercentage
    // 2. Wants & Discretionary Lifestyle (Default 30%) -> mapped to summary.plan.otherInvestPercentage
    // 3. Bank Savings, Emergency Reserves & Debt (Default 20%) -> mapped to summary.plan.savingsPercentage
    final needsPercent = summary.plan.needsPercentage;
    final wantsPercent = summary.plan.wantsPercentage;
    final savingsPercent = summary.plan.savingsBufferPercentage;

    final needsAmount = totalMonthlyInflow * (needsPercent / 100);
    final wantsAmount = totalMonthlyInflow * (wantsPercent / 100);
    final savingsAmount = totalMonthlyInflow * (savingsPercent / 100);

    final is503020 = (needsPercent - 50).abs() < 1 && (wantsPercent - 30).abs() < 1 && (savingsPercent - 20).abs() < 1;
    final is702010 = (needsPercent - 70).abs() < 1 && (wantsPercent - 10).abs() < 1 && (savingsPercent - 20).abs() < 1;
    final is602020 = (needsPercent - 60).abs() < 1 && (wantsPercent - 20).abs() < 1 && (savingsPercent - 20).abs() < 1;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Allocation Target Header
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1E172E), const Color(0xFF13101D)]
                  : [const Color(0xFFF7F2FF), const Color(0xFFEDE2FE)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF9D7CFF).withAlpha(80)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'INTERNATIONAL SALARY ALLOCATION (LKR)',
                      style: TextStyle(
                        color: Color(0xFF9D7CFF),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _showEditBudgetPlanDialog(context, summary.plan),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9D7CFF).withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Adjust %', style: TextStyle(color: Color(0xFF9D7CFF), fontSize: 11.5, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Net Take-Home: ${_lkr(totalMonthlyInflow)}',
                style: TextStyle(color: textPrimary, fontSize: 19, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Active Salary from ${activeJob.companyName} (${activeJob.designation})',
                style: TextStyle(color: textMuted, fontSize: 12),
              ),
              const SizedBox(height: 14),

              // International Rules Quick Presets
              Text(
                'INTERNATIONAL FRAMEWORK PRESET:',
                style: TextStyle(color: textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildRuleChip(
                      label: '50/30/20 Standard',
                      isSelected: is503020,
                      onTap: () {
                        ref.read(bankBudgetProvider.notifier).updateBudgetPlan(
                              summary.plan.copyWith(
                                expensesPercentage: 50.0,
                                otherInvestPercentage: 30.0,
                                savingsPercentage: 20.0,
                                cryptoPercentage: 0.0,
                              ),
                            );
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildRuleChip(
                      label: '70/20/10 Cashflow',
                      isSelected: is702010,
                      onTap: () {
                        ref.read(bankBudgetProvider.notifier).updateBudgetPlan(
                              summary.plan.copyWith(
                                expensesPercentage: 70.0,
                                otherInvestPercentage: 10.0,
                                savingsPercentage: 20.0,
                                cryptoPercentage: 0.0,
                              ),
                            );
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildRuleChip(
                      label: '60/20/20 Balanced',
                      isSelected: is602020,
                      onTap: () {
                        ref.read(bankBudgetProvider.notifier).updateBudgetPlan(
                              summary.plan.copyWith(
                                expensesPercentage: 60.0,
                                otherInvestPercentage: 20.0,
                                savingsPercentage: 20.0,
                                cryptoPercentage: 0.0,
                              ),
                            );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Visual Proportion Bar
        Container(
          height: 12,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: surfaceColor,
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              if (needsPercent > 0)
                Expanded(
                  flex: needsPercent.toInt().clamp(1, 100),
                  child: Container(color: const Color(0xFFFF5252)),
                ),
              if (wantsPercent > 0)
                Expanded(
                  flex: wantsPercent.toInt().clamp(1, 100),
                  child: Container(color: const Color(0xFF7C4DFF)),
                ),
              if (savingsPercent > 0)
                Expanded(
                  flex: savingsPercent.toInt().clamp(1, 100),
                  child: Container(color: const Color(0xFF00C087)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 1. Needs & Living Essentials Card
        _buildAllocationBucketCard(
          title: '🏠 Needs & Essential Living Costs',
          percentage: needsPercent,
          amount: needsAmount,
          color: const Color(0xFFFF5252),
          description: 'Non-negotiable living essentials: Housing/Rent, Utilities, Food & Groceries, Transport, and Healthcare.',
          guideline: 'International Rule Target: ~50% of take-home pay',
          surfaceColor: surfaceColor,
          borderColor: borderColor,
          textPrimary: textPrimary,
          textMuted: textMuted,
        ),
        const SizedBox(height: 12),

        // 2. Wants & Discretionary Lifestyle Card
        _buildAllocationBucketCard(
          title: '🎯 Wants & Discretionary Lifestyle',
          percentage: wantsPercent,
          amount: wantsAmount,
          color: const Color(0xFF7C4DFF),
          description: 'Quality of life & personal leisure: Dining out, Entertainment, Hobbies, Shopping, Travel, and Subscriptions.',
          guideline: 'International Rule Target: ~30% of take-home pay',
          surfaceColor: surfaceColor,
          borderColor: borderColor,
          textPrimary: textPrimary,
          textMuted: textMuted,
        ),
        const SizedBox(height: 12),

        // 3. Bank Savings, Emergency Reserves & Debt Payoff Card
        _buildAllocationBucketCard(
          title: '🛡️ Bank Savings & Emergency Buffer',
          percentage: savingsPercent,
          amount: savingsAmount,
          color: const Color(0xFF00C087),
          description: 'Financial security & reserves: Liquid bank savings, 3-6 month emergency fund, High-Yield Deposits, and debt reduction.',
          guideline: 'International Rule Target: Minimum 20% of take-home pay',
          surfaceColor: surfaceColor,
          borderColor: borderColor,
          textPrimary: textPrimary,
          textMuted: textMuted,
        ),
        const SizedBox(height: 16),

        // Emergency Buffer Runway Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.gold.withAlpha(90)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.shield_outlined, color: AppColors.gold, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recommended 6-Month Emergency Buffer',
                      style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _lkr(needsAmount * 6),
                      style: const TextStyle(color: AppColors.gold, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'International personal finance standards recommend holding 6 months of essential living costs in your primary bank account before making high-risk investments.',
                      style: TextStyle(color: textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildRuleChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF9D7CFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF9D7CFF) : const Color(0xFF9D7CFF).withAlpha(90),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF9D7CFF),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildAllocationBucketCard({
    required String title,
    required double percentage,
    required double amount,
    required Color color,
    required String description,
    String? guideline,
    required Color surfaceColor,
    required Color borderColor,
    required Color textPrimary,
    required Color textMuted,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 13.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${percentage.toStringAsFixed(0)}%', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _lkr(amount),
            style: TextStyle(color: color, fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(description, style: TextStyle(color: textMuted, fontSize: 12)),
          if (guideline != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withAlpha(20),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                guideline,
                style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // TAB 3: MONTHLY COMPARATIVE REPORTS & INSIGHTS
  // ==========================================
  Widget _buildReportsTab(
    BuildContext context,
    BankBudgetSummary summary,
    bool isDark,
    Color surfaceColor,
    Color surfaceLight,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
  ) {
    if (summary.monthlyReports.isEmpty) {
      return Center(
        child: Text('No historical monthly records to generate reports.', style: TextStyle(color: textMuted)),
      );
    }

    // Determine currently selected month for single-month inspection
    final activeYm = _selectedReportYm ?? summary.monthlyReports.first.yearMonth;
    final selectedReport = summary.monthlyReports.firstWhere(
      (r) => r.yearMonth == activeYm,
      orElse: () => summary.monthlyReports.first,
    );

    // Dynamic Effective Report based on Horizon Scope (Monthly, Quarterly, Half-Year, All-Time)
    final effectiveReport = _getEffectiveReport(summary, selectedReport);

    // Find previous month's report to compute expense changes
    final currIndex = summary.monthlyReports.indexOf(selectedReport);
    final MonthlyCashflowReport? prevReport = (currIndex >= 0 && currIndex + 1 < summary.monthlyReports.length)
        ? summary.monthlyReports[currIndex + 1]
        : null;

    final peakIn = summary.peakIncomeMonth;
    final peakEx = summary.peakExpenseMonth;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. Time Horizon Scope Selector Tabs (Monthly vs Quarterly vs 6M vs All-Time)
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: surfaceLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              _buildScopeTab('MONTHLY', 'Monthly Audit'),
              _buildScopeTab('QUARTERLY', 'Last 3M (QTR)'),
              _buildScopeTab('HALF_YEAR', 'Last 6M'),
              _buildScopeTab('ALL_TIME', 'All-Time'),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 2. Month Selector Pill Carousel (when in Monthly mode) & Statement Audit Actions
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                _reportScope == 'MONTHLY' ? 'Audit Month: ${effectiveReport.displayName}' : 'Aggregated: ${effectiveReport.displayName}',
                style: TextStyle(color: textPrimary, fontSize: 13.5, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => _showAuditStatementModal(context, effectiveReport, summary),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3861FB).withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF3861FB).withAlpha(60)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long_rounded, color: Color(0xFF3861FB), size: 12),
                        SizedBox(width: 4),
                        Text(
                          'View Audit Sheet',
                          style: TextStyle(color: Color(0xFF3861FB), fontSize: 10.5, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => _copyMonthlyAuditStatement(context, effectiveReport),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary.withAlpha(60)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.copy_rounded, color: AppColors.primary, size: 12),
                        SizedBox(width: 4),
                        Text(
                          'Copy Statement',
                          style: TextStyle(color: AppColors.primary, fontSize: 10.5, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),

        if (_reportScope == 'MONTHLY') ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: summary.monthlyReports.length,
              separatorBuilder: (_, index) => const SizedBox(width: 8),
              itemBuilder: (ctx, idx) {
                final r = summary.monthlyReports[idx];
                final isSelected = r.yearMonth == selectedReport.yearMonth;
                return InkWell(
                  onTap: () => setState(() => _selectedReportYm = r.yearMonth),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : surfaceColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isSelected ? AppColors.primary : borderColor),
                    ),
                    child: Center(
                      child: Text(
                        r.displayName,
                        style: TextStyle(
                          color: isSelected ? Colors.black : textPrimary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 16),

        // 3. Executive Financial Health Score & KPIs Card
        _buildFinancialKpiGrid(
          report: effectiveReport,
          currentBalance: summary.currentBalance,
          surfaceColor: surfaceColor,
          surfaceLight: surfaceLight,
          borderColor: borderColor,
          textPrimary: textPrimary,
          textMuted: textMuted,
          isDark: isDark,
        ),
        const SizedBox(height: 16),

        // 4. Freedom Runway & Emergency Fund Milestone Progress Card
        _buildFreedomRunwayMilestoneCard(
          summary: summary,
          effectiveReport: effectiveReport,
          surfaceColor: surfaceColor,
          surfaceLight: surfaceLight,
          borderColor: borderColor,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          textMuted: textMuted,
        ),
        const SizedBox(height: 16),

        // 5. Category Expense Distribution Donut / Pie Chart
        Container(
          padding: const EdgeInsets.all(16),
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
                    child: Text(
                      '${effectiveReport.displayName} Category Spending Allocation',
                      style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 13.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${effectiveReport.expenseByCategory.length} Categories',
                      style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildCategoryPieChart(
                categoryMap: effectiveReport.expenseByCategory,
                totalAmount: effectiveReport.totalExpense,
                isDark: isDark,
                textPrimary: textPrimary,
                textMuted: textMuted,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 6. Category Spending Spike & Anomaly Detection Radar
        _buildSpendingSpikeAnomalyCard(
          currentReport: effectiveReport,
          prevReport: prevReport,
          surfaceColor: surfaceColor,
          surfaceLight: surfaceLight,
          borderColor: borderColor,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          textMuted: textMuted,
        ),
        const SizedBox(height: 16),

        // 7. Interactive Financial Scenario & Wealth Growth Simulator
        _buildScenarioSimulatorCard(
          report: effectiveReport,
          currentBalance: summary.currentBalance,
          surfaceColor: surfaceColor,
          surfaceLight: surfaceLight,
          borderColor: borderColor,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          textMuted: textMuted,
        ),
        const SizedBox(height: 16),

        // 8. Budget Plan vs Actual Variance Analysis
        _buildPlanVsActualVarianceCard(
          report: effectiveReport,
          plan: summary.plan,
          surfaceColor: surfaceColor,
          surfaceLight: surfaceLight,
          borderColor: borderColor,
          textPrimary: textPrimary,
          textMuted: textMuted,
        ),
        const SizedBox(height: 16),

        // 9. Automated AI Financial Intelligence & Actionable Insights
        _buildSmartAuditInsightsCard(
          report: effectiveReport,
          prevReport: prevReport,
          summary: summary,
          surfaceColor: surfaceColor,
          borderColor: borderColor,
          textPrimary: textPrimary,
          textMuted: textMuted,
        ),
        const SizedBox(height: 16),

        // 10. Month-Wise Deep Dive Audit Card (High Expense Breakdown)
        _buildMonthDeepDiveAuditCard(
          selectedReport: selectedReport,
          prevReport: prevReport,
          surfaceColor: surfaceColor,
          surfaceLight: surfaceLight,
          borderColor: borderColor,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          textMuted: textMuted,
          isDark: isDark,
        ),
        const SizedBox(height: 20),

        // 11. Month-over-Month Bar Chart
        Container(
          padding: const EdgeInsets.all(16),
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
                    child: Text(
                      'Income vs Expense Trend',
                      style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 13.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildChartLegend('Income', AppColors.profit),
                      const SizedBox(width: 8),
                      _buildChartLegend('Expense', AppColors.loss),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 180,
                child: _buildMonthlyBarChart(summary.monthlyReports.take(6).toList().reversed.toList(), isDark),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // 12. All-Time Peak Records
        Row(
          children: [
            Expanded(
              child: _buildPeakHighlightCard(
                title: 'HIGHEST INCOME MONTH',
                month: peakIn != null ? peakIn.displayName : 'N/A',
                amount: peakIn != null ? peakIn.totalIncome : 0.0,
                color: AppColors.profit,
                icon: Icons.emoji_events_rounded,
                topBreakdown: peakIn?.incomeByCategory.entries.firstOrNull != null
                    ? '${peakIn!.incomeByCategory.entries.first.key} (${_lkr(peakIn.incomeByCategory.entries.first.value)})'
                    : 'No details',
                surfaceColor: surfaceColor,
                borderColor: borderColor,
                textPrimary: textPrimary,
                textMuted: textMuted,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildPeakHighlightCard(
                title: 'HIGHEST EXPENSE MONTH',
                month: peakEx != null ? peakEx.displayName : 'N/A',
                amount: peakEx != null ? peakEx.totalExpense : 0.0,
                color: AppColors.loss,
                icon: Icons.warning_amber_rounded,
                topBreakdown: peakEx?.expenseByCategory.entries.firstOrNull != null
                    ? '${peakEx!.expenseByCategory.entries.first.key} (${_lkr(peakEx.expenseByCategory.entries.first.value)})'
                    : 'No details',
                surfaceColor: surfaceColor,
                borderColor: borderColor,
                textPrimary: textPrimary,
                textMuted: textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  /// Detailed Month Audit Card showing exactly which expenses were highest
  Widget _buildMonthDeepDiveAuditCard({
    required MonthlyCashflowReport selectedReport,
    required MonthlyCashflowReport? prevReport,
    required Color surfaceColor,
    required Color surfaceLight,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color textMuted,
    required bool isDark,
  }) {
    // Sort expenses from highest to lowest
    final sortedExpenses = selectedReport.expenseByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Sort income from highest to lowest
    final sortedIncomes = selectedReport.incomeByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final MapEntry<String, double>? topExpense = sortedExpenses.firstOrNull;
    final double topExpensePercent = (topExpense != null && selectedReport.totalExpense > 0)
        ? (topExpense.value / selectedReport.totalExpense) * 100
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month Header & Net Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${selectedReport.displayName} Expense Audit',
                      style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Full Breakdown & Category Spending Analysis',
                      style: TextStyle(color: textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: selectedReport.netCashflow >= 0 ? AppColors.profit.withAlpha(25) : AppColors.loss.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${selectedReport.netCashflow >= 0 ? "+" : ""}${_lkr(selectedReport.netCashflow)}',
                  style: TextStyle(
                    color: selectedReport.netCashflow >= 0 ? AppColors.profit : AppColors.loss,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Mini Monthly Cashflow Metric Strip
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF101217) : const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Month Inflow', style: TextStyle(color: textMuted, fontSize: 10)),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text('+${_lkr(selectedReport.totalIncome)}',
                            style: const TextStyle(color: AppColors.profit, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Month Outflow', style: TextStyle(color: textMuted, fontSize: 10)),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text('-${_lkr(selectedReport.totalExpense)}',
                            style: const TextStyle(color: AppColors.loss, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Savings Rate', style: TextStyle(color: textMuted, fontSize: 10)),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text('${selectedReport.savingsRate.toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: selectedReport.savingsRate >= 20 ? AppColors.profit : Colors.amber,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            )),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // #1 Highest Expense Highlight Banner
          if (topExpense != null && selectedReport.totalExpense > 0) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.loss.withAlpha(18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.loss.withAlpha(45)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.loss.withAlpha(35),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.priority_high_rounded, color: AppColors.loss, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'HIGHEST EXPENSE THIS MONTH',
                          style: const TextStyle(color: AppColors.loss, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${topExpense.key}: ${_lkr(topExpense.value)} (${topExpensePercent.toStringAsFixed(1)}% of total)',
                          style: TextStyle(color: textPrimary, fontSize: 12.5, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Ranked Expense Categories (Highest to Lowest)
          Text('Expense Categories (Ranked Highest to Lowest):',
              style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          if (sortedExpenses.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('No expenses recorded for this month.', style: TextStyle(color: textMuted, fontSize: 12)),
            )
          else
            ...sortedExpenses.asMap().entries.map((mapEntry) {
              final rank = mapEntry.key + 1;
              final entry = mapEntry.value;
              final percent = selectedReport.totalExpense > 0 ? (entry.value / selectedReport.totalExpense) * 100 : 0.0;

              // Compare against previous month for this category
              String? growthLabel;
              Color growthColor = textMuted;
              if (prevReport != null) {
                final prevVal = prevReport.expenseByCategory[entry.key];
                if (prevVal != null) {
                  final diff = entry.value - prevVal;
                  final diffPercent = prevVal > 0 ? (diff / prevVal) * 100 : 0.0;
                  if (diff > 0) {
                    growthLabel = '+${diffPercent.toStringAsFixed(1)}% (+${_lkr(diff)}) higher than ${prevReport.displayName} 🔺';
                    growthColor = AppColors.loss;
                  } else if (diff < 0) {
                    growthLabel = '-${diffPercent.abs().toStringAsFixed(1)}% (-${_lkr(diff.abs())}) saved vs ${prevReport.displayName} 🔻';
                    growthColor = AppColors.profit;
                  }
                } else {
                  growthLabel = '✨ New expense this month';
                  growthColor = Colors.orange;
                }
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF14171E) : surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor.withAlpha(60)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: rank == 1
                                ? AppColors.loss.withAlpha(40)
                                : (rank == 2 ? Colors.orange.withAlpha(40) : Colors.grey.withAlpha(40)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('#$rank',
                              style: TextStyle(
                                color: rank == 1 ? AppColors.loss : (rank == 2 ? Colors.orange : textPrimary),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              )),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(entry.key,
                              style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        Text(_lkr(entry.value),
                            style: const TextStyle(color: AppColors.loss, fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: selectedReport.totalExpense > 0 ? (entry.value / selectedReport.totalExpense).clamp(0.0, 1.0) : 0.0,
                        backgroundColor: Colors.grey.withAlpha(40),
                        valueColor: AlwaysStoppedAnimation(
                          rank == 1 ? AppColors.loss : (rank == 2 ? Colors.orange : const Color(0xFF3861FB)),
                        ),
                        minHeight: 5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text('${percent.toStringAsFixed(1)}% of total spending',
                              style: TextStyle(color: textMuted, fontSize: 10.5),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (growthLabel != null) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(growthLabel,
                                style: TextStyle(color: growthColor, fontSize: 10, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              );
            }),

          // Income Sources Breakdown for Selected Month
          if (sortedIncomes.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('Income Streams in ${selectedReport.displayName}:',
                style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: sortedIncomes.map((entry) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.profit.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.profit.withAlpha(40)),
                  ),
                  child: Text(
                    '${entry.key}: ${_lkr(entry.value)}',
                    style: const TextStyle(color: AppColors.profit, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPeakHighlightCard({
    required String title,
    required String month,
    required double amount,
    required Color color,
    required IconData icon,
    required String topBreakdown,
    required Color surfaceColor,
    required Color borderColor,
    required Color textPrimary,
    required Color textMuted,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(title, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(month, style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(_lkr(amount), style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 6),
          Text('Top: $topBreakdown', style: TextStyle(color: textMuted, fontSize: 10), maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildChartLegend(String label, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildMonthlyBarChart(List<MonthlyCashflowReport> reports, bool isDark) {
    if (reports.isEmpty) return const SizedBox.shrink();

    final maxVal = reports.fold<double>(1.0, (prev, r) {
      final high = r.totalIncome > r.totalExpense ? r.totalIncome : r.totalExpense;
      return high > prev ? high : prev;
    });

    final barGroups = <BarChartGroupData>[];

    for (int i = 0; i < reports.length; i++) {
      final r = reports[i];
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: r.totalIncome,
              color: AppColors.profit,
              width: 9,
              borderRadius: BorderRadius.circular(4),
            ),
            BarChartRodData(
              toY: r.totalExpense,
              color: AppColors.loss,
              width: 9,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxVal * 1.15,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final r = reports[group.x];
              final isIncomeRod = rodIndex == 0;
              return BarTooltipItem(
                '${r.displayName}\n${isIncomeRod ? "Income" : "Expense"}: Rs. ${rod.toY.toStringAsFixed(2)}',
                const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx >= 0 && idx < reports.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      reports[idx].yearMonth.split('-').last,
                      style: const TextStyle(color: Colors.grey, fontSize: 10),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: barGroups,
      ),
    );
  }

  // ==========================================
  // ADVANCED REPORTS & KPIS HELPER WIDGETS
  // ==========================================

  static const List<Color> _categoryColors = [
    Color(0xFF3861FB), // Blue
    Color(0xFFF59E0B), // Amber
    Color(0xFFEF4444), // Coral Red
    Color(0xFF10B981), // Emerald Green
    Color(0xFF8B5CF6), // Purple
    Color(0xFFEC4899), // Pink
    Color(0xFF06B6D4), // Cyan
    Color(0xFFF97316), // Orange
    Color(0xFF64748B), // Slate
  ];

  Widget _buildCategoryPieChart({
    required Map<String, double> categoryMap,
    required double totalAmount,
    required bool isDark,
    required Color textPrimary,
    required Color textMuted,
  }) {
    if (categoryMap.isEmpty || totalAmount <= 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text('No expense distribution recorded for this month.', style: TextStyle(color: textMuted, fontSize: 12)),
        ),
      );
    }

    final sorted = categoryMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final sections = <PieChartSectionData>[];

    for (int i = 0; i < sorted.length; i++) {
      final entry = sorted[i];
      final color = _categoryColors[i % _categoryColors.length];
      final pct = (entry.value / totalAmount) * 100;

      sections.add(
        PieChartSectionData(
          color: color,
          value: entry.value,
          title: pct >= 8 ? '${pct.toStringAsFixed(0)}%' : '',
          radius: 46,
          titleStyle: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 190,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 48,
                  sectionsSpace: 2.5,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('TOTAL OUTFLOW', style: TextStyle(color: textMuted, fontSize: 8.5, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        _lkr(totalAmount),
                        style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: sorted.asMap().entries.map((mapEntry) {
            final idx = mapEntry.key;
            final entry = mapEntry.value;
            final color = _categoryColors[idx % _categoryColors.length];
            final pct = (entry.value / totalAmount) * 100;

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text(
                  '${entry.key} (${pct.toStringAsFixed(1)}%)',
                  style: TextStyle(color: textPrimary, fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFinancialKpiGrid({
    required MonthlyCashflowReport report,
    required double currentBalance,
    required Color surfaceColor,
    required Color surfaceLight,
    required Color borderColor,
    required Color textPrimary,
    required Color textMuted,
    required bool isDark,
  }) {
    // Health Grade
    final savingsRate = report.savingsRate;
    String healthGrade;
    String healthLabel;
    Color healthColor;

    if (savingsRate >= 35) {
      healthGrade = 'A+';
      healthLabel = 'Elite Saver';
      healthColor = AppColors.profit;
    } else if (savingsRate >= 25) {
      healthGrade = 'A';
      healthLabel = 'Strong';
      healthColor = AppColors.profit;
    } else if (savingsRate >= 15) {
      healthGrade = 'B';
      healthLabel = 'Balanced';
      healthColor = const Color(0xFF3861FB);
    } else if (savingsRate >= 5) {
      healthGrade = 'C';
      healthLabel = 'Tight Margin';
      healthColor = Colors.amber;
    } else {
      healthGrade = 'D';
      healthLabel = 'Deficit Spend';
      healthColor = AppColors.loss;
    }

    // Emergency Runway
    final monthlyBurn = report.totalExpense > 0 ? report.totalExpense : 1.0;
    final runwayMonths = currentBalance / monthlyBurn;
    Color runwayColor = runwayMonths >= 6
        ? AppColors.profit
        : (runwayMonths >= 3 ? Colors.amber : AppColors.loss);

    // Daily Burn
    final dailyBurn = report.totalExpense / 30.0;

    // Investment Ratio
    final investRatio = report.totalIncome > 0
        ? (report.totalInvested / report.totalIncome) * 100
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
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
                child: Text(
                  'Monthly Financial Health & KPIs',
                  style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 13.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: healthColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: healthColor.withAlpha(80), width: 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Grade $healthGrade',
                        style: TextStyle(color: healthColor, fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 4),
                    Text('($healthLabel)',
                        style: TextStyle(color: healthColor, fontSize: 10, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildKpiTile(
                  title: 'EMERGENCY RUNWAY',
                  value: '${runwayMonths.toStringAsFixed(1)} Mo',
                  subtitle: currentBalance >= monthlyBurn * 3 ? 'Safe liquid buffer' : 'Low liquid buffer',
                  color: runwayColor,
                  icon: Icons.shield_outlined,
                  surfaceLight: surfaceLight,
                  textPrimary: textPrimary,
                  textMuted: textMuted,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildKpiTile(
                  title: 'DAILY BURN RATE',
                  value: _lkr(dailyBurn),
                  subtitle: 'Avg expense / day',
                  color: AppColors.loss,
                  icon: Icons.local_fire_department_outlined,
                  surfaceLight: surfaceLight,
                  textPrimary: textPrimary,
                  textMuted: textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildKpiTile(
                  title: 'NET SAVINGS RATE',
                  value: '${savingsRate.toStringAsFixed(1)}%',
                  subtitle: savingsRate >= 20 ? 'Target achieved' : 'Below 20% target',
                  color: savingsRate >= 20 ? AppColors.profit : Colors.amber,
                  icon: Icons.savings_outlined,
                  surfaceLight: surfaceLight,
                  textPrimary: textPrimary,
                  textMuted: textMuted,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildKpiTile(
                  title: 'INVESTMENT INFLOW',
                  value: '${investRatio.toStringAsFixed(1)}%',
                  subtitle: '${_lkr(report.totalInvested)} placed',
                  color: const Color(0xFF3861FB),
                  icon: Icons.trending_up_rounded,
                  surfaceLight: surfaceLight,
                  textPrimary: textPrimary,
                  textMuted: textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiTile({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
    required Color surfaceLight,
    required Color textPrimary,
    required Color textMuted,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: textMuted, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(color: textMuted, fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPlanVsActualVarianceCard({
    required MonthlyCashflowReport report,
    required MonthlyBudgetPlanModel plan,
    required Color surfaceColor,
    required Color surfaceLight,
    required Color borderColor,
    required Color textPrimary,
    required Color textMuted,
  }) {
    final income = report.totalIncome > 0 ? report.totalIncome : 1.0;
    final actualNeedsPct = (report.totalExpense / income) * 100;
    final actualSavingsPct = report.savingsRate;
    final actualInvestPct = (report.totalInvested / income) * 100;

    final targetNeeds = plan.expensesPercentage;
    final targetSavings = plan.savingsPercentage;
    final targetInvest = plan.cryptoPercentage + plan.otherInvestPercentage;

    return Container(
      padding: const EdgeInsets.all(16),
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
                child: Text(
                  'Budget Plan vs. Actual Variance',
                  style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 13.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text('Target vs ${report.displayName}',
                  style: TextStyle(color: textMuted, fontSize: 10.5)),
            ],
          ),
          const SizedBox(height: 14),
          _buildVarianceRow(
            title: 'Needs & Living Expenses',
            targetPct: targetNeeds,
            actualPct: actualNeedsPct,
            targetAmount: report.totalIncome * (targetNeeds / 100),
            actualAmount: report.totalExpense,
            isExpenseType: true,
            textPrimary: textPrimary,
            textMuted: textMuted,
          ),
          const SizedBox(height: 12),
          _buildVarianceRow(
            title: 'Liquid Savings Buffer',
            targetPct: targetSavings,
            actualPct: actualSavingsPct,
            targetAmount: report.totalIncome * (targetSavings / 100),
            actualAmount: (report.totalIncome - report.totalExpense).clamp(0, double.infinity),
            isExpenseType: false,
            textPrimary: textPrimary,
            textMuted: textMuted,
          ),
          const SizedBox(height: 12),
          _buildVarianceRow(
            title: 'Investments & Crypto DCA',
            targetPct: targetInvest,
            actualPct: actualInvestPct,
            targetAmount: report.totalIncome * (targetInvest / 100),
            actualAmount: report.totalInvested,
            isExpenseType: false,
            textPrimary: textPrimary,
            textMuted: textMuted,
          ),
        ],
      ),
    );
  }

  Widget _buildVarianceRow({
    required String title,
    required double targetPct,
    required double actualPct,
    required double targetAmount,
    required double actualAmount,
    required bool isExpenseType,
    required Color textPrimary,
    required Color textMuted,
  }) {
    final diffPct = actualPct - targetPct;
    final bool isFavorable = isExpenseType ? diffPct <= 0 : diffPct >= 0;
    final Color statusColor = isFavorable ? AppColors.profit : AppColors.loss;
    final String statusText = isExpenseType
        ? (diffPct <= 0 ? 'Under by ${diffPct.abs().toStringAsFixed(1)}%' : 'Over by +${diffPct.toStringAsFixed(1)}%')
        : (diffPct >= 0 ? 'Exceeded by +${diffPct.toStringAsFixed(1)}%' : 'Under by ${diffPct.abs().toStringAsFixed(1)}%');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(color: textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withAlpha(20),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(statusText,
                  style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                'Target: ${targetPct.toStringAsFixed(0)}% (${_lkr(targetAmount)})',
                style: TextStyle(color: textMuted, fontSize: 10.5),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Actual: ${actualPct.toStringAsFixed(1)}% (${_lkr(actualAmount)})',
                style: TextStyle(color: textPrimary, fontSize: 10.5, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: (actualPct / 100).clamp(0.0, 1.0),
            backgroundColor: Colors.grey.withAlpha(35),
            valueColor: AlwaysStoppedAnimation(statusColor),
            minHeight: 5,
          ),
        ),
      ],
    );
  }

  Widget _buildSmartAuditInsightsCard({
    required MonthlyCashflowReport report,
    required MonthlyCashflowReport? prevReport,
    required BankBudgetSummary summary,
    required Color surfaceColor,
    required Color borderColor,
    required Color textPrimary,
    required Color textMuted,
  }) {
    final insights = <Widget>[];

    // Top Expense Insight
    final topEntry = report.expenseByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (topEntry.isNotEmpty && report.totalExpense > 0) {
      final pct = (topEntry.first.value / report.totalExpense) * 100;
      insights.add(
        _buildInsightBullet(
          icon: Icons.pie_chart_outline,
          color: Colors.amber,
          title: 'Primary Spending Driver',
          description: '${topEntry.first.key} represented ${pct.toStringAsFixed(1)}% of total monthly expenses (${_lkr(topEntry.first.value)}).',
          textPrimary: textPrimary,
          textMuted: textMuted,
        ),
      );
    }

    // Savings Rate Insight
    if (report.totalIncome > 0) {
      final isGreat = report.savingsRate >= 20;
      insights.add(
        _buildInsightBullet(
          icon: isGreat ? Icons.check_circle_outline : Icons.info_outline,
          color: isGreat ? AppColors.profit : Colors.orange,
          title: isGreat ? 'Healthy Wealth Accumulation' : 'Savings Buffer Advisory',
          description: isGreat
              ? 'Your savings rate of ${report.savingsRate.toStringAsFixed(1)}% exceeds standard recommended 20% benchmark.'
              : 'Savings rate is ${report.savingsRate.toStringAsFixed(1)}%. Trimming non-essential discretionary spending by 5-10% will rebuild reserves.',
          textPrimary: textPrimary,
          textMuted: textMuted,
        ),
      );
    }

    // Month-over-Month comparison
    if (prevReport != null) {
      final expDiff = report.totalExpense - prevReport.totalExpense;
      final isSaved = expDiff <= 0;
      insights.add(
        _buildInsightBullet(
          icon: isSaved ? Icons.trending_down_rounded : Icons.trending_up_rounded,
          color: isSaved ? AppColors.profit : AppColors.loss,
          title: 'Month-over-Month Trajectory',
          description: isSaved
              ? 'You reduced total outflow by ${_lkr(expDiff.abs())} compared to ${prevReport.displayName}. Excellent discipline!'
              : 'Outflow grew by +${_lkr(expDiff)} compared to ${prevReport.displayName}. Review top category increases above.',
          textPrimary: textPrimary,
          textMuted: textMuted,
        ),
      );
    }

    // Runway Insight
    final monthlyBurn = report.totalExpense > 0 ? report.totalExpense : 1.0;
    final runway = summary.currentBalance / monthlyBurn;
    insights.add(
      _buildInsightBullet(
        icon: Icons.security_rounded,
        color: runway >= 3 ? const Color(0xFF3861FB) : AppColors.loss,
        title: 'Emergency Reserve Assessment',
        description: runway >= 6
            ? 'Liquid bank reserves provide a robust ${runway.toStringAsFixed(1)} months runway of living costs.'
            : (runway >= 3
                ? 'Current liquid reserves cover ${runway.toStringAsFixed(1)} months. Aiming for 6 months (${_lkr(monthlyBurn * 6)}) provides total security.'
                : 'Current liquid balance only covers ${runway.toStringAsFixed(1)} months. Prioritize building emergency fund.'),
        textPrimary: textPrimary,
        textMuted: textMuted,
      ),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.primary, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Smart Financial Intelligence & Insights',
                  style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 13.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...insights,
        ],
      ),
    );
  }

  Widget _buildInsightBullet({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
    required Color textPrimary,
    required Color textMuted,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(description, style: TextStyle(color: textMuted, fontSize: 11, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _copyMonthlyAuditStatement(BuildContext context, MonthlyCashflowReport report) {
    final buffer = StringBuffer();
    buffer.writeln('📊 MONTHLY FINANCIAL AUDIT STATEMENT (${report.displayName})');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('💰 Total Inflow: ${_lkr(report.totalIncome)}');
    buffer.writeln('💸 Total Outflow: ${_lkr(report.totalExpense)}');
    buffer.writeln('📈 Investment Outflow: ${_lkr(report.totalInvested)}');
    buffer.writeln('💎 Net Retained Cashflow: ${_lkr(report.netCashflow)}');
    buffer.writeln('🛡️ Net Savings Rate: ${report.savingsRate.toStringAsFixed(1)}%');
    buffer.writeln('\n📂 EXPENSE CATEGORIES BREAKDOWN:');
    final sortedExp = report.expenseByCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    for (final e in sortedExp) {
      final pct = report.totalExpense > 0 ? (e.value / report.totalExpense) * 100 : 0.0;
      buffer.writeln('• ${e.key}: ${_lkr(e.value)} (${pct.toStringAsFixed(1)}%)');
    }
    if (report.incomeByCategory.isNotEmpty) {
      buffer.writeln('\n💵 INFLOW STREAMS:');
      for (final e in report.incomeByCategory.entries) {
        buffer.writeln('• ${e.key}: ${_lkr(e.value)}');
      }
    }
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('Generated via Crypto Asset Manager • Bank, Salary & Budget Hub');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📋 ${report.displayName} Financial Audit Statement copied to clipboard!'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildScopeTab(String scopeKey, String label) {
    final isSelected = _reportScope == scopeKey;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _reportScope = scopeKey),
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.black : Colors.grey,
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  MonthlyCashflowReport _getEffectiveReport(
    BankBudgetSummary summary,
    MonthlyCashflowReport selectedMonthlyReport,
  ) {
    if (_reportScope == 'MONTHLY') return selectedMonthlyReport;

    List<MonthlyCashflowReport> pool;
    String scopeLabel;
    if (_reportScope == 'QUARTERLY') {
      pool = summary.monthlyReports.take(3).toList();
      scopeLabel = 'Trailing 3 Months (QTR)';
    } else if (_reportScope == 'HALF_YEAR') {
      pool = summary.monthlyReports.take(6).toList();
      scopeLabel = 'Trailing 6 Months';
    } else {
      pool = summary.monthlyReports;
      scopeLabel = 'All-Time Financial History';
    }

    if (pool.isEmpty) return selectedMonthlyReport;

    double totalIn = 0;
    double totalEx = 0;
    double totalInv = 0;
    final Map<String, double> expMap = {};
    final Map<String, double> inMap = {};
    final Map<String, double> invMap = {};

    for (final r in pool) {
      totalIn += r.totalIncome;
      totalEx += r.totalExpense;
      totalInv += r.totalInvested;
      r.expenseByCategory.forEach((k, v) => expMap[k] = (expMap[k] ?? 0) + v);
      r.incomeByCategory.forEach((k, v) => inMap[k] = (inMap[k] ?? 0) + v);
      r.investmentByCategory.forEach((k, v) => invMap[k] = (invMap[k] ?? 0) + v);
    }

    return MonthlyCashflowReport(
      yearMonth: scopeLabel,
      totalIncome: totalIn,
      totalExpense: totalEx,
      totalInvested: totalInv,
      incomeByCategory: inMap,
      expenseByCategory: expMap,
      investmentByCategory: invMap,
    );
  }

  Widget _buildFreedomRunwayMilestoneCard({
    required BankBudgetSummary summary,
    required MonthlyCashflowReport effectiveReport,
    required Color surfaceColor,
    required Color surfaceLight,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color textMuted,
  }) {
    final monthsCount = _reportScope == 'QUARTERLY'
        ? 3.0
        : (_reportScope == 'HALF_YEAR'
            ? 6.0
            : (_reportScope == 'ALL_TIME'
                ? (summary.monthlyReports.isNotEmpty ? summary.monthlyReports.length.toDouble() : 1.0)
                : 1.0));

    final double monthlyBurn = effectiveReport.totalExpense > 0
        ? (effectiveReport.totalExpense / monthsCount)
        : (summary.plan.expensesPercentage > 0 ? 50000.0 : 40000.0);

    final tier1Target = monthlyBurn * 3; // 3-Month Essential Living Buffer
    final tier2Target = monthlyBurn * 6; // 6-Month Golden Reserve
    final tier3Target = monthlyBurn * 12; // 1-Year Financial Freedom

    final currentBal = summary.currentBalance;

    String tierName;
    Color tierColor;
    double progress;
    String statusNote;

    if (currentBal >= tier3Target) {
      tierName = '🥇 Tier 3: 1-Year Financial Independence';
      tierColor = const Color(0xFF00E676);
      progress = 1.0;
      statusNote = 'Outstanding! You can sustain full living costs for over a year without any income.';
    } else if (currentBal >= tier2Target) {
      tierName = '🥈 Tier 2: 6-Month Golden Reserve';
      tierColor = const Color(0xFF3861FB);
      progress = (currentBal / tier3Target).clamp(0.0, 1.0);
      statusNote = 'Rock-solid defense! Need ${_lkr(tier3Target - currentBal)} to unlock Tier 3 (1-Year buffer).';
    } else if (currentBal >= tier1Target) {
      tierName = '🥉 Tier 1: 3-Month Essential Living Buffer';
      tierColor = const Color(0xFFF59E0B);
      progress = (currentBal / tier2Target).clamp(0.0, 1.0);
      statusNote = 'Standard safety net. Need ${_lkr(tier2Target - currentBal)} to reach Tier 2 (6-Month Reserve).';
    } else {
      tierName = '🛡️ Starter Reserve Phase';
      tierColor = AppColors.loss;
      progress = tier1Target > 0 ? (currentBal / tier1Target).clamp(0.0, 1.0) : 0.0;
      statusNote = 'Vulnerable to income shocks. Need ${_lkr((tier1Target - currentBal).clamp(0, double.infinity))} to reach Tier 1 safety.';
    }

    return Container(
      padding: const EdgeInsets.all(16),
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
                child: Row(
                  children: [
                    const Icon(Icons.shield_rounded, color: AppColors.primary, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Freedom Runway & Reserve Milestones',
                        style: TextStyle(color: textPrimary, fontSize: 13.5, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: tierColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: tierColor.withAlpha(80), width: 0.8),
                ),
                child: Text(
                  tierName.split(':').first,
                  style: TextStyle(color: tierColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            tierName,
            style: TextStyle(color: tierColor, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 3),
          Text(
            statusNote,
            style: TextStyle(color: textMuted, fontSize: 11),
          ),
          const SizedBox(height: 12),

          // Progress Bar with Milestone Markers
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: surfaceLight,
              valueColor: AlwaysStoppedAnimation(tierColor),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),

          // 3-Tier Milestone Cards
          Row(
            children: [
              Expanded(
                child: _buildMilestoneTile(
                  tierLabel: '3-Mo Buffer',
                  targetAmount: tier1Target,
                  isAchieved: currentBal >= tier1Target,
                  surfaceLight: surfaceLight,
                  borderColor: borderColor,
                  textPrimary: textPrimary,
                  textMuted: textMuted,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildMilestoneTile(
                  tierLabel: '6-Mo Reserve',
                  targetAmount: tier2Target,
                  isAchieved: currentBal >= tier2Target,
                  surfaceLight: surfaceLight,
                  borderColor: borderColor,
                  textPrimary: textPrimary,
                  textMuted: textMuted,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildMilestoneTile(
                  tierLabel: '12-Mo Freedom',
                  targetAmount: tier3Target,
                  isAchieved: currentBal >= tier3Target,
                  surfaceLight: surfaceLight,
                  borderColor: borderColor,
                  textPrimary: textPrimary,
                  textMuted: textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMilestoneTile({
    required String tierLabel,
    required double targetAmount,
    required bool isAchieved,
    required Color surfaceLight,
    required Color borderColor,
    required Color textPrimary,
    required Color textMuted,
  }) {
    final statusColor = isAchieved ? const Color(0xFF00E676) : textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isAchieved ? statusColor.withAlpha(80) : borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isAchieved ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                size: 11,
                color: statusColor,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  tierLabel,
                  style: TextStyle(color: statusColor, fontSize: 9.5, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _lkr(targetAmount),
              style: TextStyle(color: textPrimary, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpendingSpikeAnomalyCard({
    required MonthlyCashflowReport currentReport,
    required MonthlyCashflowReport? prevReport,
    required Color surfaceColor,
    required Color surfaceLight,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color textMuted,
  }) {
    final items = <Widget>[];

    final sortedCurr = currentReport.expenseByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (final entry in sortedCurr.take(4)) {
      final currVal = entry.value;
      final prevVal = prevReport?.expenseByCategory[entry.key];

      String badgeText;
      Color badgeColor;

      if (prevVal != null && prevVal > 0) {
        final diff = currVal - prevVal;
        final pctDiff = (diff / prevVal) * 100;
        if (pctDiff >= 15.0 && diff >= 3000) {
          badgeText = '🚨 SPIKE: +${pctDiff.toStringAsFixed(1)}% (+${_lkr(diff)})';
          badgeColor = AppColors.loss;
        } else if (pctDiff <= -10.0) {
          badgeText = '✅ REDUCED: ${pctDiff.toStringAsFixed(1)}% (-${_lkr(diff.abs())})';
          badgeColor = const Color(0xFF00E676);
        } else {
          badgeText = 'STABLE (~${pctDiff >= 0 ? "+" : ""}${pctDiff.toStringAsFixed(1)}%)';
          badgeColor = textMuted;
        }
      } else {
        final share = currentReport.totalExpense > 0 ? (currVal / currentReport.totalExpense) * 100 : 0.0;
        badgeText = '${share.toStringAsFixed(1)}% share of wallet';
        badgeColor = const Color(0xFF3861FB);
      }

      items.add(
        Container(
          margin: const EdgeInsets.only(bottom: 7),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: surfaceLight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.key,
                      style: TextStyle(color: textPrimary, fontSize: 12.5, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      badgeText,
                      style: TextStyle(color: badgeColor, fontSize: 10.5, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _lkr(currVal),
                style: TextStyle(color: textPrimary, fontSize: 12.5, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
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
                child: Row(
                  children: [
                    const Icon(Icons.radar_rounded, color: Color(0xFFF59E0B), size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Category Spending Spike Radar',
                        style: TextStyle(color: textPrimary, fontSize: 13.5, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withAlpha(20),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('AUTO ANOMALY',
                    style: TextStyle(color: Color(0xFFF59E0B), fontSize: 9.5, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Text('No categorized spending recorded.', style: TextStyle(color: textMuted, fontSize: 11))
          else
            ...items,
        ],
      ),
    );
  }

  Widget _buildScenarioSimulatorCard({
    required MonthlyCashflowReport report,
    required double currentBalance,
    required Color surfaceColor,
    required Color surfaceLight,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color textMuted,
  }) {
    final simInflow = report.totalIncome * (1.0 + (_simIncomeBoostPct / 100.0));
    final simExpense = report.totalExpense * (1.0 - (_simExpenseCutPct / 100.0));
    final simNetSavings = (simInflow - simExpense).clamp(0.0, double.infinity);
    final simSavingsRate = simInflow > 0 ? (simNetSavings / simInflow) * 100.0 : 0.0;

    final origSavings = (report.totalIncome - report.totalExpense).clamp(0.0, double.infinity);
    final monthlySurplusGain = (simNetSavings - origSavings).clamp(0.0, double.infinity);
    final annualWealthGain = monthlySurplusGain * 12.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withAlpha(90)),
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
                    const Icon(Icons.insights_rounded, color: AppColors.primary, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'What-If Financial Growth Simulator',
                        style: TextStyle(color: textPrimary, fontSize: 13.5, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('PROJECTION',
                    style: TextStyle(color: AppColors.primary, fontSize: 9.5, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Simulate how trimming discretionary costs or boosting earnings multiplies your bank reserves:',
            style: TextStyle(color: textMuted, fontSize: 11),
          ),
          const SizedBox(height: 12),

          // Expense Cut Chips
          Row(
            children: [
              Expanded(
                child: Text('Cut Expenses:',
                    style: TextStyle(color: textSecondary, fontSize: 11.5, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 6),
              ...[0.0, 10.0, 20.0, 30.0].map((cut) {
                final isSel = (_simExpenseCutPct - cut).abs() < 0.1;
                return Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: InkWell(
                    onTap: () => setState(() => _simExpenseCutPct = cut),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: isSel ? AppColors.loss : surfaceLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '-${cut.toInt()}%',
                        style: TextStyle(
                          color: isSel ? Colors.white : textSecondary,
                          fontSize: 10.5,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 8),

          // Income Boost Chips
          Row(
            children: [
              Expanded(
                child: Text('Boost Earnings:',
                    style: TextStyle(color: textSecondary, fontSize: 11.5, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 6),
              ...[0.0, 5.0, 10.0, 15.0].map((boost) {
                final isSel = (_simIncomeBoostPct - boost).abs() < 0.1;
                return Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: InkWell(
                    onTap: () => setState(() => _simIncomeBoostPct = boost),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: isSel ? const Color(0xFF00E676) : surfaceLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '+${boost.toInt()}%',
                        style: TextStyle(
                          color: isSel ? Colors.black : textSecondary,
                          fontSize: 10.5,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 14),

          // Simulation Results Container
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Extra Monthly Surplus', style: TextStyle(color: textMuted, fontSize: 10)),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '+${_lkr(monthlySurplusGain)} / mo',
                              style: const TextStyle(color: Color(0xFF00E676), fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('1-Year Wealth Added', style: TextStyle(color: textMuted, fontSize: 10)),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              '+${_lkr(annualWealthGain)} / yr',
                              style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Divider(color: borderColor, height: 1),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Optimized Savings Rate:',
                        style: TextStyle(color: textSecondary, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${report.savingsRate.toStringAsFixed(1)}% ➔ ${simSavingsRate.toStringAsFixed(1)}%',
                      style: const TextStyle(color: Color(0xFF00E676), fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAuditStatementModal(
    BuildContext context,
    MonthlyCashflowReport report,
    BankBudgetSummary summary,
  ) {
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final textMuted = AppColors.textMuted(context);
    final surfaceColor = AppColors.surface(context);
    final surfaceLight = AppColors.surfaceLight(context);
    final borderColor = AppColors.border(context);

    final sortedExp = report.expenseByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: surfaceColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) {
        return SafeArea(
          child: Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.88),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.verified_rounded, color: AppColors.primary, size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'FINANCIAL AUDIT STATEMENT',
                                  style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Period: ${report.displayName} • ${summary.account.bankName}',
                            style: TextStyle(color: textMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(color: borderColor, height: 1),
                const SizedBox(height: 14),

                // Key Figures Strip
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total Gross Inflows:', style: TextStyle(color: textSecondary, fontSize: 12)),
                          Text('+${_lkr(report.totalIncome)}', style: const TextStyle(color: AppColors.profit, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total Outflows (Expenses):', style: TextStyle(color: textSecondary, fontSize: 12)),
                          Text('-${_lkr(report.totalExpense)}', style: const TextStyle(color: AppColors.loss, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Investment Transfers:', style: TextStyle(color: textSecondary, fontSize: 12)),
                          Text('-${_lkr(report.totalInvested)}', style: const TextStyle(color: Color(0xFF3861FB), fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                      Divider(color: borderColor, height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Net Retained Surplus:', style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                          Text(
                            '${report.netCashflow >= 0 ? "+" : ""}${_lkr(report.netCashflow)}',
                            style: TextStyle(color: report.netCashflow >= 0 ? AppColors.profit : AppColors.loss, fontSize: 13, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Itemized Category Table Header
                Text('Itemized Category Breakdown:', style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    itemCount: sortedExp.length,
                    separatorBuilder: (_, index) => Divider(color: borderColor.withAlpha(80), height: 1),
                    itemBuilder: (c, i) {
                      final item = sortedExp[i];
                      final pct = report.totalExpense > 0 ? (item.value / report.totalExpense) * 100 : 0.0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(item.key, style: TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.w500)),
                            ),
                            Text('${pct.toStringAsFixed(1)}%', style: TextStyle(color: textMuted, fontSize: 11)),
                            const SizedBox(width: 14),
                            Text(_lkr(item.value), style: TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copy Formatted Audit Statement', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _copyMonthlyAuditStatement(context, report);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // MODALS & DIALOGS
  // ==========================================

  void _showInitialBalanceDialog(BuildContext context, BankAccountModel currentAccount) {
    final balanceController = TextEditingController(
      text: currentAccount.initialBalance > 0
          ? (currentAccount.initialBalance == currentAccount.initialBalance.truncateToDouble()
              ? currentAccount.initialBalance.toStringAsFixed(0)
              : currentAccount.initialBalance.toStringAsFixed(2))
          : '',
    );
    final bankController = TextEditingController(text: currentAccount.bankName);
    final accountNumController = TextEditingController(text: currentAccount.accountNumber);
    bool autoCredit = currentAccount.autoCreditSalary;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Set Starting Bank Balance (LKR)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Enter your initial bank balance in Sri Lankan Rupees down to exact cents (e.g. 150000.75).',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: balanceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Initial Account Balance (Rs.)',
                      hintText: 'e.g. 150250.50',
                      prefixText: 'Rs. ',
                      prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bankController,
                    decoration: const InputDecoration(
                      labelText: 'Bank Name (e.g. Commercial, HNB, Sampath)',
                      prefixIcon: Icon(Icons.account_balance_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: accountNumController,
                    decoration: const InputDecoration(
                      labelText: 'Account Number (Optional)',
                      prefixIcon: Icon(Icons.credit_card_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Auto-Credit Monthly Salary', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    subtitle: const Text('Automatically credits net company salary on your monthly payout date starting next month.',
                        style: TextStyle(fontSize: 11, color: Colors.grey)),
                    value: autoCredit,
                    onChanged: (val) => setModalState(() => autoCredit = val),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                      onPressed: () async {
                        final amt = double.tryParse(balanceController.text.trim()) ?? 0.0;
                        final nextMonthStr = DateFormat('yyyy-MM').format(DateTime(DateTime.now().year, DateTime.now().month + 1, 1));
                        await ref.read(bankBudgetProvider.notifier).setInitialBankBalance(
                              initialBalance: amt,
                              bankName: bankController.text.trim().isNotEmpty ? bankController.text.trim() : 'Commercial Bank',
                              accountNumber: accountNumController.text.trim(),
                              salaryStartMonth: nextMonthStr,
                              autoCreditSalary: autoCredit,
                            );
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('Save Bank Baseline (Rs.)', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAddRecordSheet(BuildContext context, {String defaultType = 'EXPENSE'}) {
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    String selectedType = defaultType; // 'INCOME', 'EXPENSE', 'INVESTMENT_TRANSFER'
    final DateTime selectedDate = DateTime.now();

    final incomeCategories = ['Salary', 'Freelance', 'Bonus', 'Dividend', 'Business Inflow', 'Gift/Other'];
    final expenseCategories = [
      'Food & Dining',
      'Housing & Rent',
      'Utilities & Bills',
      'Transport & Fuel',
      'Healthcare & Medical',
      'Leisure & Shopping',
      'EMI & Debt',
      'Miscellaneous'
    ];
    final investmentCategories = ['Crypto DCA', 'Stock Market (CSE)', 'Fixed Deposit', 'Emergency Fund'];

    String selectedCategory = selectedType == 'INCOME'
        ? incomeCategories.first
        : (selectedType == 'EXPENSE' ? expenseCategories.first : investmentCategories.first);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            List<String> currentCategories = selectedType == 'INCOME'
                ? incomeCategories
                : (selectedType == 'EXPENSE' ? expenseCategories : investmentCategories);

            if (!currentCategories.contains(selectedCategory)) {
              selectedCategory = currentCategories.first;
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Log Cashflow Activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Type Segmented Toggle
                  Row(
                    children: [
                      Expanded(
                        child: _buildTypeSegment('Income', 'INCOME', selectedType, AppColors.profit, () {
                          setModalState(() {
                            selectedType = 'INCOME';
                            selectedCategory = incomeCategories.first;
                          });
                        }),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildTypeSegment('Expense', 'EXPENSE', selectedType, AppColors.loss, () {
                          setModalState(() {
                            selectedType = 'EXPENSE';
                            selectedCategory = expenseCategories.first;
                          });
                        }),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildTypeSegment('Invest', 'INVESTMENT_TRANSFER', selectedType, const Color(0xFF9D7CFF), () {
                          setModalState(() {
                            selectedType = 'INVESTMENT_TRANSFER';
                            selectedCategory = investmentCategories.first;
                          });
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount (Rs.)',
                      hintText: 'e.g. 2450.50 (with cents)',
                      prefixText: 'Rs. ',
                      prefixIcon: Icon(Icons.money_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      prefixIcon: Icon(Icons.category_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: currentCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedCategory = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes (Optional description)',
                      prefixIcon: Icon(Icons.edit_note_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                      onPressed: () async {
                        final amt = double.tryParse(amountController.text.trim()) ?? 0.0;
                        if (amt <= 0) return;

                        await ref.read(bankBudgetProvider.notifier).addCashRecord(
                              type: selectedType,
                              category: selectedCategory,
                              amount: amt,
                              recordDate: selectedDate,
                              notes: notesController.text.trim(),
                            );

                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('Save Record (Rs.)', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTypeSegment(String label, String key, String selected, Color color, VoidCallback onTap) {
    final isSelected = selected == key;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha(30) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? color : Colors.grey.withAlpha(60)),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? color : Colors.grey,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  void _showEditBudgetPlanDialog(BuildContext context, MonthlyBudgetPlanModel currentPlan) {
    double expense = currentPlan.needsPercentage;
    double other = currentPlan.wantsPercentage;
    double savings = currentPlan.savingsBufferPercentage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final total = expense + other + savings;
            final is100 = (total - 100).abs() < 0.1;

            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('International Budget Rule', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Total: ${total.toStringAsFixed(0)}% ${is100 ? "✅" : "⚠️ Must equal 100%"}',
                      style: TextStyle(color: is100 ? AppColors.profit : AppColors.loss, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  // Quick presets row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ActionChip(
                          label: const Text('50/30/20 Standard'),
                          onPressed: () {
                            setModalState(() {
                              expense = 50.0;
                              other = 30.0;
                              savings = 20.0;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        ActionChip(
                          label: const Text('70/20/10 Cashflow'),
                          onPressed: () {
                            setModalState(() {
                              expense = 70.0;
                              other = 10.0;
                              savings = 20.0;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        ActionChip(
                          label: const Text('60/20/20 Balanced'),
                          onPressed: () {
                            setModalState(() {
                              expense = 60.0;
                              other = 20.0;
                              savings = 20.0;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSliderRow('🏠 Needs & Living Essentials %', expense, const Color(0xFFFF5252), (v) => setModalState(() => expense = v)),
                  _buildSliderRow('🎯 Wants & Discretionary Lifestyle %', other, const Color(0xFF7C4DFF), (v) => setModalState(() => other = v)),
                  _buildSliderRow('🛡️ Bank Savings & Emergency Buffer %', savings, const Color(0xFF00C087), (v) => setModalState(() => savings = v)),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                      onPressed: !is100
                          ? null
                          : () async {
                              final updated = currentPlan.copyWith(
                                expensesPercentage: expense,
                                otherInvestPercentage: other,
                                savingsPercentage: savings,
                                cryptoPercentage: 0.0,
                              );
                              await ref.read(bankBudgetProvider.notifier).updateBudgetPlan(updated);
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                      child: const Text('Save Allocation Plan', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSliderRow(String label, double val, Color color, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            Text('${val.toStringAsFixed(0)}%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        Slider(
          value: val.clamp(0, 100),
          min: 0,
          max: 100,
          divisions: 20,
          activeColor: color,
          onChanged: onChanged,
        ),
      ],
    );
  }

  void _simulateNextMonthSalary(BuildContext context, String nextMonthStr) async {
    final messenger = ScaffoldMessenger.of(context);
    final success = await ref.read(bankBudgetProvider.notifier).creditSalaryForMonth(nextMonthStr);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(success ? '✅ Next month salary credited to bank balance in LKR!' : '⚠️ Salary for $nextMonthStr already credited or no active job found.'),
        backgroundColor: success ? AppColors.profit : AppColors.loss,
      ),
    );
  }

  void _confirmDeleteRecord(BuildContext context, CashRecordModel record) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Cash Record?'),
        content: Text('Are you sure you want to delete "${record.category}" (${_lkr(record.amount)})?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(bankBudgetProvider.notifier).deleteRecord(record.id);
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.loss)),
          ),
        ],
      ),
    );
  }
}
