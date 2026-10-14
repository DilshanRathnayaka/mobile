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
import '../widgets/realtime_status_badge.dart';

class PositionDetailScreen extends ConsumerStatefulWidget {
  final HoldingModel holding;

  const PositionDetailScreen({super.key, required this.holding});

  @override
  ConsumerState<PositionDetailScreen> createState() => _PositionDetailScreenState();
}

class _PositionDetailScreenState extends ConsumerState<PositionDetailScreen> {
  String _activeTab = 'DCA_BUYS'; // 'DCA_BUYS', 'SELLS', 'ALL'
  bool? _userToggledAllCycles;

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

    // Filter transactions for this coin - strictly spot/futures trades, excluding P2P and cashflow
    final allTxs = txAsync.valueOrNull ?? [];
    final coinTxs = allTxs.where((t) {
      if (t.isP2P || t.isCashflow) return false;
      final sMatch = t.symbol != null && t.symbol!.toUpperCase() == widget.holding.symbol.toUpperCase();
      final idMatch = t.coinId != null && t.coinId == widget.holding.coinId;
      return sMatch || idMatch;
    }).toList();

    // Sort chronologically oldest -> newest to calculate DCA sequence numbers and detect position cycles.
    // If timestamps are equal, process BUY/LONG before SELL/SHORT to maintain inventory validity.
    final chronologicalTxs = List<TransactionModel>.from(coinTxs)
      ..sort((a, b) {
        final dateComp = a.transactionDate.compareTo(b.transactionDate);
        if (dateComp != 0) return dateComp;
        final aIsBuy = a.type == 'BUY' || a.type == 'LONG';
        final bIsBuy = b.type == 'BUY' || b.type == 'LONG';
        if (aIsBuy && !bIsBuy) return -1;
        if (!aIsBuy && bIsBuy) return 1;
        return a.id.compareTo(b.id);
      });

    // Track position cycles: when running quantity returns to 0 (position fully closed/sold),
    // any subsequent buy starts a brand new active trade cycle.
    double runningQty = 0.0;
    int cycle = 1;
    final Map<String, int> txCycleMap = {};
    final Map<String, int> dcaIndices = {};
    int cycleBuyCount = 0;

    for (final tx in chronologicalTxs) {
      if (tx.type == 'BUY' || tx.type == 'LONG') {
        cycleBuyCount++;
        dcaIndices[tx.id] = cycleBuyCount;
        runningQty += tx.amount;
        txCycleMap[tx.id] = cycle;
      } else if (tx.type == 'SELL' || tx.type == 'SHORT') {
        txCycleMap[tx.id] = cycle;
        runningQty = (runningQty - tx.amount).clamp(0.0, double.infinity);
        final remainingValue = runningQty * (tx.pricePerUnit > 0 ? tx.pricePerUnit : 1.0);
        // Position fully closed if remaining quantity or remaining fiat value is negligible dust
        if (runningQty <= 0.001 || remainingValue < 0.20) {
          runningQty = 0.0;
          // Position fully closed! Next transaction starts a fresh cycle
          cycle++;
          cycleBuyCount = 0;
        }
      } else {
        txCycleMap[tx.id] = cycle;
      }
    }

    final bool hasActivePosition = runningQty > 0.001;
    final int latestCycle = hasActivePosition ? cycle : (cycle > 1 ? cycle - 1 : 1);
    final int activeCycle = latestCycle;
    final bool hasPastCycles = (cycle > 1 && (hasActivePosition || cycle > 2));
    final bool showAllCycles = _userToggledAllCycles ?? false;

    // Calculate metrics strictly for the active position cycle
    int activeBuyCount = 0;
    double lowestBuyPrice = double.infinity;
    double highestBuyPrice = 0.0;
    double totalFeesPaid = 0.0;
    double activeQty = 0.0;
    double activeInvested = 0.0;
    double activeRealized = 0.0;
    double activeAvgBuyPrice = 0.0;

    final activeCycleTxs = chronologicalTxs.where((t) => txCycleMap[t.id] == activeCycle).toList();
    for (final tx in activeCycleTxs) {
      totalFeesPaid += tx.fee;
      if (tx.type == 'BUY' || tx.type == 'LONG') {
        activeBuyCount++;
        if (tx.pricePerUnit < lowestBuyPrice) lowestBuyPrice = tx.pricePerUnit;
        if (tx.pricePerUnit > highestBuyPrice) highestBuyPrice = tx.pricePerUnit;
        activeQty += tx.amount;
        activeInvested += tx.totalAmount + tx.fee;
        if (activeQty > 0) {
          activeAvgBuyPrice = activeInvested / activeQty;
        }
      } else if (tx.type == 'SELL' || tx.type == 'SHORT') {
        final sellRev = tx.totalAmount - tx.fee;
        final costBasis = tx.amount * activeAvgBuyPrice;
        activeRealized += (sellRev - costBasis);
        activeQty = (activeQty - tx.amount).clamp(0.0, double.infinity);
        if (activeQty <= 0.00000001) {
          activeQty = 0.0;
          activeInvested = 0.0;
          activeAvgBuyPrice = 0.0;
        } else {
          activeInvested = activeQty * activeAvgBuyPrice;
        }
      }
    }

    if (lowestBuyPrice == double.infinity) lowestBuyPrice = activeAvgBuyPrice > 0 ? activeAvgBuyPrice : liveHolding.averageBuyPrice;
    if (highestBuyPrice == 0.0) highestBuyPrice = activeAvgBuyPrice > 0 ? activeAvgBuyPrice : liveHolding.averageBuyPrice;

    // Build isolated active display holding vs lifetime holding
    final double effectiveQty = (!showAllCycles && hasActivePosition) ? activeQty : liveHolding.totalQuantity;
    final double effectiveInvested = (!showAllCycles && hasActivePosition) ? activeInvested : liveHolding.totalInvestedCost;
    final double effectiveAvgPrice = (!showAllCycles && hasActivePosition && activeAvgBuyPrice > 0) ? activeAvgBuyPrice : liveHolding.averageBuyPrice;
    final double effectiveCurrentVal = effectiveQty * liveHolding.currentPrice;
    final double effectiveUnrealized = effectiveCurrentVal - effectiveInvested;
    final double effectiveUnrealizedPct = effectiveInvested > 0 ? (effectiveUnrealized / effectiveInvested) * 100 : 0.0;
    final double effectiveRealized = (!showAllCycles && hasActivePosition) ? activeRealized : liveHolding.realizedPnl;

    final displayHolding = liveHolding.copyWith(
      totalQuantity: effectiveQty,
      averageBuyPrice: effectiveAvgPrice,
      totalInvestedCost: effectiveInvested,
      currentValue: effectiveCurrentVal,
      unrealizedPnl: effectiveUnrealized,
      unrealizedPnlPercentage: effectiveUnrealizedPct,
      realizedPnl: effectiveRealized,
    );

    final isProfit = displayHolding.unrealizedPnl >= 0;
    final isClosed = displayHolding.totalQuantity <= 0.00000001;

    // Scope displayed transactions based on whether user wants only the active position or all history
    final scopedTxs = (showAllCycles || !hasActivePosition)
        ? coinTxs
        : coinTxs.where((t) => txCycleMap[t.id] == activeCycle).toList();

    // Filter based on active tab (ordered newest first for display)
    final displayTxs = List<TransactionModel>.from(scopedTxs)
      ..sort((a, b) => b.transactionDate.compareTo(a.transactionDate));

    final filteredTxs = displayTxs.where((t) {
      if (_activeTab == 'DCA_BUYS') return t.type == 'BUY' || t.type == 'LONG';
      if (_activeTab == 'SELLS') return t.type == 'SELL' || t.type == 'SHORT';
      return true;
    }).toList();

    final buyTxsCount = scopedTxs.where((t) => t.type == 'BUY' || t.type == 'LONG').length;
    final sellTxsCount = scopedTxs.where((t) => t.type == 'SELL' || t.type == 'SHORT').length;

    // Price deviation from average buy price
    final avgPrice = displayHolding.averageBuyPrice > 0 ? displayHolding.averageBuyPrice : 1.0;
    final deviationPct = ((displayHolding.currentPrice - avgPrice) / avgPrice) * 100;

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
                displayHolding.symbol.substring(0, displayHolding.symbol.length > 3 ? 3 : displayHolding.symbol.length),
                style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '${displayHolding.name} (${displayHolding.symbol})',
                style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            const RealtimeStatusBadge(size: 6),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Add DCA Transaction',
            icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
            onPressed: () => _navigateToAdd(context, 'BUY', displayHolding),
          ),
          if (coinTxs.isNotEmpty)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: textPrimary),
              color: surfaceColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (val) {
                if (val == 'clear_all') {
                  _confirmClearAllCoinTransactions(context, coinTxs, displayHolding.symbol);
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'clear_all',
                  child: Row(
                    children: const [
                      Icon(Icons.delete_sweep_outlined, color: AppColors.loss, size: 20),
                      SizedBox(width: 8),
                      Text('Clear All Coin Orders', style: TextStyle(color: AppColors.loss, fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
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
              displayHolding,
              currency,
              isProfit,
              isClosed,
              activeBuyCount,
              deviationPct,
              isDark,
              borderColor,
              textPrimary,
              textSecondary,
              textMuted,
            ),
            const SizedBox(height: 16),

            // 2. DCA Price Range & Execution Breakdown Card (only if multiple buys exist in this cycle)
            if (activeBuyCount > 1) ...[
              _buildDcaRangeCard(
                context,
                displayHolding,
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
            ],

            // 3. Tab Navigation (DCA Buys, Sells, All)
            if (hasPastCycles) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _userToggledAllCycles = false),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: !showAllCycles ? AppColors.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Active Position ($activeBuyCount Buys)',
                                style: TextStyle(
                                  color: !showAllCycles ? Colors.black : textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _userToggledAllCycles = true),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: showAllCycles ? AppColors.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'All History (${coinTxs.length} Total)',
                                style: TextStyle(
                                  color: showAllCycles ? Colors.black : textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            Row(
              children: [
                Expanded(
                  child: Text(
                    showAllCycles ? 'All Orders History' : 'Current DCA Entries',
                    style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Container(
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
                        _tabChip('All (${scopedTxs.length})', 'ALL'),
                      ],
                    ),
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
                final isPastCycle = hasPastCycles && (txCycleMap[tx.id] != activeCycle);
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
                  isClosedCycle: isPastCycle,
                );
              }),
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomActionBar(context, displayHolding),
    );
  }

  Widget _tabChip(String label, String key) {
    final isSelected = _activeTab == key;
    return InkWell(
      onTap: () => setState(() => _activeTab = key),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
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
    Color textMuted, {
    bool isClosedCycle = false,
  }) {
    final isBuy = tx.type == 'BUY' || tx.type == 'LONG';
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
                Expanded(
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: badgeColor.withAlpha(25),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: badgeColor.withAlpha(60)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(isBuy ? Icons.arrow_downward : Icons.arrow_upward, color: badgeColor, size: 11),
                            const SizedBox(width: 3),
                            Text(
                              isBuy
                                  ? (dcaNumber != null && dcaNumber > 1 ? 'DCA #$dcaNumber' : 'ENTRY')
                                  : 'SELL',
                              style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      if (isClosedCycle)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.withAlpha(35),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.grey.withAlpha(80), width: 0.8),
                          ),
                          child: const Text('CLOSED', style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            Formatters.currency(tx.totalAmount, currency),
                            style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _confirmDeleteTransaction(context, tx),
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Icon(Icons.delete_outline, color: AppColors.loss.withAlpha(200), size: 18),
                        ),
                      ),
                    ],
                  ),
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
                      Text(isBuy ? 'Buy Price' : 'Sell Price', style: TextStyle(color: textMuted, fontSize: 10)),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          Formatters.currency(tx.pricePerUnit, currency),
                          style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isBuy ? 'Quantity Acquired' : 'Quantity Sold', style: TextStyle(color: textMuted, fontSize: 10)),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${isBuy ? "+" : "-"}${Formatters.cryptoAmount(tx.amount)} ${tx.symbol ?? widget.holding.symbol}',
                          style: TextStyle(color: badgeColor, fontSize: 13, fontWeight: FontWeight.bold),
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
                      Text('Trading Fee', style: TextStyle(color: textMuted, fontSize: 10)),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          tx.fee > 0 ? Formatters.currency(tx.fee, currency) : 'Free / \$0',
                          style: TextStyle(color: textSecondary, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
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
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '• ${tx.notes}',
                      style: TextStyle(color: textSecondary, fontSize: 11, fontStyle: FontStyle.italic),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ] else
                  const Spacer(),
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
    final livePrice = holding.currentPrice > 0 ? holding.currentPrice : holding.averageBuyPrice;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTransactionScreen(
          initialType: type,
          preselectedSymbol: holding.symbol,
          preselectedCoinName: holding.name,
          preselectedCoinId: holding.coinId,
          prefilledPrice: livePrice > 0 ? livePrice : null,
          prefilledAmount: type == 'SELL' ? holding.totalQuantity : null,
        ),
      ),
    );
  }

  Future<void> _confirmDeleteTransaction(BuildContext context, TransactionModel tx) async {
    final surfaceColor = AppColors.surface(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);

    final isBuy = tx.type == 'BUY' || tx.type == 'LONG';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.delete_forever_rounded, color: AppColors.loss, size: 24),
            const SizedBox(width: 8),
            Text('Delete ${isBuy ? "BUY" : "SELL"} Order?', style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete this ${Formatters.cryptoAmount(tx.amount)} ${tx.symbol ?? widget.holding.symbol} order?\n\nYour portfolio holding and DCA metrics will be automatically recalculated.',
          style: TextStyle(color: textSecondary, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: textSecondary)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.loss,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      final success = await ref.read(transactionsProvider.notifier).deleteTransaction(tx.id);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(success ? 'Order deleted & DCA recalculated!' : 'Failed to delete transaction'),
            backgroundColor: success ? AppColors.profit : AppColors.loss,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _confirmClearAllCoinTransactions(
    BuildContext context,
    List<TransactionModel> txs,
    String symbol,
  ) async {
    final surfaceColor = AppColors.surface(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.loss, size: 24),
            const SizedBox(width: 8),
            Text('Clear All $symbol Orders?', style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete all ${txs.length} transactions for $symbol?\n\nThis will remove the entire position and reset all related DCA metrics.',
          style: TextStyle(color: textSecondary, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.loss,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete All', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      final notifier = ref.read(transactionsProvider.notifier);
      for (final tx in txs) {
        await notifier.deleteTransaction(tx.id);
      }
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('All $symbol orders deleted successfully.'),
            backgroundColor: AppColors.profit,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    }
  }
}
