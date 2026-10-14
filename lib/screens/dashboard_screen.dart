import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/formatters.dart';
import '../providers/bank_budget_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/employment_provider.dart';
import '../providers/portfolio_provider.dart';
import '../providers/theme_provider.dart';
import 'add_transaction_screen.dart';
import 'bank_budget_hub_screen.dart';
import 'deposit_withdraw_screen.dart';
import 'profile_screen.dart';
import 'profit_calculator_screen.dart';
import 'salary_epf_screen.dart';
import 'transactions_history_screen.dart';
import 'position_detail_screen.dart';
import 'crypto_intelligence_screen.dart';
import '../widgets/realtime_status_badge.dart';
import '../widgets/skeleton_loading.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final portfolioAsync = ref.watch(portfolioSummaryProvider);
    final isHidden = ref.watch(isBalanceHiddenProvider);
    final currency = ref.watch(currencyProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = AppColors.background(context);
    final surfaceColor = AppColors.surface(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        titleSpacing: 10,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Profile Button
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.primaryGlow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withAlpha(120), width: 1.2),
                ),
                child: const Icon(Icons.person, color: AppColors.primary, size: 18),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Asset Manager',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Crypto & DCA Terminal',
                    style: TextStyle(color: textSecondary, fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Realtime Live Streaming Indicator
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14, horizontal: 4),
            child: RealtimeStatusBadge(),
          ),
          // Theme Toggle Button (Dark / Light)
          IconButton(
            tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              color: AppColors.primary,
              size: 20,
            ),
            onPressed: () {
              ref.read(themeModeProvider.notifier).toggle();
            },
          ),
          // Privacy Toggle Button
          IconButton(
            tooltip: isHidden ? 'Show Balances' : 'Hide Balances',
            icon: Icon(
              isHidden ? Icons.visibility_off : Icons.visibility,
              color: textSecondary,
              size: 20,
            ),
            onPressed: () {
              ref.read(isBalanceHiddenProvider.notifier).state = !isHidden;
            },
          ),
        ],
      ),
      body: portfolioAsync.when(
        loading: () => const DashboardSkeleton(),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $err', style: const TextStyle(color: AppColors.loss)),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: () => ref.read(portfolioSummaryProvider.notifier).refresh(),
                child: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
        data: (portfolio) {
          final isProfit = portfolio.unrealizedPnl >= 0;

          return RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: surfaceColor,
            onRefresh: () => ref.read(portfolioSummaryProvider.notifier).refresh(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 1. Hero Net Worth Card
                _buildHeroCard(context, portfolio, isHidden, isProfit, currency),
                const SizedBox(height: 20),

                // 2. Quick Actions
                _buildQuickActions(context),
                const SizedBox(height: 14),

                // 2.2 Market Intelligence & Wire Banner
                _buildMarketIntelligenceBanner(context),
                const SizedBox(height: 14),

                // 2.5 Career, Salary & EPF Banner
                _buildCareerSalaryEpfBanner(context, ref),
                const SizedBox(height: 12),

                // 2.6 Bank Balance & Monthly Cashflow Budget Banner
                _buildBankBudgetBanner(context, ref),
                const SizedBox(height: 24),

                // 3. Asset Allocation Bar
                if (portfolio.allocations.isNotEmpty) ...[
                  _buildAllocationSection(context, portfolio),
                  const SizedBox(height: 24),
                ],

                // 4. Holdings Section Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Live Positions & DCA',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${portfolio.coinsCount} Assets',
                      style: TextStyle(color: textSecondary, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 5. Holdings List
                if (portfolio.holdings.where((h) => h.totalQuantity > 0.00000001).isEmpty)
                  _buildEmptyHoldings(context)
                else
                  ...portfolio.holdings
                      .where((h) => h.totalQuantity > 0.00000001)
                      .map((h) => _buildHoldingTile(context, h, isHidden, currency)),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
          );
        },
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildHeroCard(
    BuildContext context,
    dynamic portfolio,
    bool isHidden,
    bool isProfit,
    CurrencyInfo currency,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final borderColor = AppColors.border(context);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF16161B), const Color(0xFF0D0D10)]
              : [const Color(0xFFFFFFFF), const Color(0xFFF9F9FC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppColors.primary.withAlpha(50) : borderColor,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withAlpha(120) : Colors.black.withAlpha(15),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Text(
                    'NET PORTFOLIO VALUE',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.3,
                    ),
                  ),
                  SizedBox(width: 8),
                  RealtimeStatusBadge(size: 5.5),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryGlow,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  currency.code,
                  style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isHidden ? '•••••••• ${currency.code}' : Formatters.currency(portfolio.netPortfolioValue, currency),
            style: TextStyle(
              color: textPrimary,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),

          // PnL & Unallocated Cash Badges
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isProfit ? AppColors.profitBg : AppColors.lossBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isProfit ? Icons.arrow_upward : Icons.arrow_downward,
                      color: isProfit ? AppColors.profit : AppColors.loss,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isHidden
                          ? '•••%'
                          : '${Formatters.percentage(portfolio.unrealizedPnlPercentage)} (${Formatters.currency(portfolio.unrealizedPnl, currency)})',
                      style: TextStyle(
                        color: isProfit ? AppColors.profit : AppColors.loss,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              // Unallocated Cash Pill Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00B4D8).withAlpha(isDark ? 30 : 20),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF00B4D8).withAlpha(80), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.account_balance_wallet, color: Color(0xFF00B4D8), size: 14),
                    const SizedBox(width: 5),
                    Text(
                      'Unallocated: ${isHidden ? '••••' : Formatters.currency(portfolio.unallocatedUsdt, currency)}',
                      style: const TextStyle(
                        color: Color(0xFF00B4D8),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          Divider(color: borderColor, height: 26),

          // Sub metrics: Crypto Value, Total Invested, Realized PnL
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Crypto Holdings', style: TextStyle(color: textSecondary, fontSize: 11)),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        isHidden ? '••••' : Formatters.currency(portfolio.currentValue, currency),
                        style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text('Capital Invested', style: TextStyle(color: textSecondary, fontSize: 11)),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Text(
                        isHidden ? '••••' : Formatters.currency(portfolio.totalInvested, currency),
                        style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Realized Profit', style: TextStyle(color: textSecondary, fontSize: 11)),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        isHidden ? '••••' : Formatters.currency(portfolio.realizedPnl, currency),
                        style: const TextStyle(color: AppColors.profit, fontSize: 14, fontWeight: FontWeight.w700),
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

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _actionButton(
            context: context,
            icon: Icons.add_circle,
            label: 'DCA Buy',
            accentColor: AppColors.primary,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddTransactionScreen(initialType: 'BUY')),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _actionButton(
            context: context,
            icon: Icons.calculate,
            label: 'Calculator',
            accentColor: const Color(0xFF7C4DFF),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfitCalculatorScreen()),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _actionButton(
            context: context,
            icon: Icons.account_balance_wallet,
            label: 'Deposit',
            accentColor: AppColors.gold,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DepositWithdrawScreen()),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _actionButton(
            context: context,
            icon: Icons.receipt_long,
            label: 'History',
            accentColor: const Color(0xFF00B4D8),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TransactionsHistoryScreen()),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _actionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = AppColors.surface(context);
    final borderColor = AppColors.border(context);
    final textPrimary = AppColors.textPrimary(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: accentColor.withAlpha(40),
        highlightColor: accentColor.withAlpha(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 2),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF14151B) : surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? borderColor.withAlpha(90) : borderColor,
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 50 : 8),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withAlpha(isDark ? 35 : 25),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: accentColor.withAlpha(isDark ? 90 : 50),
                    width: 1.2,
                  ),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(height: 7),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMarketIntelligenceBanner(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CryptoIntelligenceScreen()),
        );
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF131D24), const Color(0xFF0F151A)]
                : [const Color(0xFFF0F9FB), const Color(0xFFE8F4F8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFF00B4D8).withAlpha(isDark ? 90 : 60),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00B4D8).withAlpha(isDark ? 20 : 8),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: const Color(0xFF00B4D8).withAlpha(35),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF00B4D8).withAlpha(90)),
              ),
              child: const Icon(Icons.bolt_rounded, color: Color(0xFF00B4D8), size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Trading Wire & News',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E676).withAlpha(25),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Text('LIVE', style: TextStyle(color: Color(0xFF00E676), fontSize: 8.5, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Macro FED dates, ETF inflows & token unlock alerts',
                    style: TextStyle(color: textSecondary, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCareerSalaryEpfBanner(BuildContext context, WidgetRef ref) {
    final careerSummary = ref.watch(careerSummaryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);

    final activeJob = careerSummary.activeEmployment;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SalaryEpfScreen()),
        );
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF1B1828), const Color(0xFF13131A)]
                : [const Color(0xFFF7F5FE), const Color(0xFFEDEDFA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFF7C4DFF).withAlpha(isDark ? 90 : 60),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C4DFF).withAlpha(isDark ? 25 : 10),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF7C4DFF).withAlpha(35),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF7C4DFF).withAlpha(90), width: 1.2),
              ),
              child: const Icon(Icons.work_history_rounded, color: Color(0xFF9D7CFF), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          activeJob != null ? activeJob.companyName : 'Career, Salary & EPF',
                          style: TextStyle(
                            color: textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (activeJob != null ? AppColors.profit : const Color(0xFF7C4DFF)).withAlpha(35),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          activeJob != null ? 'ACTIVE' : 'EPF / ETF',
                          style: TextStyle(
                            color: activeJob != null ? AppColors.profit : const Color(0xFF9D7CFF),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    activeJob != null
                        ? 'Net: ${Formatters.fullLkr(activeJob.monthlyNetSalary, showCents: false)} • Next Pay in ${activeJob.daysUntilNextSalary}d'
                        : 'Track Join Date, Resignation & CBSL EPF 20%',
                    style: TextStyle(color: textSecondary, fontSize: 11.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'EPF Fund',
                  style: TextStyle(color: textSecondary, fontSize: 10, fontWeight: FontWeight.w600),
                ),
                Text(
                  Formatters.fullLkr(careerSummary.totalAccumulatedEpf20, showCents: false),
                  style: const TextStyle(
                    color: Color(0xFF9D7CFF),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildBankBudgetBanner(BuildContext context, WidgetRef ref) {
    final budgetAsync = ref.watch(bankBudgetProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BankBudgetHubScreen()),
        );
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF10192A), const Color(0xFF0D131F)]
                : [const Color(0xFFF2F6FE), const Color(0xFFE7EFFD)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFF3861FB).withAlpha(isDark ? 90 : 60),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3861FB).withAlpha(isDark ? 25 : 10),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF3861FB).withAlpha(35),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF3861FB).withAlpha(90), width: 1.2),
              ),
              child: const Icon(Icons.account_balance_rounded, color: Color(0xFF3861FB), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          budgetAsync.asData?.value.account.bankName ?? 'Bank Account & Budget',
                          style: TextStyle(
                            color: textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3861FB).withAlpha(35),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'BANK HUB',
                          style: TextStyle(
                            color: Color(0xFF3861FB),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    budgetAsync.when(
                      data: (b) => 'Inflow: +${Formatters.fullLkr(b.totalIncomeAllTime, showCents: true)} • Outflow: -${Formatters.fullLkr(b.totalExpenseAllTime, showCents: true)}',
                      loading: () => 'Loading balance details...',
                      error: (e, s) => 'Tap to configure initial bank balance',
                    ),
                    style: TextStyle(color: textSecondary, fontSize: 11.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Bank Balance',
                  style: TextStyle(color: textSecondary, fontSize: 10, fontWeight: FontWeight.w600),
                ),
                Text(
                  budgetAsync.when(
                    data: (b) => Formatters.fullLkr(b.currentBalance, showCents: true),
                    loading: () => '...',
                    error: (e, s) => 'Rs. 0.00',
                  ),
                  style: const TextStyle(
                    color: Color(0xFF3861FB),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAllocationSection(BuildContext context, dynamic portfolio) {
    final surfaceColor = AppColors.surface(context);
    final borderColor = AppColors.border(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);

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
          Text(
            'Asset Distribution',
            style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: portfolio.allocations.asMap().entries.map<Widget>((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  final color = AppColors.chartColors[idx % AppColors.chartColors.length];
                  return Expanded(
                    flex: (item.percentage * 10).toInt(),
                    child: Container(color: color),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: portfolio.allocations.asMap().entries.map<Widget>((entry) {
              final idx = entry.key;
              final item = entry.value;
              final color = AppColors.chartColors[idx % AppColors.chartColors.length];
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${item.symbol} ${item.percentage.toStringAsFixed(1)}%',
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHoldingTile(
    BuildContext context,
    dynamic holding,
    bool isHidden,
    CurrencyInfo currency,
  ) {
    final surfaceColor = AppColors.surface(context);
    final surfaceLight = AppColors.surfaceLight(context);
    final borderColor = AppColors.border(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final textMuted = AppColors.textMuted(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isProfit = holding.unrealizedPnl >= 0;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PositionDetailScreen(holding: holding)),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          children: [
            Row(
              children: [
              CircleAvatar(
                backgroundColor: surfaceLight,
                radius: 18,
                child: Text(
                  holding.symbol.substring(0, holding.symbol.length > 3 ? 3 : holding.symbol.length),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      holding.name,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isHidden
                          ? '•••• ${holding.symbol}'
                          : '${Formatters.cryptoAmount(holding.totalQuantity)} ${holding.symbol}',
                      style: TextStyle(color: textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    isHidden ? '••••' : Formatters.currency(holding.currentValue, currency),
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isHidden
                        ? '•••%'
                        : '${Formatters.percentage(holding.unrealizedPnlPercentage)} (${Formatters.currency(holding.unrealizedPnl, currency)})',
                    style: TextStyle(
                      color: isProfit ? AppColors.profit : AppColors.loss,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Divider(color: borderColor, height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Text('DCA Avg: ', style: TextStyle(color: textMuted, fontSize: 11)),
                      Text(
                        Formatters.currency(holding.averageBuyPrice, currency),
                        style: TextStyle(color: textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    children: [
                      Text('Market: ', style: TextStyle(color: textMuted, fontSize: 11)),
                      Text(
                        Formatters.currency(holding.currentPrice, currency),
                        style: TextStyle(color: textPrimary, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        Formatters.percentage(holding.change24h),
                        style: TextStyle(
                          color: holding.change24h >= 0 ? AppColors.profit : AppColors.loss,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Position Action Controls: DCA / Add Margin & Sell Position
          Row(
            children: [
              // 1. DCA / Add Margin Button
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.profit.withAlpha(isDark ? 35 : 25),
                      foregroundColor: AppColors.profit,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      side: BorderSide(
                        color: AppColors.profit.withAlpha(isDark ? 90 : 60),
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddTransactionScreen(
                            initialType: 'BUY',
                            preselectedCoinId: holding.coinId,
                            preselectedSymbol: holding.symbol,
                            preselectedCoinName: holding.name,
                            prefilledPrice: holding.currentPrice > 0 ? holding.currentPrice : holding.averageBuyPrice,
                          ),
                        ),
                      );
                    },
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.add_circle_outline, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'DCA / Add Margin',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 2. Sell Position Button
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.loss,
                      backgroundColor: AppColors.loss.withAlpha(isDark ? 30 : 20),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      side: BorderSide(
                        color: AppColors.loss.withAlpha(isDark ? 90 : 60),
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddTransactionScreen(
                            initialType: 'SELL',
                            preselectedCoinId: holding.coinId,
                            preselectedSymbol: holding.symbol,
                            preselectedCoinName: holding.name,
                            prefilledPrice: holding.currentPrice > 0 ? holding.currentPrice : holding.averageBuyPrice,
                            prefilledAmount: holding.totalQuantity,
                          ),
                        ),
                      );
                    },
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.sell_outlined, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Sell Position',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Tap to view DCA entry prices & order timeline',
                style: TextStyle(color: textMuted, fontSize: 10.5, fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 14, color: textMuted),
            ],
          ),
        ],
      ),
    ),
  );
}

  Widget _buildEmptyHoldings(BuildContext context) {
    final surfaceColor = AppColors.surface(context);
    final borderColor = AppColors.border(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          const Icon(Icons.currency_bitcoin, color: AppColors.primary, size: 48),
          const SizedBox(height: 12),
          Text(
            'No crypto holdings yet',
            style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Start your Dollar-Cost Averaging strategy by adding your first crypto buy.',
            textAlign: TextAlign.center,
            style: TextStyle(color: textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
              );
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add First Buy'),
          ),
        ],
      ),
    );
  }
}
