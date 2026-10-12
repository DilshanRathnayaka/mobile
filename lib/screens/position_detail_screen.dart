import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/formatters.dart';
import '../data/models/holding_model.dart';
import '../data/models/transaction_model.dart';
import '../providers/currency_provider.dart';
import '../providers/portfolio_provider.dart';
import 'add_transaction_screen.dart';

class PositionDetailScreen extends ConsumerStatefulWidget {
  final HoldingModel holding;

  const PositionDetailScreen({super.key, required this.holding});

  @override
  ConsumerState<PositionDetailScreen> createState() => _PositionDetailScreenState();
}

class _PositionDetailScreenState extends ConsumerState<PositionDetailScreen> {
  String _activeTab = 'DCA_BUYS'; // 'DCA_BUYS', 'SELLS', 'ALL'

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(currencyProvider);
    final portfolioAsync = ref.watch(portfolioSummaryProvider);
    final txAsync = ref.watch(transactionsProvider);

    final bgColor = AppColors.background(context);
    final surfaceColor = AppColors.surface(context);
    final borderColor = AppColors.border(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final textMuted = AppColors.textMuted(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Resolve latest live holding data if available
    HoldingModel liveHolding = widget.holding;
    final portfolio = portfolioAsync.valueOrNull;
    if (portfolio != null) {
      final found = portfolio.holdings.where(
        (h) => h.symbol.toUpperCase() == widget.holding.symbol.toUpperCase() || h.coinId == widget.holding.coinId,
      );
      if (found.isNotEmpty) {
        liveHolding = found.first;
      }
    }

    final isProfit = liveHolding.unrealizedPnl >= 0;
    final isClosed = liveHolding.totalQuantity <= 0.00000001;

    // Filter transactions for this coin
    final allTxs = txAsync.valueOrNull ?? [];
    final coinTxs = allTxs.where((t) {
      final sMatch = t.symbol != null && t.symbol!.toUpperCase() == widget.holding.symbol.toUpperCase();
      final idMatch = t.coinId != null && t.coinId == widget.holding.coinId;
      return sMatch || idMatch;
    }).toList();

    // Sort chronologically oldest -> newest to calculate DCA sequence numbers
    final chronologicalTxs = List<TransactionModel>.from(coinTxs)
      ..sort((a, b) => a.transactionDate.compareTo(b.transactionDate));

    // Map each BUY transaction to its DCA order index (1, 2, 3...)
    final Map<String, int> dcaIndices = {};
    int buyCount = 0;
    double lowestBuyPrice = double.infinity;
    double highestBuyPrice = 0.0;
    double totalFeesPaid = 0.0;

    for (final tx in chronologicalTxs) {
      totalFeesPaid += tx.fee;
      if (tx.type == 'BUY') {
        buyCount++;
        dcaIndices[tx.id] = buyCount;
        if (tx.pricePerUnit < lowestBuyPrice) lowestBuyPrice = tx.pricePerUnit;
        if (tx.pricePerUnit > highestBuyPrice) highestBuyPrice = tx.pricePerUnit;
      }
    }

    if (lowestBuyPrice == double.infinity) lowestBuyPrice = liveHolding.averageBuyPrice;
    if (highestBuyPrice == 0.0) highestBuyPrice = liveHolding.averageBuyPrice;

    // Filter based on active tab (ordered newest first for display)
    final displayTxs = List<TransactionModel>.from(coinTxs)
      ..sort((a, b) => b.transactionDate.compareTo(a.transactionDate));

    final filteredTxs = displayTxs.where((t) {
      if (_activeTab == 'DCA_BUYS') return t.type == 'BUY';
      if (_activeTab == 'SELLS') return t.type == 'SELL';
      return true;
    }).toList();

    final buyTxsCount = coinTxs.where((t) => t.type == 'BUY').length;
    final sellTxsCount = coinTxs.where((t) => t.type == 'SELL').length;

    // Price deviation from average buy price
    final avgPrice = liveHolding.averageBuyPrice > 0 ? liveHolding.averageBuyPrice : 1.0;
    final deviationPct = ((liveHolding.currentPrice - avgPrice) / avgPrice) * 100;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primaryGlow,
              radius: 14,
              child: Text(
                liveHolding.symbol.substring(0, liveHolding.symbol.length > 3 ? 3 : liveHolding.symbol.length),
                style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '${liveHolding.name} (${liveHolding.symbol})',
                style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Add DCA Transaction',
            icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
            onPressed: () => _navigateToAdd(context, 'BUY', liveHolding),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Position Hero Analytics Card
            _buildPositionHeroCard(
              context,
              liveHolding,
              currency,
              isProfit,
              isClosed,
              buyCount,
              deviationPct,
              isDark,
              borderColor,
              textPrimary,
              textSecondary,
              textMuted,
            ),
            const SizedBox(height: 16),

            // 2. DCA Price Range & Execution Breakdown Card
            _buildDcaRangeCard(
              context,
              liveHolding,
              lowestBuyPrice,
              highestBuyPrice,
              totalFeesPaid,
              currency,
              surfaceColor,
              borderColor,
              textPrimary,
              textSecondary,
              textMuted,
            ),
            const SizedBox(height: 20),

            // 3. Tab Navigation (DCA Buys, Sells, All)
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Order History & DCA Entries',
                    style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _tabChip('Buys ($buyTxsCount)', 'DCA_BUYS'),
                      _tabChip('Sells ($sellTxsCount)', 'SELLS'),
                      _tabChip('All (${coinTxs.length})', 'ALL'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 4. Detailed Orders Timeline
            if (filteredTxs.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 44, color: textMuted),
                    const SizedBox(height: 10),
                    Text(
                      _activeTab == 'SELLS' ? 'No sell orders executed yet' : 'No transactions recorded',
                      style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _activeTab == 'SELLS'
                          ? 'When you take profit or sell this position, sell records will appear here.'
                          : 'Tap "+ Add DCA Buy" to record your entry point.',
                      style: TextStyle(color: textMuted, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ...filteredTxs.map((tx) {
                final dcaNumber = dcaIndices[tx.id];
                return _buildTransactionCard(
                  context,
                  tx,
                  dcaNumber,
                  currency,
                  surfaceColor,
                  borderColor,
                  textPrimary,
                  textSecondary,
                  textMuted,
                );
              }),
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomActionBar(context, liveHolding),
    );
  }

  Widget _tabChip(String label, String key) {
    final isSelected = _activeTab == key;
    return InkWell(
      onTap: () => setState(() => _activeTab = key),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.grey,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildPositionHeroCard(
    BuildContext context,
    HoldingModel holding,
    CurrencyInfo currency,
    bool isProfit,
    bool isClosed,
    int buyCount,
    double deviationPct,
    bool isDark,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
  ) {
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
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isClosed
              ? Colors.grey.withAlpha(80)
              : (isProfit ? AppColors.profit.withAlpha(120) : AppColors.loss.withAlpha(120)),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 80 : 15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Badges & Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isClosed ? Colors.grey.withAlpha(40) : (isProfit ? AppColors.profitBg : AppColors.lossBg),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isClosed ? Icons.lock_clock : (isProfit ? Icons.trending_up : Icons.trending_down),
                      size: 14,
                      color: isClosed ? Colors.grey : (isProfit ? AppColors.profit : AppColors.loss),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isClosed ? 'CLOSED POSITION' : (isProfit ? 'IN PROFIT' : 'IN LOSS'),
                      style: TextStyle(
                        color: isClosed ? Colors.grey : (isProfit ? AppColors.profit : AppColors.loss),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryGlow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$buyCount DCA Orders Completed',
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Row 2: Main Holding Value
          Text(
            isClosed ? 'TOTAL REALIZED PROCEEDS' : 'CURRENT POSITION VALUE',
            style: TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.0),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Formatters.currency(isClosed ? holding.realizedPnl : holding.currentValue, currency),
              style: TextStyle(
                color: textPrimary,
                fontSize: 32,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 4),

          // Row 3: Unrealized & Realized PnL summary
          Row(
            children: [
              Flexible(
                child: Text(
                  isClosed
                      ? 'Closed trade with realized return'
                      : '${isProfit ? "+" : ""}${Formatters.currency(holding.unrealizedPnl, currency)} (${Formatters.percentage(holding.unrealizedPnlPercentage)})',
                  style: TextStyle(
                    color: isClosed ? textSecondary : (isProfit ? AppColors.profit : AppColors.loss),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              if (!isClosed && holding.realizedPnl != 0)
                Flexible(
                  child: Text(
                    '• Realized: ${holding.realizedPnl >= 0 ? "+" : ""}${Formatters.currency(holding.realizedPnl, currency)}',
                    style: TextStyle(color: holding.realizedPnl >= 0 ? AppColors.profit : AppColors.loss, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: borderColor),
          const SizedBox(height: 10),

          // Row 4: Key Metrics 2x2 Grid
          Row(
            children: [
              Expanded(
                child: _heroMetric(
                  label: 'DCA Average Buy Price',
                  value: Formatters.currency(holding.averageBuyPrice, currency),
                  subValue: '${deviationPct >= 0 ? "+" : ""}${deviationPct.toStringAsFixed(1)}% vs Market',
                  subColor: deviationPct >= 0 ? AppColors.profit : AppColors.loss,
                  textPrimary: textPrimary,
                  textMuted: textMuted,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _heroMetric(
                  label: 'Current Live Price',
                  value: Formatters.currency(holding.currentPrice, currency),
                  subValue: '24h: ${Formatters.percentage(holding.change24h)}',
                  subColor: holding.change24h >= 0 ? AppColors.profit : AppColors.loss,
                  textPrimary: textPrimary,
                  textMuted: textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _heroMetric(
                  label: 'Total Quantity Held',
                  value: '${Formatters.cryptoAmount(holding.totalQuantity)} ${holding.symbol}',
                  subValue: 'In Wallet / Custody',
                  subColor: textMuted,
                  textPrimary: textPrimary,
                  textMuted: textMuted,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _heroMetric(
                  label: 'Total Cost Invested',
                  value: Formatters.currency(holding.totalInvestedCost, currency),
                  subValue: 'Principal Capital',
                  subColor: textMuted,
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

  Widget _heroMetric({
    required String label,
    required String value,
    required String subValue,
    required Color subColor,
    required Color textPrimary,
    required Color textMuted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: textMuted, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 1),
        Text(subValue, style: TextStyle(color: subColor, fontSize: 10, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _buildDcaRangeCard(
    BuildContext context,
    HoldingModel holding,
    double lowestBuy,
    double highestBuy,
    double totalFees,
    CurrencyInfo currency,
    Color surfaceColor,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
  ) {
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
            children: [
              const Icon(Icons.analytics_outlined, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                'DCA Price Execution Range',
                style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.profit.withAlpha(15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.profit.withAlpha(40)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Lowest DCA Buy', style: TextStyle(color: AppColors.profit, fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 3),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(Formatters.currency(lowestBuy, currency), style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                      const SizedBox(height: 2),
                      const Text('Best Dip Entry', style: TextStyle(color: Colors.grey, fontSize: 9.5)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.loss.withAlpha(15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.loss.withAlpha(40)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Highest DCA Buy', style: TextStyle(color: AppColors.loss, fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 3),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(Formatters.currency(highestBuy, currency), style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                      const SizedBox(height: 2),
                      const Text('Peak Entry Price', style: TextStyle(color: Colors.grey, fontSize: 9.5)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C4DFF).withAlpha(15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF7C4DFF).withAlpha(40)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Fees Paid', style: TextStyle(color: Color(0xFF7C4DFF), fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 3),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(Formatters.currency(totalFees, currency), style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                      const SizedBox(height: 2),
                      const Text('Exchange Costs', style: TextStyle(color: Colors.grey, fontSize: 9.5)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(
    BuildContext context,
    TransactionModel tx,
    int? dcaNumber,
    CurrencyInfo currency,
    Color surfaceColor,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
  ) {
    final isBuy = tx.type == 'BUY';
    final badgeColor = isBuy ? AppColors.profit : AppColors.loss;
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(tx.transactionDate);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AddTransactionScreen(transactionToEdit: tx)),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Type, DCA Badge, Amount, Total
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: badgeColor.withAlpha(60)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(isBuy ? Icons.arrow_downward : Icons.arrow_upward, color: badgeColor, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        isBuy ? (dcaNumber != null ? 'DCA #$dcaNumber BUY' : 'BUY') : 'SELL ORDER',
                        style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 10.5),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  Formatters.currency(tx.totalAmount, currency),
                  style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Execution details
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Buy Price / Execution Rate', style: TextStyle(color: textMuted, fontSize: 10)),
                      const SizedBox(height: 2),
                      Text(
                        Formatters.currency(tx.pricePerUnit, currency),
                        style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Quantity Acquired', style: TextStyle(color: textMuted, fontSize: 10)),
                      const SizedBox(height: 2),
                      Text(
                        '${isBuy ? "+" : "-"}${Formatters.cryptoAmount(tx.amount)} ${tx.symbol ?? widget.holding.symbol}',
                        style: TextStyle(color: badgeColor, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Trading Fee', style: TextStyle(color: textMuted, fontSize: 10)),
                    const SizedBox(height: 2),
                    Text(
                      tx.fee > 0 ? Formatters.currency(tx.fee, currency) : 'Free / \$0',
                      style: TextStyle(color: textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Date and Notes
            Row(
              children: [
                Icon(Icons.schedule, size: 12, color: textMuted),
                const SizedBox(width: 4),
                Text(dateStr, style: TextStyle(color: textMuted, fontSize: 11)),
                if (tx.notes.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '• ${tx.notes}',
                      style: TextStyle(color: textSecondary, fontSize: 11, fontStyle: FontStyle.italic),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 16, color: textMuted),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActionBar(BuildContext context, HoldingModel holding) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _navigateToAdd(context, 'BUY', holding),
                icon: const Icon(Icons.add_shopping_cart, size: 18),
                label: const Text('+ DCA Buy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.loss,
                  side: const BorderSide(color: AppColors.loss, width: 1.2),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _navigateToAdd(context, 'SELL', holding),
                icon: const Icon(Icons.sell_outlined, size: 18),
                label: const Text('Sell Position', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToAdd(BuildContext context, String type, HoldingModel holding) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTransactionScreen(
          initialType: type,
          preselectedSymbol: holding.symbol,
          preselectedCoinName: holding.name,
          preselectedCoinId: holding.coinId,
        ),
      ),
    );
  }
}
