import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/formatters.dart';
import '../providers/currency_provider.dart';
import '../providers/portfolio_provider.dart';
import 'transactions_history_screen.dart';
import 'position_detail_screen.dart';
import '../widgets/realtime_status_badge.dart';
import '../widgets/skeleton_loading.dart';

class HoldingsScreen extends ConsumerWidget {
  const HoldingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final portfolioAsync = ref.watch(portfolioSummaryProvider);
    final isHidden = ref.watch(isBalanceHiddenProvider);
    final currency = ref.watch(currencyProvider);

    final bgColor = AppColors.background(context);
    final surfaceColor = AppColors.surface(context);
    final surfaceLight = AppColors.surfaceLight(context);
    final borderColor = AppColors.border(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final textMuted = AppColors.textMuted(context);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                'Positions & DCA Performance',
                style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            const RealtimeStatusBadge(size: 6),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Transaction History',
            icon: Icon(Icons.history, color: textSecondary),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TransactionsHistoryScreen()),
              );
            },
          ),
        ],
      ),
      body: portfolioAsync.when(
        loading: () => const HoldingsSkeleton(),
        error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: AppColors.loss))),
        data: (portfolio) {
          final activeHoldings = portfolio.holdings
              .where((h) => h.totalQuantity > 0.00000001)
              .toList();

          if (activeHoldings.isEmpty) {
            return Center(
              child: Text('No positions found. Add your first DCA buy!', style: TextStyle(color: textSecondary)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: activeHoldings.length,
            itemBuilder: (context, index) {
              final h = activeHoldings[index];
              final isProfit = h.unrealizedPnl >= 0;

              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => PositionDetailScreen(holding: h)),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      // Coin Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: surfaceLight,
                                child: Text(
                                  h.symbol.substring(0, h.symbol.length > 3 ? 3 : h.symbol.length),
                                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(h.name, style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                                  Text(
                                    isHidden ? '•••• ${h.symbol}' : '${Formatters.cryptoAmount(h.totalQuantity)} ${h.symbol}',
                                    style: TextStyle(color: textSecondary, fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                isHidden ? '••••' : Formatters.currency(h.currentValue, currency),
                                style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                isHidden ? '•••' : '${Formatters.percentage(h.unrealizedPnlPercentage)} (${Formatters.currency(h.unrealizedPnl, currency)})',
                                style: TextStyle(color: isProfit ? AppColors.profit : AppColors.loss, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),

                      Divider(color: borderColor, height: 24),

                      // Metrics Grid (DCA Avg, Live Price, Total Cost)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _metricColumn('DCA Avg Price', Formatters.currency(h.averageBuyPrice, currency), textPrimary, textMuted),
                          _metricColumn('Market Price', Formatters.currency(h.currentPrice, currency), textPrimary, textMuted),
                          _metricColumn('Cost Basis', isHidden ? '••••' : Formatters.currency(h.totalInvestedCost, currency), textPrimary, textMuted),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _metricColumn(String label, String value, Color textColor, Color labelColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: labelColor, fontSize: 11)),
        const SizedBox(height: 3),
        Text(value, style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
