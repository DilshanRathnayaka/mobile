import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/export_service.dart';
import '../core/utils/formatters.dart';
import '../data/models/holding_model.dart';
import '../data/models/portfolio_summary_model.dart';
import '../data/models/transaction_model.dart';
import '../providers/currency_provider.dart';
import '../providers/portfolio_provider.dart';
import '../widgets/realtime_status_badge.dart';
import '../widgets/skeleton_loading.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  String _selectedRange = '30D';
  int _touchedPieIndex = -1;
  String _assetFilter = 'ALL'; // 'ALL', 'PROFIT', 'DRAWDOWN', 'TOP_WEIGHT'

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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                'Financial Reports & KPIs',
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
        loading: () => const AnalyticsSkeleton(),
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

              // 4. Quant Risk & Return KPI Ratios (Sharpe Ratio, Profit Factor, MDD, Fee Drag)
              _buildRiskRatiosStrip(context, portfolio, txList, totalFees),
              const SizedBox(height: 20),

              // 5. DCA Execution Quality & Alpha Radar
              _buildDcaAlphaRadar(context, portfolio, txList),
              const SizedBox(height: 20),

              // 6. Capital Milestone Roadmap
              _buildMilestoneRoadmapCard(context, portfolio),
              const SizedBox(height: 20),

              // 7. Asset Allocation Pie Chart (Capital Weighting)
              _buildAllocationCard(context, portfolio),
              const SizedBox(height: 20),

              // 8. Profit / Loss Breakdown Summary
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

              // 9. Comprehensive Asset-by-Asset Performance Table with Filters
              _buildAssetPerformanceSection(context, portfolio, surfaceColor, surfaceLight, borderColor, textPrimary, textSecondary, textMuted, currency),
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
  Widget _buildTrendLineChart(BuildContext context, PortfolioSummaryModel portfolio, bool isDark, List<TransactionModel> txList) {
    final surfaceColor = AppColors.surface(context);
    final borderColor = AppColors.border(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final textMuted = AppColors.textMuted(context);
    final currency = ref.watch(currencyProvider);

    final currentValue = portfolio.currentValue;

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
  Widget _buildAllocationCard(BuildContext context, PortfolioSummaryModel portfolio) {
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

  // 4. Quant Risk & Return KPI Ratios (Sharpe Ratio, Profit Factor, MDD, Fee Drag)
  Widget _buildRiskRatiosStrip(BuildContext context, PortfolioSummaryModel portfolio, List<TransactionModel> txList, double totalFees) {
    final surfaceColor = AppColors.surface(context);
    final borderColor = AppColors.border(context);
    final textPrimary = AppColors.textPrimary(context);

    // 1. Sharpe Ratio
    double volatility = 18.0;
    if (portfolio.holdings.length > 1) {
      final mean = portfolio.unrealizedPnlPercentage;
      final sumSq = portfolio.holdings.fold<double>(0.0, (acc, h) => acc + math.pow((h.unrealizedPnlPercentage - mean), 2));
      final stdDev = math.sqrt(sumSq / portfolio.holdings.length);
      volatility = stdDev.clamp(10.0, 90.0);
    }
    final sharpe = ((portfolio.unrealizedPnlPercentage - 4.5) / volatility);

    // 2. Profit Factor
    final grossGains = portfolio.holdings.where((HoldingModel h) => h.unrealizedPnl > 0).fold<double>(0.0, (s, h) => s + h.unrealizedPnl) +
        (portfolio.realizedPnl > 0 ? portfolio.realizedPnl : 0.0);
    final grossLosses = portfolio.holdings.where((HoldingModel h) => h.unrealizedPnl < 0).fold<double>(0.0, (s, h) => s + h.unrealizedPnl.abs()) +
        (portfolio.realizedPnl < 0 ? portfolio.realizedPnl.abs() : 0.0);
    final profitFactor = grossLosses > 0 ? (grossGains / grossLosses) : (grossGains > 0 ? 9.99 : 1.0);

    // 3. Max Drawdown across holdings
    double maxHoldingDd = 0.0;
    for (final h in portfolio.holdings) {
      if (h.unrealizedPnlPercentage < maxHoldingDd) {
        maxHoldingDd = h.unrealizedPnlPercentage;
      }
    }

    // 4. Fee Drag
    final totalInvested = portfolio.totalInvested;
    final feeDrag = totalInvested > 0 ? (totalFees / totalInvested) * 100 : 0.0;

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
                child: Row(
                  children: [
                    const Icon(Icons.analytics_outlined, color: AppColors.primary, size: 18),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Quant Risk & Return Ratios',
                        style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryGlow,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('QUANT BENCHMARK', style: TextStyle(color: AppColors.primary, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildRatioTile(
                  context,
                  title: 'Sharpe Ratio',
                  value: sharpe.toStringAsFixed(2),
                  badge: sharpe >= 1.5 ? 'Excellent' : (sharpe >= 0.5 ? 'Moderate' : 'High Risk'),
                  badgeColor: sharpe >= 1.5 ? AppColors.profit : (sharpe >= 0.5 ? AppColors.primary : AppColors.loss),
                  subtitle: 'Rf 4.5% Risk Adj',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildRatioTile(
                  context,
                  title: 'Profit Factor',
                  value: profitFactor >= 9.9 ? '9.9+' : profitFactor.toStringAsFixed(2),
                  badge: profitFactor >= 2.0 ? 'Superb' : (profitFactor >= 1.0 ? 'Profitable' : 'Loss Drag'),
                  badgeColor: profitFactor >= 1.0 ? AppColors.profit : AppColors.loss,
                  subtitle: 'Gains / Losses',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildRatioTile(
                  context,
                  title: 'Deepest Dip',
                  value: Formatters.percentage(maxHoldingDd),
                  badge: maxHoldingDd >= -10 ? 'Protected' : (maxHoldingDd >= -25 ? 'Normal' : 'High Dip'),
                  badgeColor: maxHoldingDd >= -15 ? AppColors.profit : (maxHoldingDd >= -30 ? AppColors.gold : AppColors.loss),
                  subtitle: 'Max Asset DD',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildRatioTile(
                  context,
                  title: 'Fee Drag',
                  value: '${feeDrag.toStringAsFixed(2)}%',
                  badge: feeDrag < 0.5 ? 'Optimal' : 'High Fees',
                  badgeColor: feeDrag < 0.5 ? AppColors.profit : AppColors.loss,
                  subtitle: 'Capital Friction',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRatioTile(
    BuildContext context, {
    required String title,
    required String value,
    required String badge,
    required Color badgeColor,
    required String subtitle,
  }) {
    final surfaceLight = AppColors.surfaceLight(context);
    final borderColor = AppColors.border(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final textMuted = AppColors.textMuted(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(color: textSecondary, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: badgeColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badge,
                  style: TextStyle(color: badgeColor, fontSize: 9, fontWeight: FontWeight.bold),
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
              style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
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

  // 5. DCA Execution Quality & Alpha Radar
  Widget _buildDcaAlphaRadar(BuildContext context, PortfolioSummaryModel portfolio, List<TransactionModel> txList) {
    final surfaceColor = AppColors.surface(context);
    final borderColor = AppColors.border(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final textMuted = AppColors.textMuted(context);
    final currency = ref.watch(currencyProvider);

    // DCA Execution Advantage
    double avgDiscountPct = 0.0;
    if (portfolio.holdings.isNotEmpty) {
      double totalDiscount = 0.0;
      for (final h in portfolio.holdings) {
        if (h.currentPrice > 0) {
          totalDiscount += ((h.currentPrice - h.averageBuyPrice) / h.currentPrice) * 100;
        }
      }
      avgDiscountPct = totalDiscount / portfolio.holdings.length;
    }

    final avgTicket = txList.isNotEmpty ? (portfolio.totalInvested / txList.length) : 0.0;
    final topAllocPct = portfolio.allocations.isNotEmpty
        ? portfolio.allocations.map((a) => a.percentage).reduce(math.max)
        : 0.0;

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
                child: Row(
                  children: [
                    const Icon(Icons.radar_outlined, color: AppColors.primary, size: 18),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'DCA Execution & Alpha Radar',
                        style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: avgDiscountPct >= 0 ? AppColors.profitBg : AppColors.lossBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  avgDiscountPct >= 0 ? 'ALPHA EDGE' : 'ACCUMULATING',
                  style: TextStyle(
                    color: avgDiscountPct >= 0 ? AppColors.profit : AppColors.loss,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor.withAlpha(50)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('DCA Entry Edge', style: TextStyle(color: textSecondary, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          Formatters.percentage(avgDiscountPct),
                          style: TextStyle(
                            color: avgDiscountPct >= 0 ? AppColors.profit : AppColors.loss,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        avgDiscountPct >= 0 ? 'Cost below market spot' : 'Averaging down in dip',
                        style: TextStyle(color: textMuted, fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor.withAlpha(50)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Avg DCA Ticket', style: TextStyle(color: textSecondary, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          Formatters.currency(avgTicket, currency),
                          style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Per order allocation',
                        style: TextStyle(color: textMuted, fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor.withAlpha(50)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        topAllocPct > 50 ? Icons.warning_amber_rounded : Icons.pie_chart_outline,
                        color: topAllocPct > 50 ? AppColors.gold : AppColors.primary,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Max Position Concentration:',
                          style: TextStyle(color: textSecondary, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${topAllocPct.toStringAsFixed(1)}% (${topAllocPct > 50 ? 'High' : 'Balanced'})',
                  style: TextStyle(
                    color: topAllocPct > 50 ? AppColors.gold : AppColors.profit,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 6. Capital Milestone Roadmap
  Widget _buildMilestoneRoadmapCard(BuildContext context, PortfolioSummaryModel portfolio) {
    final surfaceColor = AppColors.surface(context);
    final borderColor = AppColors.border(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final currency = ref.watch(currencyProvider);

    final double currentVal = portfolio.currentValue;
    final milestones = <double>[500.0, 1000.0, 2500.0, 5000.0, 10000.0, 25000.0, 50000.0, 100000.0, 250000.0, 500000.0, 1000000.0];

    double target = milestones.firstWhere((double m) => m > currentVal, orElse: () => currentVal * 1.5);
    int targetIndex = milestones.indexOf(target);
    double prevMilestone = targetIndex > 0 ? milestones[targetIndex - 1] : 0.0;

    double progress = target > prevMilestone
        ? ((currentVal - prevMilestone) / (target - prevMilestone)).clamp(0.0, 1.0)
        : 1.0;
    double overallPct = target > 0 ? (currentVal / target * 100).clamp(0.0, 100.0) : 100.0;
    double remaining = (target - currentVal) > 0 ? (target - currentVal) : 0.0;

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
                child: Row(
                  children: [
                    const Icon(Icons.flag_outlined, color: AppColors.primary, size: 18),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Capital Milestone Roadmap',
                        style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryGlow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${overallPct.toStringAsFixed(1)}% Goal',
                  style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Next Goal: ${Formatters.currency(target, currency)}',
                style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Text(
                '${Formatters.currency(remaining, currency)} remaining',
                style: TextStyle(color: textSecondary, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.surfaceLight(context),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Base: ${Formatters.currency(prevMilestone, currency)}',
                style: TextStyle(color: AppColors.textMuted(context), fontSize: 10),
              ),
              Text(
                'Target: ${Formatters.currency(target, currency)}',
                style: TextStyle(color: AppColors.textMuted(context), fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 9. Comprehensive Asset-by-Asset Performance Section with Dynamic Filter Chips
  Widget _buildAssetPerformanceSection(
    BuildContext context,
    PortfolioSummaryModel portfolio,
    Color surfaceColor,
    Color surfaceLight,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
    dynamic currency,
  ) {
    List<HoldingModel> displayedHoldings = portfolio.holdings;
    if (_assetFilter == 'PROFIT') {
      displayedHoldings = portfolio.holdings.where((HoldingModel h) => h.unrealizedPnl >= 0).toList();
    } else if (_assetFilter == 'DRAWDOWN') {
      displayedHoldings = portfolio.holdings.where((HoldingModel h) => h.unrealizedPnl < 0).toList();
    } else if (_assetFilter == 'TOP_WEIGHT') {
      final totalVal = portfolio.currentValue;
      displayedHoldings = portfolio.holdings.where((HoldingModel h) => totalVal > 0 && (h.currentValue / totalVal) >= 0.10).toList();
    }

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
              Text('Asset Performance Summary', style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
              Text('${displayedHoldings.length} of ${portfolio.holdings.length} Assets', style: TextStyle(color: textSecondary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildAssetFilterChip('ALL', 'All (${portfolio.holdings.length})'),
                const SizedBox(width: 6),
                _buildAssetFilterChip('PROFIT', 'Profit (${portfolio.holdings.where((HoldingModel h) => h.unrealizedPnl >= 0).length})'),
                const SizedBox(width: 6),
                _buildAssetFilterChip('DRAWDOWN', 'Dip (${portfolio.holdings.where((HoldingModel h) => h.unrealizedPnl < 0).length})'),
                const SizedBox(width: 6),
                _buildAssetFilterChip(
                  'TOP_WEIGHT',
                  'Weight > 10% (${portfolio.holdings.where((HoldingModel h) => portfolio.currentValue > 0 && (h.currentValue / portfolio.currentValue) >= 0.10).length})',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          if (portfolio.holdings.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('No active asset positions to analyze', style: TextStyle(color: textMuted)),
              ),
            )
          else if (displayedHoldings.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('No positions match "$_assetFilter" filter', style: TextStyle(color: textMuted)),
              ),
            )
          else
            ...displayedHoldings.map((h) {
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
    );
  }

  Widget _buildAssetFilterChip(String filterKey, String label) {
    final isSelected = _assetFilter == filterKey;
    return GestureDetector(
      onTap: () => setState(() => _assetFilter = filterKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceLight(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border(context),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary(context),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Future<void> _copyExecutiveReport(BuildContext context, PortfolioSummaryModel portfolio, double totalFees, List<TransactionModel> txList) async {
    final currency = ref.read(currencyProvider);
    final now = DateTime.now();
    final formattedDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final buffer = StringBuffer();
    buffer.writeln('====================================================');
    buffer.writeln('📈 FINANCIAL & ASSET KPI EXECUTIVE REPORT');
    buffer.writeln('Generated: $formattedDate');
    buffer.writeln('====================================================');
    buffer.writeln('Valuation:        ${Formatters.currency(portfolio.currentValue, currency)}');
    buffer.writeln('Total Invested:   ${Formatters.currency(portfolio.totalInvested, currency)}');
    buffer.writeln('Unrealized PnL:   ${Formatters.currency(portfolio.unrealizedPnl, currency)} (${Formatters.percentage(portfolio.unrealizedPnlPercentage)})');
    buffer.writeln('Realized Profit:  ${Formatters.currency(portfolio.realizedPnl, currency)}');
    buffer.writeln('Trading Fees:     ${Formatters.currency(totalFees, currency)}');
    buffer.writeln('Active Holdings:  ${portfolio.coinsCount} assets');
    buffer.writeln('----------------------------------------------------');
    buffer.writeln('HOLDINGS PERFORMANCE:');
    for (final h in portfolio.holdings) {
      buffer.writeln('- ${h.symbol} (${h.name}): ${Formatters.currency(h.currentValue, currency)} | DCA: ${Formatters.currency(h.averageBuyPrice, currency)} | PnL: ${Formatters.percentage(h.unrealizedPnlPercentage)}');
    }
    buffer.writeln('====================================================');

    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Executive Markdown statement copied to clipboard!'),
          backgroundColor: AppColors.profit,
        ),
      );
    }
  }

  void _showReportSnapshot(BuildContext context, PortfolioSummaryModel portfolio, double totalFees, List<TransactionModel> txList) {
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
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _copyExecutiveReport(context, portfolio, totalFees, txList);
                    },
                    icon: const Icon(Icons.copy_outlined, size: 16),
                    label: const Text('Copy Audit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size.fromHeight(46),
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
                    icon: const Icon(Icons.share, size: 16, color: Colors.white),
                    label: const Text('Share CSV', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ],
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
