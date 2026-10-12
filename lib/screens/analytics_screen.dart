import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/export_service.dart';
import '../core/utils/formatters.dart';
import '../data/models/holding_model.dart';
import '../data/models/transaction_model.dart';
import '../providers/currency_provider.dart';
import '../providers/portfolio_provider.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  String _selectedRange = '30D';
  int _touchedPieIndex = -1;

  @override
  Widget build(BuildContext context) {
    final portfolioAsync = ref.watch(portfolioSummaryProvider);
    final txAsync = ref.watch(transactionsProvider);
    final currency = ref.watch(currencyProvider);

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
          'Financial Reports & KPIs',
          style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Report Snapshot',
            icon: Icon(Icons.description_outlined, color: AppColors.primary),
            onPressed: () {
              portfolioAsync.whenData((p) {
                final txList = txAsync.asData?.value ?? [];
                final totalFees = txList.fold<double>(0.0, (sum, t) => sum + t.fee);
                _showReportSnapshot(context, p, totalFees, txList);
              });
            },
          ),
        ],
      ),
      body: portfolioAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: AppColors.loss))),
        data: (portfolio) {
          final txList = txAsync.asData?.value ?? [];
          final totalFees = txList.fold<double>(0.0, (sum, t) => sum + t.fee);
          final totalTrades = txList.length;

          HoldingModel? topPerformer;
          HoldingModel? worstPerformer;
          int profitableCount = 0;

          if (portfolio.holdings.isNotEmpty) {
            topPerformer = portfolio.holdings.reduce(
              (curr, next) => curr.unrealizedPnlPercentage > next.unrealizedPnlPercentage ? curr : next,
            );
            worstPerformer = portfolio.holdings.reduce(
              (curr, next) => curr.unrealizedPnlPercentage < next.unrealizedPnlPercentage ? curr : next,
            );
            profitableCount = portfolio.holdings.where((h) => h.unrealizedPnl >= 0).length;
          }

          final winRatePct = portfolio.holdings.isNotEmpty
              ? (profitableCount / portfolio.holdings.length) * 100
              : 0.0;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 1. Fixed Institutional Segmented Timeframe Selector (NO checkmark, NO size jumping)
              _buildSegmentedTimeSelector(surfaceColor, borderColor, textSecondary),
              const SizedBox(height: 20),

              // 2. Interactive Equity Trend Line Chart
              _buildTrendLineChart(context, portfolio, isDark, txList),
              const SizedBox(height: 20),

              // 3. Financial KPI Dashboard Cards (Top Performer, Worst Performer, Win Rate, Fees)
              _buildKpiMetricsGrid(
                context,
                topPerformer,
                worstPerformer,
                winRatePct,
                totalFees,
                totalTrades,
                profitableCount,
                portfolio.holdings.length,
              ),
              const SizedBox(height: 20),

              // 4. Asset Allocation Pie Chart (Capital Weighting)
              _buildAllocationCard(context, portfolio),
              const SizedBox(height: 20),

              // 5. Profit / Loss Breakdown Summary
              Row(
                children: [
                  Expanded(
                    child: _statCard(
                      context,
                      'Unrealized PnL',
                      Formatters.currency(portfolio.unrealizedPnl, currency),
                      Formatters.percentage(portfolio.unrealizedPnlPercentage),
                      portfolio.unrealizedPnl >= 0,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _statCard(
                      context,
                      'Realized Profit',
                      Formatters.currency(portfolio.realizedPnl, currency),
                      'From Closed Sells',
                      portfolio.realizedPnl >= 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 6. Comprehensive Asset-by-Asset Performance Table
              Container(
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
                        Text('Asset Performance Summary', style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
                        Text('${portfolio.holdings.length} Assets', style: TextStyle(color: textSecondary, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (portfolio.holdings.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text('No active asset positions to analyze', style: TextStyle(color: textMuted)),
                        ),
                      )
                    else
                      ...portfolio.holdings.map((h) {
                        final isProf = h.unrealizedPnl >= 0;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: surfaceLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor.withAlpha(50)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(h.symbol, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14)),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            h.name,
                                            style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'DCA Avg: ${Formatters.currency(h.averageBuyPrice, currency)} • Now: ${Formatters.currency(h.currentPrice, currency)}',
                                        style: TextStyle(color: textMuted, fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    Formatters.currency(h.unrealizedPnl, currency),
                                    style: TextStyle(color: isProf ? AppColors.profit : AppColors.loss, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isProf ? AppColors.profitBg : AppColors.lossBg,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      Formatters.percentage(h.unrealizedPnlPercentage),
                                      style: TextStyle(color: isProf ? AppColors.profit : AppColors.loss, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // 1. Institutional Segmented Timeframe Control without checkmarks or resizing
  Widget _buildSegmentedTimeSelector(Color surfaceColor, Color borderColor, Color textSecondary) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: ['7D', '30D', '90D', '1Y', 'ALL'].map((range) {
          final isSelected = _selectedRange == range;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedRange = range),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  range,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? Colors.white : textSecondary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // 2. Line Chart of Equity Curve (Constructed from Real Transaction Dates)
  Widget _buildTrendLineChart(BuildContext context, dynamic portfolio, bool isDark, List<TransactionModel> txList) {
    final surfaceColor = AppColors.surface(context);
    final borderColor = AppColors.border(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final textMuted = AppColors.textMuted(context);
    final currency = ref.watch(currencyProvider);

    final currentValue = portfolio.currentValue as double;

    // Filter transactions chronologically by selected timeframe
    final now = DateTime.now();
    DateTime cutoff;
    switch (_selectedRange) {
      case '7D':
        cutoff = now.subtract(const Duration(days: 7));
        break;
      case '30D':
        cutoff = now.subtract(const Duration(days: 30));
        break;
      case '90D':
        cutoff = now.subtract(const Duration(days: 90));
        break;
      case '1Y':
        cutoff = now.subtract(const Duration(days: 365));
        break;
      case 'ALL':
      default:
        cutoff = DateTime(2020);
        break;
    }

    final filtered = txList
        .where((t) => t.transactionDate.isAfter(cutoff))
        .toList()
      ..sort((a, b) => a.transactionDate.compareTo(b.transactionDate));

    final spots = <FlSpot>[];
    if (filtered.length >= 2) {
      double runningCost = 0;
      for (int i = 0; i < filtered.length; i++) {
        final t = filtered[i];
        if (t.type == 'BUY') {
          runningCost += t.totalAmount;
        } else if (t.type == 'SELL') {
          runningCost = (runningCost - t.totalAmount).clamp(0, double.infinity);
        }
        spots.add(FlSpot(i.toDouble(), runningCost));
      }
    }

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
                    Text(
                      'Equity Curve ($_selectedRange)',
                      style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Historical Capital Valuation Trajectory',
                      style: TextStyle(color: textSecondary, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryGlow,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(Formatters.currency(currentValue, currency), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (spots.length < 2)
            SizedBox(
              height: 120,
              child: Center(
                child: Text(
                  'Insufficient transaction history in $_selectedRange to plot trend.\nRecord more trades to observe valuation trajectory.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textMuted, fontSize: 12),
                ),
              ),
            )
          else
            SizedBox(
              height: 160,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: borderColor.withAlpha(40),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: (spots.length - 1).toDouble(),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: AppColors.primary,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withAlpha(isDark ? 80 : 50),
                            AppColors.primary.withAlpha(0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 3. Financial KPI Dashboard Grid
  Widget _buildKpiMetricsGrid(
    BuildContext context,
    HoldingModel? top,
    HoldingModel? worst,
    double winRatePct,
    double totalFees,
    int totalTrades,
    int profitableCount,
    int totalCoins,
  ) {
    final surfaceColor = AppColors.surface(context);
    final borderColor = AppColors.border(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final currency = ref.watch(currencyProvider);

    return Column(
      children: [
        Row(
          children: [
            // Top Performer
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'Top Performer',
                            style: TextStyle(color: textSecondary, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.trending_up, color: AppColors.profit, size: 16),
                      ],
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        top != null ? top.symbol : 'None',
                        style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        top != null ? Formatters.percentage(top.unrealizedPnlPercentage) : '0.00%',
                        style: const TextStyle(color: AppColors.profit, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Underperformer
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'Underperformer',
                            style: TextStyle(color: textSecondary, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.trending_down, color: AppColors.loss, size: 16),
                      ],
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        worst != null ? worst.symbol : 'None',
                        style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        worst != null ? Formatters.percentage(worst.unrealizedPnlPercentage) : '0.00%',
                        style: TextStyle(
                          color: (worst?.unrealizedPnlPercentage ?? 0) >= 0 ? AppColors.profit : AppColors.loss,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Portfolio Win Rate
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'Health Win Rate',
                            style: TextStyle(color: textSecondary, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.pie_chart, color: AppColors.primary, size: 16),
                      ],
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${winRatePct.toStringAsFixed(0)}%',
                        style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '$profitableCount of $totalCoins in Profit',
                        style: TextStyle(color: textSecondary, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Trading Activity & Fees
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'Trading Fees Paid',
                            style: TextStyle(color: textSecondary, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.receipt_outlined, color: AppColors.gold, size: 16),
                      ],
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        Formatters.currency(totalFees, currency),
                        style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '$totalTrades total DCA orders',
                        style: TextStyle(color: textSecondary, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 4. Asset Allocation Card
  Widget _buildAllocationCard(BuildContext context, dynamic portfolio) {
    final surfaceColor = AppColors.surface(context);
    final borderColor = AppColors.border(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final textMuted = AppColors.textMuted(context);
    final currency = ref.watch(currencyProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Capital Allocation',
            style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Portfolio weighting by crypto asset',
            style: TextStyle(color: textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 20),
          if (portfolio.allocations.isEmpty)
            Center(child: Text('No allocations to display', style: TextStyle(color: textMuted)))
          else ...[
            SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (event, pieTouchResponse) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            pieTouchResponse == null ||
                            pieTouchResponse.touchedSection == null) {
                          _touchedPieIndex = -1;
                          return;
                        }
                        _touchedPieIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                      });
                    },
                  ),
                  sectionsSpace: 3,
                  centerSpaceRadius: 40,
                  sections: portfolio.allocations.asMap().entries.map<PieChartSectionData>((entry) {
                    final idx = entry.key;
                    final item = entry.value;
                    final isTouched = idx == _touchedPieIndex;
                    final radius = isTouched ? 45.0 : 38.0;
                    final color = AppColors.chartColors[idx % AppColors.chartColors.length];

                    return PieChartSectionData(
                      color: color,
                      value: item.percentage,
                      title: '${item.percentage.toStringAsFixed(0)}%',
                      radius: radius,
                      titleStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ...portfolio.allocations.asMap().entries.map<Widget>((entry) {
              final idx = entry.key;
              final item = entry.value;
              final color = AppColors.chartColors[idx % AppColors.chartColors.length];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              item.symbol,
                              style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${Formatters.currency(item.value, currency)} (${item.percentage.toStringAsFixed(1)}%)',
                      style: TextStyle(color: textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _statCard(BuildContext context, String title, String val, String subtitle, bool isPositive) {
    final surfaceColor = AppColors.surface(context);
    final borderColor = AppColors.border(context);
    final textSecondary = AppColors.textSecondary(context);
    final textMuted = AppColors.textMuted(context);

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
            title,
            style: TextStyle(color: textSecondary, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              val,
              style: TextStyle(
                color: isPositive ? AppColors.profit : AppColors.loss,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(color: textMuted, fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _showReportSnapshot(BuildContext context, dynamic portfolio, double totalFees, List<TransactionModel> txList) {
    final surfaceColor = AppColors.surface(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final currency = ref.read(currencyProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Portfolio Financial Statement',
                    style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 16),
            _snapshotRow('Total Market Valuation', Formatters.currency(portfolio.currentValue, currency), textPrimary, textSecondary),
            _snapshotRow('Cumulative Capital Invested', Formatters.currency(portfolio.totalInvested, currency), textPrimary, textSecondary),
            _snapshotRow('Total Trading Fees Paid', Formatters.currency(totalFees, currency), AppColors.loss, textSecondary),
            _snapshotRow('Unrealized PnL', Formatters.currency(portfolio.unrealizedPnl, currency), AppColors.profit, textSecondary),
            _snapshotRow('Closed Sells Realized Gain', Formatters.currency(portfolio.realizedPnl, currency), AppColors.profit, textSecondary),
            _snapshotRow('Active Asset Positions', '${portfolio.coinsCount} Assets', textPrimary, textSecondary),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                final success = await ExportService.shareCsvStatement(txList, currency);
                if (context.mounted && success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Financial CSV statement exported successfully!'), backgroundColor: AppColors.profit),
                  );
                }
              },
              icon: const Icon(Icons.share, size: 18, color: Colors.white),
              label: const Text('Export & Share Statement (CSV)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _snapshotRow(String label, String value, Color valueColor, Color labelColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: labelColor, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(value, style: TextStyle(color: valueColor, fontSize: 14, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
