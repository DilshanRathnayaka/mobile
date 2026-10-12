import 'package:flutter/material.dart';
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

  // Exact Sri Lankan Rupee (LKR) Formatter down to the exact cent (e.g. Rs. 150,250.75)
  static String _lkr(num amount) => Formatters.fullLkr(amount, showCents: true);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
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
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text('Add Record (Rs.)', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        onPressed: () => _showAddRecordSheet(context),
      ),
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
    final netSalary = career.activeEmployment?.monthlyNetSalary ?? (career.activeJob != null ? career.activeJob!.monthlyNetSalary : 0.0);
    final totalMonthlyInflow = netSalary > 0 ? netSalary : (summary.totalIncomeAllTime > 0 ? summary.totalIncomeAllTime : 100000.0);

    final savingsAmount = totalMonthlyInflow * (summary.plan.savingsPercentage / 100);
    final cryptoAmount = totalMonthlyInflow * (summary.plan.cryptoPercentage / 100);
    final otherInvestAmount = totalMonthlyInflow * (summary.plan.otherInvestPercentage / 100);
    final expenseAmount = totalMonthlyInflow * (summary.plan.expensesPercentage / 100);

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
                      'SALARY ALLOCATION MATRIX (LKR)',
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9D7CFF).withAlpha(30),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('Adjust %', style: TextStyle(color: Color(0xFF9D7CFF), fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Monthly Base: ${_lkr(totalMonthlyInflow)}',
                style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Based on ${career.activeEmployment?.companyName ?? "Monthly Net Cashflow"}',
                style: TextStyle(color: textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Breakdown Cards
        _buildAllocationBucketCard(
          title: '🛡️ Bank & Emergency Savings',
          percentage: summary.plan.savingsPercentage,
          amount: savingsAmount,
          color: const Color(0xFF00D182),
          description: 'High-liquidity bank savings in LKR to secure a 6-month buffer.',
          surfaceColor: surfaceColor,
          borderColor: borderColor,
          textPrimary: textPrimary,
          textMuted: textMuted,
        ),
        const SizedBox(height: 10),

        _buildAllocationBucketCard(
          title: '🪙 Crypto DCA Asset Fund',
          percentage: summary.plan.cryptoPercentage,
          amount: cryptoAmount,
          color: const Color(0xFFF7931A),
          description: 'Disciplined monthly LKR allocation to DCA into Bitcoin & Top crypto assets.',
          surfaceColor: surfaceColor,
          borderColor: borderColor,
          textPrimary: textPrimary,
          textMuted: textMuted,
        ),
        const SizedBox(height: 10),

        _buildAllocationBucketCard(
          title: '📈 Other Investments (Stocks, FD, T-Bills)',
          percentage: summary.plan.otherInvestPercentage,
          amount: otherInvestAmount,
          color: const Color(0xFF3861FB),
          description: 'Fixed income, Colombo Stock Exchange (CSE) shares & high-yield deposits in LKR.',
          surfaceColor: surfaceColor,
          borderColor: borderColor,
          textPrimary: textPrimary,
          textMuted: textMuted,
        ),
        const SizedBox(height: 10),

        _buildAllocationBucketCard(
          title: '🛒 Living & Discretionary Expenses',
          percentage: summary.plan.expensesPercentage,
          amount: expenseAmount,
          color: const Color(0xFFFF5252),
          description: 'Maximum permitted monthly budget for rent, bills, groceries and lifestyle in LKR.',
          surfaceColor: surfaceColor,
          borderColor: borderColor,
          textPrimary: textPrimary,
          textMuted: textMuted,
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildAllocationBucketCard({
    required String title,
    required double percentage,
    required double amount,
    required Color color,
    required String description,
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

    // Determine currently selected month for deep inspection
    final activeYm = _selectedReportYm ?? summary.monthlyReports.first.yearMonth;
    final selectedReport = summary.monthlyReports.firstWhere(
      (r) => r.yearMonth == activeYm,
      orElse: () => summary.monthlyReports.first,
    );

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
        // 1. Month Selector Pill Carousel
        Text('Select Month to Audit', style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
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
        const SizedBox(height: 16),

        // 2. Month-Wise Deep Dive Audit Card (High Expense Breakdown)
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

        // 3. Month-over-Month Bar Chart
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

        // 4. All-Time Peak Records
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
                      Text('+${_lkr(selectedReport.totalIncome)}',
                          style: const TextStyle(color: AppColors.profit, fontSize: 12, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Month Outflow', style: TextStyle(color: textMuted, fontSize: 10)),
                      const SizedBox(height: 2),
                      Text('-${_lkr(selectedReport.totalExpense)}',
                          style: const TextStyle(color: AppColors.loss, fontSize: 12, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Savings Rate', style: TextStyle(color: textMuted, fontSize: 10)),
                      const SizedBox(height: 2),
                      Text('${selectedReport.savingsRate.toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: selectedReport.savingsRate >= 20 ? AppColors.profit : Colors.amber,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
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
                        Text('${percent.toStringAsFixed(1)}% of total spending',
                            style: TextStyle(color: textMuted, fontSize: 10.5)),
                        if (growthLabel != null)
                          Flexible(
                            child: Text(growthLabel,
                                style: TextStyle(color: growthColor, fontSize: 10, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
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
          Text(month, style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(_lkr(amount), style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w800)),
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
    double savings = currentPlan.savingsPercentage;
    double crypto = currentPlan.cryptoPercentage;
    double other = currentPlan.otherInvestPercentage;
    double expense = currentPlan.expensesPercentage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final total = savings + crypto + other + expense;
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
                      const Text('Custom Salary Budget Plan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Total: ${total.toStringAsFixed(0)}% ${is100 ? "✅" : "⚠️ Must equal 100%"}',
                      style: TextStyle(color: is100 ? AppColors.profit : AppColors.loss, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildSliderRow('Savings %', savings, (v) => setModalState(() => savings = v)),
                  _buildSliderRow('Crypto DCA %', crypto, (v) => setModalState(() => crypto = v)),
                  _buildSliderRow('Other Investments %', other, (v) => setModalState(() => other = v)),
                  _buildSliderRow('Expenses %', expense, (v) => setModalState(() => expense = v)),
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
                                savingsPercentage: savings,
                                cryptoPercentage: crypto,
                                otherInvestPercentage: other,
                                expensesPercentage: expense,
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

  Widget _buildSliderRow(String label, double val, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            Text('${val.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
        Slider(
          value: val,
          min: 0,
          max: 100,
          divisions: 20,
          activeColor: AppColors.primary,
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
