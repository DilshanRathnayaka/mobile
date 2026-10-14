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
import 'position_detail_screen.dart';
import '../widgets/skeleton_loading.dart';

class TransactionsHistoryScreen extends ConsumerStatefulWidget {
  final String? initialCoinFilter; // e.g. 'BTC'

  const TransactionsHistoryScreen({super.key, this.initialCoinFilter});

  @override
  ConsumerState<TransactionsHistoryScreen> createState() => _TransactionsHistoryScreenState();
}

class _TransactionsHistoryScreenState extends ConsumerState<TransactionsHistoryScreen> {
  String _selectedTypeFilter = 'ALL'; // 'ALL', 'BUY', 'SELL', 'SALARY_DEPOSIT'
  String? _selectedCoinFilter;

  @override
  void initState() {
    super.initState();
    _selectedCoinFilter = widget.initialCoinFilter;
  }

  @override
  Widget build(BuildContext context) {
    final txAsync = ref.watch(transactionsProvider);
    final portfolioAsync = ref.watch(portfolioSummaryProvider);
    final currency = ref.watch(currencyProvider);

    final bgColor = AppColors.background(context);
    final surfaceColor = AppColors.surface(context);
    final borderColor = AppColors.border(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final textMuted = AppColors.textMuted(context);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text(
          'Transactions & Trade History',
          style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Add New Transaction',
            icon: const Icon(Icons.add, color: AppColors.primary),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
              );
            },
          ),
        ],
      ),
      body: txAsync.when(
        loading: () => const TransactionsSkeleton(),
        error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: AppColors.loss))),
        data: (allTransactions) {
          if (allTransactions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined, color: textMuted, size: 54),
                  const SizedBox(height: 12),
                  Text('No transactions recorded yet', style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('Add your first DCA buy or deposit to start tracking.', style: TextStyle(color: textSecondary, fontSize: 13)),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
                      );
                    },
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text('Add Transaction', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          }

          // Extract unique coins present in transaction history
          final availableCoins = allTransactions
              .where((t) => t.symbol != null && t.symbol!.isNotEmpty)
              .map((t) => t.symbol!.toUpperCase())
              .toSet()
              .toList()
            ..sort();

          // Apply filters
          final filteredTransactions = allTransactions.where((tx) {
            bool matchesType = false;
            if (_selectedTypeFilter == 'ALL') {
              matchesType = true;
            } else if (_selectedTypeFilter == 'BUY') {
              matchesType = tx.isSpotBuy;
            } else if (_selectedTypeFilter == 'SELL') {
              matchesType = tx.isSpotSell;
            } else if (_selectedTypeFilter == 'LONG') {
              matchesType = tx.isFutures && (tx.type == 'LONG' || tx.type == 'BUY');
            } else if (_selectedTypeFilter == 'SHORT') {
              matchesType = tx.isFutures && (tx.type == 'SHORT' || tx.type == 'SELL');
            } else if (_selectedTypeFilter == 'P2P') {
              matchesType = tx.isP2P;
            } else if (_selectedTypeFilter == 'DEPOSIT') {
              matchesType = tx.isCashflow && !tx.isP2P;
            } else {
              matchesType = tx.type == _selectedTypeFilter;
            }
            final matchesCoin = _selectedCoinFilter == null || (tx.symbol != null && tx.symbol!.toUpperCase() == _selectedCoinFilter);
            return matchesType && matchesCoin;
          }).toList();

          final totalSellsVolume = allTransactions.where((t) => t.isSpotSell).fold<double>(0.0, (sum, t) => sum + t.totalAmount);
          final totalBuysVolume = allTransactions.where((t) => t.isSpotBuy).fold<double>(0.0, (sum, t) => sum + t.totalAmount);
          final totalP2pVolume = allTransactions.where((t) => t.isP2P).fold<double>(0.0, (sum, t) => sum + t.totalAmount);

          return Column(
            children: [
              // 1. Filter Chips Row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: bgColor,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _typeFilterChip('All Activity', 'ALL'),
                      const SizedBox(width: 8),
                      _typeFilterChip('Spot Buys', 'BUY', color: AppColors.profit),
                      const SizedBox(width: 8),
                      _typeFilterChip('Spot Sells', 'SELL', color: AppColors.loss),
                      const SizedBox(width: 8),
                      _typeFilterChip('Futures Long', 'LONG', color: const Color(0xFF00C087)),
                      const SizedBox(width: 8),
                      _typeFilterChip('Futures Short', 'SHORT', color: const Color(0xFFFF4D4F)),
                      const SizedBox(width: 8),
                      _typeFilterChip('P2P Orders', 'P2P', color: const Color(0xFFF59E0B)),
                      const SizedBox(width: 8),
                      _typeFilterChip('Deposits', 'DEPOSIT', color: AppColors.gold),
                    ],
                  ),
                ),
              ),

              // 2. Coin Quick Selector Bar (if coins exist)
              if (availableCoins.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Text('Asset Filter: ', style: TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 6),
                        _coinChip('All Assets', null),
                        const SizedBox(width: 6),
                        ...availableCoins.map((c) => Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: _coinChip(c, c),
                            )),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 6),

              // 3. Transactions Count & Volume Summary Strip
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        '${filteredTransactions.length} records found',
                        style: TextStyle(color: textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_selectedTypeFilter == 'SELL')
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Total Spot Sold: ${Formatters.currency(totalSellsVolume, currency)}',
                            style: const TextStyle(color: AppColors.loss, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      )
                    else if (_selectedTypeFilter == 'BUY')
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Total DCA Capital: ${Formatters.currency(totalBuysVolume, currency)}',
                            style: const TextStyle(color: AppColors.profit, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      )
                    else if (_selectedTypeFilter == 'P2P')
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Total P2P: ${Formatters.currency(totalP2pVolume, currency)}',
                            style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // 4. Transactions List
              Expanded(
                child: filteredTransactions.isEmpty
                    ? Center(
                        child: Text(
                          'No transactions match this filter',
                          style: TextStyle(color: textMuted, fontSize: 14),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        itemCount: filteredTransactions.length,
                        itemBuilder: (context, index) {
                          final tx = filteredTransactions[index];
                          final isLong = tx.type == 'LONG' || (tx.type == 'BUY' && tx.isFutures);
                          final isShort = tx.type == 'SHORT' || (tx.type == 'SELL' && tx.isFutures);
                          final isP2p = tx.isP2P;
                          final isBuy = tx.isSpotBuy;
                          final isSell = tx.isSpotSell;
                          final isSalary = tx.type == 'SALARY_DEPOSIT' || (tx.type == 'DEPOSIT' && !isP2p);

                          final Color color;
                          if (isP2p) {
                            color = const Color(0xFFF59E0B);
                          } else if (isBuy || isLong) {
                            color = AppColors.profit;
                          } else if (isSalary) {
                            color = AppColors.gold;
                          } else {
                            color = AppColors.loss;
                          }

                          return InkWell(
                            onTap: () => _showTransactionDetailSheet(context, tx, portfolioAsync, currency),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: surfaceColor,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isP2p ? const Color(0xFFF59E0B).withAlpha(80) : borderColor,
                                  width: isP2p ? 1.2 : 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Icon Badge
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: color.withAlpha(25),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      isP2p
                                          ? Icons.handshake_rounded
                                          : (isBuy || isLong)
                                              ? Icons.arrow_downward_rounded
                                              : (isSalary ? Icons.payments_rounded : Icons.arrow_upward_rounded),
                                      color: color,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Center Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                isP2p
                                                    ? (tx.type == 'BUY' || tx.type == 'DEPOSIT' ? 'P2P Buy' : 'P2P Sell')
                                                    : (isSalary ? 'Cashflow Deposit' : '${tx.type} ${tx.symbol ?? ""}'),
                                                style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (tx.isFutures) ...[
                                              const SizedBox(width: 5),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF0B90B).withAlpha(35),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: const Color(0xFFF0B90B).withAlpha(120), width: 0.8),
                                                ),
                                                child: Text(
                                                  '${tx.leverage.toInt()}x ${isLong ? "LONG" : (isShort ? "SHORT" : "PERP")}',
                                                  style: const TextStyle(color: Color(0xFFF0B90B), fontSize: 9, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ] else if (isP2p) ...[
                                              const SizedBox(width: 5),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF59E0B).withAlpha(35),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: const Color(0xFFF59E0B).withAlpha(120), width: 0.8),
                                                ),
                                                child: const Text('P2P FIAT', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 9, fontWeight: FontWeight.bold)),
                                              ),
                                            ] else if (isSell) ...[
                                              const SizedBox(width: 5),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppColors.lossBg,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: const Text('SPOT SOLD', style: TextStyle(color: AppColors.loss, fontSize: 9, fontWeight: FontWeight.bold)),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          DateFormat('dd MMM yyyy, hh:mm a').format(tx.transactionDate),
                                          style: TextStyle(color: textMuted, fontSize: 11),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (tx.notes.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 2),
                                            child: Text(
                                              tx.notes,
                                              style: TextStyle(color: textSecondary, fontSize: 11, fontStyle: FontStyle.italic),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Right Amount & Action
                                  Flexible(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Flexible(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              FittedBox(
                                                fit: BoxFit.scaleDown,
                                                alignment: Alignment.centerRight,
                                                child: Text(
                                                  Formatters.currency(tx.totalAmount, currency),
                                                  style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                              if (!isSalary)
                                                FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  alignment: Alignment.centerRight,
                                                  child: Text(
                                                    '${Formatters.cryptoAmount(tx.amount)} @ ${Formatters.currency(tx.pricePerUnit, currency)}',
                                                    style: TextStyle(color: textSecondary, fontSize: 11),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        InkWell(
                                          borderRadius: BorderRadius.circular(20),
                                          onTap: () => _confirmDelete(context, tx),
                                          child: Padding(
                                            padding: const EdgeInsets.all(6.0),
                                            child: Icon(Icons.delete_outline, color: AppColors.loss.withAlpha(190), size: 19),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
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
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _typeFilterChip(String label, String key, {Color? color}) {
    final isSelected = _selectedTypeFilter == key;
    return InkWell(
      onTap: () => setState(() => _selectedTypeFilter = key),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? (color ?? AppColors.primary) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? (color ?? AppColors.primary) : Colors.grey.withAlpha(80),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? (color != null ? Colors.white : Colors.black) : Colors.grey,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _coinChip(String label, String? coinSymbol) {
    final isSelected = _selectedCoinFilter == coinSymbol;
    return InkWell(
      onTap: () => setState(() => _selectedCoinFilter = coinSymbol),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withAlpha(30) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.withAlpha(60),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.primary : Colors.grey,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  void _showTransactionDetailSheet(
    BuildContext context,
    TransactionModel tx,
    AsyncValue<dynamic> portfolioAsync,
    CurrencyInfo currency,
  ) {
    final surfaceColor = AppColors.surface(context);
    final borderColor = AppColors.border(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final textMuted = AppColors.textMuted(context);

    final isBuy = tx.type == 'BUY';
    final isSell = tx.type == 'SELL';
    final isSalary = tx.type == 'SALARY_DEPOSIT';
    final color = isBuy ? AppColors.profit : (isSalary ? AppColors.gold : AppColors.loss);

    showModalBottomSheet(
      context: context,
      backgroundColor: surfaceColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.88,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: color.withAlpha(25), shape: BoxShape.circle),
                              child: Icon(isBuy ? Icons.arrow_downward : (isSalary ? Icons.payments : Icons.arrow_upward), color: color, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isSalary ? 'Salary Inflow Record' : '${tx.type} Order Details',
                                    style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    DateFormat('dd MMMM yyyy, hh:mm a').format(tx.transactionDate),
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
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(color: borderColor),
                  const SizedBox(height: 12),

              // Breakdown rows
              if (!isSalary) ...[
                _detailRow('Asset / Crypto', '${tx.name ?? tx.symbol} (${tx.symbol})', textPrimary, textMuted),
                if (tx.isFutures) ...[
                  const SizedBox(height: 10),
                  _detailRow(
                    'Market & Leverage',
                    '${tx.leverage.toInt()}x Isolated Futures (${tx.isLong ? "LONG" : "SHORT"})',
                    const Color(0xFFF0B90B),
                    textMuted,
                    isBold: true,
                  ),
                  if (tx.margin != null && tx.margin! > 0) ...[
                    const SizedBox(height: 10),
                    _detailRow(
                      'Initial Margin / Collateral',
                      Formatters.currency(tx.margin!, currency),
                      const Color(0xFFF0B90B),
                      textMuted,
                      isBold: true,
                    ),
                  ],
                  if (tx.liquidationPrice != null && tx.liquidationPrice! > 0) ...[
                    const SizedBox(height: 10),
                    _detailRow(
                      'Estimated Liquidation Price',
                      Formatters.currency(tx.liquidationPrice!, currency),
                      AppColors.loss,
                      textMuted,
                      isBold: true,
                    ),
                  ],
                ],
                const SizedBox(height: 10),
                _detailRow(
                  (isBuy || tx.isLong) ? 'Entry Price per Unit' : 'Execution Sell Price per Unit',
                  Formatters.currency(tx.pricePerUnit, currency),
                  textPrimary,
                  textMuted,
                  isBold: true,
                ),
                const SizedBox(height: 10),
                _detailRow(
                  isBuy ? 'Quantity Acquired' : 'Quantity Liquidated',
                  '${Formatters.cryptoAmount(tx.amount)} ${tx.symbol ?? ""}',
                  color,
                  textMuted,
                  isBold: true,
                ),
                const SizedBox(height: 10),
                _detailRow('Total Order Value', Formatters.currency(tx.totalAmount, currency), textPrimary, textMuted, isBold: true),
                const SizedBox(height: 10),
                _detailRow('Trading Fee', tx.fee > 0 ? Formatters.currency(tx.fee, currency) : 'Free (\$0.00)', textSecondary, textMuted),
              ] else ...[
                _detailRow('Deposit Amount', Formatters.currency(tx.totalAmount, currency), AppColors.gold, textMuted, isBold: true),
              ],

              if (tx.notes.isNotEmpty) ...[
                const SizedBox(height: 10),
                _detailRow('Notes / Strategy', tx.notes, textSecondary, textMuted),
              ],

              const SizedBox(height: 20),

              // Button to view full Asset DCA lifecycle (if crypto)
              if (tx.symbol != null && tx.symbol!.isNotEmpty) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      // Try to locate holding or build representative holding
                      final portfolio = portfolioAsync.valueOrNull;
                      HoldingModel? matchedHolding;
                      if (portfolio != null) {
                        final found = portfolio.holdings.where((h) => h.symbol.toUpperCase() == tx.symbol!.toUpperCase());
                        if (found.isNotEmpty) matchedHolding = found.first;
                      }

                      matchedHolding ??= HoldingModel(
                        id: tx.coinId ?? tx.symbol!,
                        coinId: tx.coinId ?? tx.symbol!.toLowerCase(),
                        symbol: tx.symbol!.toUpperCase(),
                        name: tx.name ?? tx.symbol!.toUpperCase(),
                        totalQuantity: tx.amount,
                        averageBuyPrice: tx.pricePerUnit,
                        currentPrice: tx.pricePerUnit,
                        change24h: 0.0,
                        totalInvestedCost: tx.totalAmount,
                        currentValue: tx.totalAmount,
                        unrealizedPnl: 0.0,
                        unrealizedPnlPercentage: 0.0,
                        realizedPnl: isSell ? tx.totalAmount : 0.0,
                      );

                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => PositionDetailScreen(holding: matchedHolding!)),
                      );
                    },
                    icon: const Icon(Icons.show_chart_rounded, size: 18),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('View Full ${tx.symbol} DCA & Position History', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Edit & Delete Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => AddTransactionScreen(transactionToEdit: tx)),
                        );
                      },
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Edit Order', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.loss,
                        side: const BorderSide(color: AppColors.loss),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _confirmDelete(context, tx, parentSheetCtx: ctx),
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  },
);
}

  Widget _detailRow(String label, String value, Color textColor, Color labelColor, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(color: labelColor, fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          flex: 3,
          child: Text(
            value,
            style: TextStyle(color: textColor, fontSize: 13.5, fontWeight: isBold ? FontWeight.bold : FontWeight.w500),
            textAlign: TextAlign.end,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    TransactionModel tx, {
    BuildContext? parentSheetCtx,
  }) async {
    final surfaceColor = AppColors.surface(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.delete_forever_rounded, color: AppColors.loss, size: 24),
            const SizedBox(width: 8),
            Text('Delete ${tx.type} Order?', style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete this ${Formatters.cryptoAmount(tx.amount)} ${tx.symbol ?? ""} transaction?\n\nYour portfolio holdings and DCA metrics will automatically be recalculated.',
          style: TextStyle(color: textSecondary, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: Text('Cancel', style: TextStyle(color: textSecondary)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.loss,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(dCtx, true),
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      if (parentSheetCtx != null && parentSheetCtx.mounted) {
        Navigator.pop(parentSheetCtx);
      }
      final messenger = ScaffoldMessenger.of(context);
      final success = await ref.read(transactionsProvider.notifier).deleteTransaction(tx.id);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(success ? 'Transaction deleted & portfolio updated!' : 'Failed to delete transaction'),
            backgroundColor: success ? AppColors.profit : AppColors.loss,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
