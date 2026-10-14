import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/formatters.dart';
import '../data/models/cashflow_model.dart';
import '../providers/cashflow_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/portfolio_provider.dart';
import 'bank_budget_hub_screen.dart';
import 'salary_epf_screen.dart';

class DepositWithdrawScreen extends ConsumerStatefulWidget {
  const DepositWithdrawScreen({super.key});

  @override
  ConsumerState<DepositWithdrawScreen> createState() => _DepositWithdrawScreenState();
}

class _DepositWithdrawScreenState extends ConsumerState<DepositWithdrawScreen> {
  String _selectedFilter = 'ALL'; // 'ALL', 'DEPOSIT', 'WITHDRAWAL', 'P2P'

  @override
  Widget build(BuildContext context) {
    final cashflow = ref.watch(cashflowProvider);
    final currency = ref.watch(depositWithdrawCurrencyProvider);

    final bgColor = AppColors.background(context);
    final surfaceColor = AppColors.surface(context);
    final surfaceLight = AppColors.surfaceLight(context);
    final borderColor = AppColors.border(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final textMuted = AppColors.textMuted(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isNetPositive = cashflow.netCapital >= 0;

    final filteredItems = cashflow.items.where((item) {
      if (_selectedFilter == 'ALL') return true;
      if (_selectedFilter == 'P2P') return item.isP2P;
      return item.type == _selectedFilter;
    }).toList();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text(
          'Deposit & Withdraw Hub',
          style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          // Currency selector button
          InkWell(
            onTap: () => _showCurrencyPicker(context, currency),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: surfaceLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: currency.code == 'USDT'
                      ? const Color(0xFF26A17B).withAlpha(140)
                      : AppColors.primary.withAlpha(100),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (currency.code == 'USDT') ...[
                    Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: const BoxDecoration(
                        color: Color(0xFF26A17B),
                        shape: BoxShape.circle,
                      ),
                      child: const Text('₮', style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold, height: 1.0)),
                    ),
                    const SizedBox(width: 5),
                  ],
                  Text(
                    currency.code,
                    style: TextStyle(
                      color: currency.code == 'USDT' ? const Color(0xFF26A17B) : AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_drop_down,
                    color: currency.code == 'USDT' ? const Color(0xFF26A17B) : AppColors.primary,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Bank & Monthly Budget Hub',
            icon: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF3861FB)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BankBudgetHubScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Salary & EPF Tracker',
            icon: const Icon(Icons.work_history_rounded, color: Color(0xFF9D7CFF)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SalaryEpfScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: surfaceColor,
        onRefresh: () async {
          await ref.read(cashflowProvider.notifier).refresh();
          await ref.read(portfolioSummaryProvider.notifier).refresh();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1. Net Capital & Cashflow Hero Card
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF16161C), const Color(0xFF0F0E13)]
                      : [const Color(0xFFFFFFFF), const Color(0xFFF9F9FC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isNetPositive ? AppColors.profit.withAlpha(80) : AppColors.loss.withAlpha(80),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'NET DEPOSITED CAPITAL',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isNetPositive ? AppColors.profitBg : AppColors.lossBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isNetPositive ? 'Capital Inflow' : 'Net Outflow',
                          style: TextStyle(
                            color: isNetPositive ? AppColors.profit : AppColors.loss,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${cashflow.netCapital >= 0 ? '+' : ''}${Formatters.currency(cashflow.netCapital, SupportedCurrencies.usdt)}',
                      style: TextStyle(
                        color: isNetPositive ? textPrimary : AppColors.loss,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (currency.code != 'USDT' && currency.code != 'USD') ...[
                    const SizedBox(height: 3),
                    Text(
                      '≈ ${Formatters.currency(cashflow.netCapital, currency)} (${currency.code})',
                      style: const TextStyle(
                        color: Color(0xFF3861FB),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    'Total capital deposited into trading minus total withdrawals',
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                  Divider(color: borderColor, height: 26),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.arrow_downward, color: AppColors.profit, size: 14),
                                  const SizedBox(width: 4),
                                  Text('Total Deposited', style: TextStyle(color: textMuted, fontSize: 11)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 3),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '+${Formatters.currency(cashflow.totalDeposited, SupportedCurrencies.usdt)}',
                                style: const TextStyle(color: AppColors.profit, fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                            ),
                            if (currency.code != 'USDT' && currency.code != 'USD') ...[
                              const SizedBox(height: 2),
                              Text(
                                Formatters.currency(cashflow.totalDeposited, currency),
                                style: TextStyle(color: textMuted, fontSize: 10),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  const Icon(Icons.arrow_upward, color: AppColors.loss, size: 14),
                                  const SizedBox(width: 4),
                                  Text('Total Withdrawn', style: TextStyle(color: textMuted, fontSize: 11)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 3),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                '-${Formatters.currency(cashflow.totalWithdrawn, SupportedCurrencies.usdt)}',
                                style: const TextStyle(color: AppColors.loss, fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                            ),
                            if (currency.code != 'USDT' && currency.code != 'USD') ...[
                              const SizedBox(height: 2),
                              Text(
                                Formatters.currency(cashflow.totalWithdrawn, currency),
                                style: TextStyle(color: textMuted, fontSize: 10),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. 🤝 P2P MERCHANT & TRADE SUMMARY CARD
            _buildP2pMerchantCard(context, cashflow, currency, surfaceColor, surfaceLight, borderColor, textPrimary, textSecondary, textMuted),
            const SizedBox(height: 16),

            // 3. Action Buttons (Deposit vs Withdraw + P2P Express)
            Row(
              children: [
                // Deposit Button
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.profit,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => _openCashflowDialog(context, type: 'DEPOSIT'),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.arrow_downward, size: 18),
                          SizedBox(width: 6),
                          Text('Deposit Funds', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Withdraw Button
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.loss,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => _openCashflowDialog(context, type: 'WITHDRAWAL'),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.arrow_upward, size: 18),
                          SizedBox(width: 6),
                          Text('Withdraw Funds', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // P2P Quick Action Bar
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFF59E0B),
                side: const BorderSide(color: Color(0xFFF59E0B), width: 1.2),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.handshake_rounded, size: 18),
              label: const Text('New P2P Trade (Rate & Local Currency)', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => _openCashflowDialog(context, type: 'DEPOSIT', defaultP2P: true),
            ),
            const SizedBox(height: 20),

            // 4. Segmented Filter Tabs
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'TRANSFER HISTORY',
                    style: TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Wrap(
                  spacing: 4,
                  children: [
                    _filterButton('ALL', 'All', surfaceColor, surfaceLight, borderColor, textPrimary, textSecondary),
                    _filterButton('DEPOSIT', 'Deposits', surfaceColor, surfaceLight, borderColor, textPrimary, textSecondary),
                    _filterButton('WITHDRAWAL', 'Withdrawals', surfaceColor, surfaceLight, borderColor, textPrimary, textSecondary),
                    _filterButton('P2P', '🤝 P2P Only', surfaceColor, surfaceLight, borderColor, textPrimary, textSecondary),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 5. Activity Log List
            if (filteredItems.isEmpty)
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.swap_vert, size: 42, color: textMuted),
                      const SizedBox(height: 10),
                      Text('No transfer records found', style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        _selectedFilter == 'P2P'
                            ? 'No P2P trades recorded yet. Tap "New P2P Trade" above to log buy/sell with custom rates.'
                            : 'Tap "Deposit Funds" or "Withdraw Funds" above to record transfers.',
                        style: TextStyle(color: textSecondary, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              ...filteredItems.map((item) {
                final isDep = item.type == 'DEPOSIT';
                final color = isDep ? AppColors.profit : AppColors.loss;
                final isP2p = item.isP2P;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isP2p ? const Color(0xFFF59E0B).withAlpha(100) : borderColor,
                      width: isP2p ? 1.2 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isP2p ? const Color(0xFFF59E0B).withAlpha(30) : color.withAlpha(30),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isP2p
                              ? Icons.handshake_rounded
                              : (isDep ? Icons.arrow_downward : Icons.arrow_upward),
                          color: isP2p ? const Color(0xFFF59E0B) : color,
                          size: 20,
                        ),
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
                                    item.category,
                                    style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                if (isP2p)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF59E0B).withAlpha(30),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isDep ? 'P2P BUY' : 'P2P SELL',
                                      style: const TextStyle(
                                        color: Color(0xFFF59E0B),
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: color.withAlpha(20),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isDep ? 'Deposit' : 'Withdrawal',
                                      style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              Formatters.date(item.date),
                              style: TextStyle(color: textMuted, fontSize: 11),
                            ),
                            if (isP2p && item.p2pRate != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Rate: 1 USDT = ${NumberFormat('#,##0.00').format(item.p2pRate)} ${item.effectiveLocalCurrency}',
                                style: const TextStyle(
                                  color: Color(0xFF3861FB),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            if (item.notes.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                item.notes,
                                style: TextStyle(color: textSecondary, fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              '${isDep ? '+' : '-'}${NumberFormat('#,##0.00').format(item.amount)} USDT',
                              style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (isP2p || item.localAmount != null) ...[
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                '${isDep ? 'Spent: ' : 'Payout: '}${item.effectiveLocalCurrency} ${NumberFormat('#,##0.00').format(item.effectiveLocalAmount)}',
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(width: 4),
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, color: textMuted, size: 18),
                        color: surfaceColor,
                        onSelected: (val) {
                          if (val == 'edit') {
                            _openCashflowDialog(context, type: item.type, itemToEdit: item);
                          } else if (val == 'delete') {
                            _confirmDelete(context, item.id);
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'edit', child: Text('Edit')),
                          const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppColors.loss))),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // 🤝 P2P Merchant Overview Widget
  Widget _buildP2pMerchantCard(
    BuildContext context,
    CashflowSummary cashflow,
    CurrencyInfo currency,
    Color surfaceColor,
    Color surfaceLight,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
  ) {
    final hasP2p = cashflow.p2pTradeCount > 0;
    final currencyFormat = NumberFormat('#,##0.00');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF59E0B).withAlpha(120), width: 1.2),
      ),
      child: Column(
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
                      color: const Color(0xFFF59E0B).withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.handshake_rounded, color: Color(0xFFF59E0B), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'P2P MERCHANT & LOCAL HUB',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withAlpha(20),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${cashflow.p2pTradeCount} Trades',
                  style: const TextStyle(
                    color: Color(0xFFF59E0B),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (!hasP2p)
            Text(
              'No P2P trades logged yet. When you buy or sell USDT via P2P (Binance, Bybit, etc.), log them here with your exact fiat rate to track total local currency spent and merchant spreads.',
              style: TextStyle(color: textSecondary, fontSize: 12),
            )
          else ...[
            Row(
              children: [
                // P2P Bought Column
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.profit.withAlpha(50)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('P2P Bought (Inflow)', style: TextStyle(color: textMuted, fontSize: 11)),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '+${cashflow.totalP2pDepositedUsdt.toStringAsFixed(2)} USDT',
                            style: const TextStyle(color: AppColors.profit, fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Spent: ${currency.symbol}${currencyFormat.format(cashflow.totalP2pDepositedLocal)}',
                          style: TextStyle(color: textPrimary, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Avg Rate: @ ${cashflow.avgP2pBuyRate.toStringAsFixed(2)} / USDT',
                          style: TextStyle(color: textMuted, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // P2P Sold Column
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.loss.withAlpha(50)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('P2P Sold (Outflow)', style: TextStyle(color: textMuted, fontSize: 11)),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '-${cashflow.totalP2pWithdrawnUsdt.toStringAsFixed(2)} USDT',
                            style: const TextStyle(color: AppColors.loss, fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Payout: ${currency.symbol}${currencyFormat.format(cashflow.totalP2pWithdrawnLocal)}',
                          style: TextStyle(color: textPrimary, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Avg Rate: @ ${cashflow.avgP2pSellRate.toStringAsFixed(2)} / USDT',
                          style: TextStyle(color: textMuted, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            if (cashflow.avgP2pBuyRate > 0 && cashflow.avgP2pSellRate > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: (cashflow.avgP2pSellRate >= cashflow.avgP2pBuyRate ? AppColors.profit : AppColors.loss).withAlpha(15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: (cashflow.avgP2pSellRate >= cashflow.avgP2pBuyRate ? AppColors.profit : AppColors.loss).withAlpha(60),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Merchant Spread / Margin', style: TextStyle(color: textMuted, fontSize: 11)),
                        Text(
                          '${(cashflow.avgP2pSellRate - cashflow.avgP2pBuyRate).toStringAsFixed(2)} ${currency.code} / USDT',
                          style: TextStyle(
                            color: cashflow.avgP2pSellRate >= cashflow.avgP2pBuyRate ? AppColors.profit : AppColors.loss,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Realized Fiat Gain', style: TextStyle(color: textMuted, fontSize: 11)),
                        Text(
                          '${cashflow.p2pNetProfitLocal >= 0 ? '+' : ''}${currency.symbol}${currencyFormat.format(cashflow.p2pNetProfitLocal)}',
                          style: TextStyle(
                            color: cashflow.p2pNetProfitLocal >= 0 ? AppColors.profit : AppColors.loss,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _filterButton(
    String key,
    String label,
    Color surfaceColor,
    Color surfaceLight,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    final isSelected = _selectedFilter == key;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = key),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : surfaceLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? AppColors.primary : borderColor),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : textSecondary,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  void _showCurrencyPicker(BuildContext context, CurrencyInfo current) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final textPrimary = AppColors.textPrimary(context);
        final borderColor = AppColors.border(context);

        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            padding: const EdgeInsets.only(top: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select Display / Local Currency',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                Divider(color: borderColor, height: 16),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
                    itemCount: SupportedCurrencies.all.length,
                    separatorBuilder: (context, index) => Divider(color: borderColor.withAlpha(80), height: 1),
                    itemBuilder: (context, index) {
                      final c = SupportedCurrencies.all[index];
                      final isSel = c.code == current.code;
                      final isUsdt = c.code == 'USDT';

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        decoration: BoxDecoration(
                          color: isSel
                              ? (isUsdt ? const Color(0xFF26A17B).withAlpha(18) : AppColors.primary.withAlpha(18))
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          leading: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: isSel
                                  ? (isUsdt ? const Color(0xFF26A17B) : AppColors.primary)
                                  : (isUsdt ? const Color(0xFF26A17B).withAlpha(25) : AppColors.surfaceLight(context)),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSel
                                    ? (isUsdt ? const Color(0xFF26A17B) : AppColors.primary)
                                    : (isUsdt ? const Color(0xFF26A17B).withAlpha(80) : borderColor),
                                width: 1.2,
                              ),
                            ),
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    isUsdt ? '₮' : c.code,
                                    style: TextStyle(
                                      color: isSel
                                          ? Colors.white
                                          : (isUsdt ? const Color(0xFF26A17B) : textPrimary),
                                      fontSize: isUsdt ? 20 : 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  '${c.name} (${c.code})',
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                                    fontSize: 14.5,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isUsdt) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF26A17B).withAlpha(25),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFF26A17B).withAlpha(100), width: 0.8),
                                  ),
                                  child: const Text(
                                    'BASE STABLECOIN',
                                    style: TextStyle(
                                      color: Color(0xFF26A17B),
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              isUsdt
                                  ? 'Pegged 1:1 with USD • Primary Base Currency'
                                  : 'Base Rate: 1 USD ≈ ${c.rateToUsd} ${c.code}',
                              style: TextStyle(
                                color: isUsdt ? const Color(0xFF26A17B) : AppColors.textSecondary(context),
                                fontSize: 11,
                                fontWeight: isUsdt ? FontWeight.w500 : FontWeight.normal,
                              ),
                            ),
                          ),
                          trailing: isSel
                              ? Icon(Icons.check_circle_rounded, color: isUsdt ? const Color(0xFF26A17B) : AppColors.primary, size: 20)
                              : null,
                          onTap: () {
                            ref.read(depositWithdrawCurrencyProvider.notifier).setCurrency(c);
                            Navigator.pop(ctx);
                          },
                        ),
                      );
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

  void _openCashflowDialog(
    BuildContext context, {
    required String type,
    CashflowItem? itemToEdit,
    bool defaultP2P = false,
  }) {
    final CurrencyInfo activeCurrency = ref.read(depositWithdrawCurrencyProvider);
    final isDeposit = type == 'DEPOSIT';

    final amountCtrl = TextEditingController(text: itemToEdit != null ? itemToEdit.amount.toString() : '');
    final notesCtrl = TextEditingController(text: itemToEdit?.notes ?? '');

    bool isP2P = itemToEdit != null ? itemToEdit.isP2P : defaultP2P;
    String selectedLocalCurrency = itemToEdit?.localCurrency ?? activeCurrency.code;
    if (selectedLocalCurrency == 'USD' || selectedLocalCurrency == 'USDT') {
      selectedLocalCurrency = 'LKR'; // Default local fiat currency
    }

    final initialRate = itemToEdit?.p2pRate ??
        (SupportedCurrencies.fromCode(selectedLocalCurrency).rateToUsd > 1.0
            ? SupportedCurrencies.fromCode(selectedLocalCurrency).rateToUsd
            : 310.0);
    final rateCtrl = TextEditingController(text: initialRate.toStringAsFixed(2));

    final initialLocalAmount = itemToEdit?.localAmount ??
        (itemToEdit != null ? (itemToEdit.amount * initialRate) : 0.0);
    final localAmountCtrl = TextEditingController(
      text: initialLocalAmount > 0 ? initialLocalAmount.toStringAsFixed(2) : '',
    );

    String selectedCategory = itemToEdit?.category ??
        (isP2P
            ? (isDeposit ? 'P2P Buy' : 'P2P Sell')
            : (isDeposit ? 'Salary Inflow' : 'Profit Realization'));

    DateTime selectedDate = itemToEdit?.date ?? DateTime.now();

    final depositCategories = ['P2P Buy', 'Salary Inflow', 'Bank Transfer', 'Crypto Deposit', 'Savings / Bonus', 'Custom Deposit'];
    final withdrawalCategories = ['P2P Sell', 'Profit Realization', 'Bank Withdrawal', 'Emergency Expense', 'Crypto Cashout', 'Custom Withdrawal'];

    final categories = isDeposit ? depositCategories : withdrawalCategories;

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
          final color = isDeposit ? AppColors.profit : AppColors.loss;

          void updateCalculationsFromUsdt() {
            final u = double.tryParse(amountCtrl.text.trim()) ?? 0;
            final r = double.tryParse(rateCtrl.text.trim()) ?? 0;
            if (u > 0 && r > 0) {
              localAmountCtrl.text = (u * r).toStringAsFixed(2);
            }
          }

          void updateCalculationsFromLocal() {
            final l = double.tryParse(localAmountCtrl.text.trim()) ?? 0;
            final r = double.tryParse(rateCtrl.text.trim()) ?? 0;
            if (l > 0 && r > 0) {
              amountCtrl.text = (l / r).toStringAsFixed(2);
            }
          }

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(modalCtx).size.height * 0.85,
                ),
                padding: const EdgeInsets.only(
                  top: 20,
                  left: 20,
                  right: 20,
                  bottom: 20,
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
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
                                decoration: BoxDecoration(color: color.withAlpha(30), shape: BoxShape.circle),
                                child: Icon(isDeposit ? Icons.arrow_downward : Icons.arrow_upward, color: color, size: 20),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  itemToEdit != null
                                      ? 'Edit ${isDeposit ? "Deposit" : "Withdrawal"}'
                                      : (isDeposit ? 'Deposit Funds (Buy)' : 'Withdraw Funds (Sell)'),
                                  style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // P2P Mode Switch
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isP2P ? const Color(0xFFF59E0B).withAlpha(20) : AppColors.surfaceLight(modalCtx),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isP2P ? const Color(0xFFF59E0B) : borderColor,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(Icons.handshake_rounded, color: isP2P ? const Color(0xFFF59E0B) : textSecondary, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'P2P Trade (Rate & Local Currency)',
                                        style: TextStyle(
                                          color: textPrimary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'Track local fiat spent/received & exchange rate',
                                        style: TextStyle(color: textSecondary, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Switch(
                            value: isP2P,
                            activeThumbColor: const Color(0xFFF59E0B),
                            onChanged: (val) {
                              setModalState(() {
                                isP2P = val;
                                if (isP2P) {
                                  selectedCategory = isDeposit ? 'P2P Buy' : 'P2P Sell';
                                  updateCalculationsFromUsdt();
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                  // P2P Specific Fields
                  if (isP2P) ...[
                    // Local Currency & Exchange Rate
                    Row(
                      children: [
                        // Local Currency Selector
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Local Fiat Currency', style: TextStyle(color: textSecondary, fontSize: 12)),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceLight(modalCtx),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: borderColor),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: selectedLocalCurrency,
                                    isExpanded: true,
                                    dropdownColor: AppColors.surface(modalCtx),
                                    items: ['LKR', 'INR', 'AED', 'EUR', 'GBP', 'USD', 'AUD', 'CAD']
                                        .map((c) => DropdownMenuItem(
                                              value: c,
                                              child: Text(c, style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold)),
                                            ))
                                        .toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setModalState(() {
                                          selectedLocalCurrency = val;
                                          final cur = SupportedCurrencies.fromCode(val);
                                          if (cur.rateToUsd > 1.0) {
                                            rateCtrl.text = cur.rateToUsd.toStringAsFixed(2);
                                            updateCalculationsFromUsdt();
                                          }
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        // P2P Rate
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('P2P Rate ($selectedLocalCurrency / USDT)', style: TextStyle(color: textSecondary, fontSize: 12)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: rateCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(Icons.currency_exchange, color: Color(0xFFF59E0B), size: 18),
                                  hintText: 'e.g. 310.50',
                                  filled: true,
                                  fillColor: AppColors.surfaceLight(modalCtx),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                                ),
                                onChanged: (_) => setModalState(updateCalculationsFromUsdt),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Amount USDT & Total Local Currency
                    Row(
                      children: [
                        // USDT Amount
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Crypto (USDT)', style: TextStyle(color: textSecondary, fontSize: 12)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: amountCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  prefixIcon: Icon(Icons.attach_money, color: color),
                                  hintText: '500.00',
                                  filled: true,
                                  fillColor: AppColors.surfaceLight(modalCtx),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                                ),
                                onChanged: (_) => setModalState(updateCalculationsFromUsdt),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Total Local Fiat
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Total Fiat ($selectedLocalCurrency)', style: TextStyle(color: textSecondary, fontSize: 12)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: localAmountCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(Icons.account_balance_wallet, color: Color(0xFF3861FB)),
                                  hintText: '155250.00',
                                  filled: true,
                                  fillColor: AppColors.surfaceLight(modalCtx),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                                ),
                                onChanged: (_) => setModalState(updateCalculationsFromLocal),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Live calculation summary badge
                    Builder(builder: (_) {
                      final u = double.tryParse(amountCtrl.text.trim()) ?? 0;
                      final r = double.tryParse(rateCtrl.text.trim()) ?? 0;
                      final total = u * r;
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withAlpha(15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFF59E0B).withAlpha(50)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                isDeposit ? 'Total Local Currency Cost:' : 'Total Local Currency Payout:',
                                style: TextStyle(color: textSecondary, fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$selectedLocalCurrency ${NumberFormat('#,##0.00').format(total)}',
                              style: const TextStyle(
                                color: Color(0xFFF59E0B),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ] else ...[
                    // Standard Non-P2P Amount field
                    Text('Amount (USDT)', style: TextStyle(color: textSecondary, fontSize: 12)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.attach_money, color: color),
                        hintText: 'e.g. 500.00',
                        filled: true,
                        fillColor: AppColors.surfaceLight(modalCtx),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),

                  // Category Selector
                  Text('Transfer Category', style: TextStyle(color: textSecondary, fontSize: 12)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categories.map((cat) {
                      final isSel = selectedCategory == cat;
                      return InkWell(
                        onTap: () {
                          setModalState(() {
                            selectedCategory = cat;
                            if (cat.contains('P2P') && !isP2P) {
                              isP2P = true;
                              updateCalculationsFromUsdt();
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSel ? color : AppColors.surfaceLight(modalCtx),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isSel ? color : borderColor),
                          ),
                          child: Text(
                            cat,
                            style: TextStyle(
                              color: isSel ? Colors.white : textSecondary,
                              fontSize: 12,
                              fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // Date Picker Tile
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today, color: AppColors.primary, size: 20),
                    title: Text(Formatters.date(selectedDate), style: TextStyle(color: textPrimary, fontSize: 14)),
                    trailing: const Text('Change Date', style: TextStyle(color: AppColors.primary, fontSize: 12)),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: modalCtx,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setModalState(() => selectedDate = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 6),

                  // Notes Field
                  TextField(
                    controller: notesCtrl,
                    style: TextStyle(color: textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: isP2P ? 'Merchant note (e.g. Binance Order #, Bank Ref)...' : 'Optional transfer notes...',
                      filled: true,
                      fillColor: AppColors.surfaceLight(modalCtx),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Submit Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      final amt = double.tryParse(amountCtrl.text.trim()) ?? 0;
                      if (amt <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a valid amount'), backgroundColor: AppColors.loss),
                        );
                        return;
                      }

                      final pRate = isP2P ? (double.tryParse(rateCtrl.text.trim()) ?? 1.0) : null;
                      final lAmt = isP2P
                          ? (double.tryParse(localAmountCtrl.text.trim()) ?? (amt * (pRate ?? 1.0)))
                          : null;

                      if (itemToEdit != null) {
                        ref.read(cashflowProvider.notifier).updateRecord(
                              id: itemToEdit.id,
                              type: type,
                              amount: amt,
                              category: selectedCategory,
                              date: selectedDate,
                              notes: notesCtrl.text.trim(),
                              isP2P: isP2P,
                              p2pRate: pRate,
                              localCurrency: isP2P ? selectedLocalCurrency : null,
                              localAmount: lAmt,
                            );
                      } else {
                        ref.read(cashflowProvider.notifier).addRecord(
                              type: type,
                              amount: amt,
                              category: selectedCategory,
                              date: selectedDate,
                              notes: notesCtrl.text.trim(),
                              isP2P: isP2P,
                              p2pRate: pRate,
                              localCurrency: isP2P ? selectedLocalCurrency : null,
                              localAmount: lAmt,
                            );
                      }

                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${isDeposit ? "Deposit" : "Withdrawal"} recorded successfully!'),
                          backgroundColor: color,
                        ),
                      );
                    },
                    child: Text(
                      itemToEdit != null
                          ? 'Save Changes'
                          : (isP2P
                              ? (isDeposit ? 'Confirm P2P Buy' : 'Confirm P2P Sell')
                              : (isDeposit ? 'Confirm Deposit' : 'Confirm Withdrawal')),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
      ),
    );
  }

  void _confirmDelete(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        title: Text('Delete Record', style: TextStyle(color: AppColors.textPrimary(context))),
        content: Text('Are you sure you want to delete this cashflow entry?', style: TextStyle(color: AppColors.textSecondary(context))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary(context))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.loss),
            onPressed: () {
              ref.read(cashflowProvider.notifier).deleteRecord(id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
