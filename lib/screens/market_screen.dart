import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/formatters.dart';
import '../data/models/binance_ticker_model.dart';
import '../providers/binance_provider.dart';
import '../providers/currency_provider.dart';
import 'add_transaction_screen.dart';
import 'profit_calculator_screen.dart';
import 'crypto_intelligence_screen.dart';
import 'coin_chart_screen.dart';
import '../widgets/realtime_status_badge.dart';
import '../widgets/skeleton_loading.dart';

class MarketScreen extends ConsumerStatefulWidget {
  const MarketScreen({super.key});

  @override
  ConsumerState<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends ConsumerState<MarketScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'ALL'; // ALL, GAINERS, LOSERS, VOLUME

  @override
  Widget build(BuildContext context) {
    final tickersAsync = ref.watch(binanceTickersProvider);
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
        titleSpacing: 16,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Markets', style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            const RealtimeStatusBadge(size: 6),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Market Wire & News',
            icon: const Icon(Icons.bolt_rounded, color: Color(0xFF00E676), size: 24),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CryptoIntelligenceScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Profit & ROI Calculator',
            icon: const Icon(Icons.calculate_outlined, color: AppColors.primary, size: 24),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfitCalculatorScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Refresh Prices',
            icon: Icon(Icons.refresh, color: textSecondary),
            onPressed: () => ref.read(binanceTickersProvider.notifier).fetchTickers(),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Search Box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              style: TextStyle(color: textPrimary),
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search 400+ coins (BTC, SOL, PEPE, SUI, DOGE)...',
                hintStyle: TextStyle(color: textMuted, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: AppColors.primary, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                filled: true,
                fillColor: surfaceColor,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: borderColor)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: borderColor)),
                focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14)), borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
              ),
            ),
          ),

          // 2. Filter Pills
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterPill('ALL', 'All Tickers', surfaceColor, surfaceLight, borderColor, textPrimary, textSecondary),
                  _filterPill('GAINERS', '🔥 Top Gainers', surfaceColor, surfaceLight, borderColor, textPrimary, textSecondary),
                  _filterPill('LOSERS', '❄️ Top Losers', surfaceColor, surfaceLight, borderColor, textPrimary, textSecondary),
                  _filterPill('VOLUME', '💎 Top Volume', surfaceColor, surfaceLight, borderColor, textPrimary, textSecondary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),

          // 3. Tickers List
          Expanded(
            child: tickersAsync.when(
              loading: () => const MarketSkeleton(),
              error: (err, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Failed to load Binance feed: $err', style: const TextStyle(color: AppColors.loss)),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                      onPressed: () => ref.read(binanceTickersProvider.notifier).fetchTickers(),
                      child: const Text('Retry Connection', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
              data: (tickers) {
                if (tickers.isEmpty) {
                  return const Center(
                    child: MarketSkeleton(),
                  );
                }

                final filtered = _applyFilters(tickers);

                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 48, color: textMuted),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No coins matching "$_searchQuery"'
                                : 'No coins found for filter "$_selectedFilter"',
                            style: TextStyle(color: textSecondary, fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                          if (_searchQuery.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: () => setState(() => _searchQuery = ''),
                              icon: const Icon(Icons.clear, size: 16),
                              label: const Text('Clear Search'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () => ref.read(binanceTickersProvider.notifier).fetchTickers(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final coin = filtered[index];
                      final isPositive = coin.priceChangePercent >= 0;

                      return InkWell(
                        onTap: () => _showCoinActionSheet(context, coin),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            children: [
                              // Avatar / Icon
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: surfaceLight,
                                child: Text(
                                  coin.symbol.length > 3 ? coin.symbol.substring(0, 3) : coin.symbol,
                                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Name & Symbol
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(coin.symbol, style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
                                        const SizedBox(width: 6),
                                        Text('/ USDT', style: TextStyle(color: textMuted, fontSize: 11)),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      coin.name,
                                      style: TextStyle(color: textSecondary, fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),

                              // Price & 24h Change Pill
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    Formatters.currency(coin.price, currency),
                                    style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 3),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isPositive ? AppColors.profitBg : AppColors.lossBg,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      Formatters.percentage(coin.priceChangePercent),
                                      style: TextStyle(
                                        color: isPositive ? AppColors.profit : AppColors.loss,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: const Icon(Icons.candlestick_chart_rounded, color: Color(0xFF2962FF), size: 22),
                                tooltip: 'TradingView Chart',
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => CoinChartScreen(coin: coin)),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterPill(
    String key,
    String label,
    Color surfaceColor,
    Color surfaceLight,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    final isSelected = _selectedFilter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => setState(() => _selectedFilter = key),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : surfaceColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? AppColors.primary : borderColor),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : textSecondary,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  List<BinanceTickerModel> _applyFilters(List<BinanceTickerModel> list) {
    var result = list;

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      result = result.where((c) {
        return c.symbol.toLowerCase().contains(q) || c.name.toLowerCase().contains(q);
      }).toList();
    }

    switch (_selectedFilter) {
      case 'GAINERS':
        result = List.from(result)..sort((a, b) => b.priceChangePercent.compareTo(a.priceChangePercent));
        break;
      case 'LOSERS':
        result = List.from(result)..sort((a, b) => a.priceChangePercent.compareTo(b.priceChangePercent));
        break;
      case 'VOLUME':
        result = List.from(result)..sort((a, b) => b.quoteVolume.compareTo(a.quoteVolume));
        break;
      default:
        // Already sorted by volume
        break;
    }

    return result;
  }

  void _showCoinActionSheet(BuildContext context, BinanceTickerModel coin) {
    final surfaceColor = AppColors.surface(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final isProf = coin.priceChangePercent >= 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: surfaceColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.primaryGlow,
                      child: Text(
                        coin.symbol.length > 3 ? coin.symbol.substring(0, 3) : coin.symbol,
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${coin.symbol} / USDT', style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
                        Text(coin.name, style: TextStyle(color: textSecondary, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 16),

            // Live Price & 24h Stats
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Binance Live Price', style: TextStyle(color: textSecondary, fontSize: 11)),
                      const SizedBox(height: 2),
                      Text(Formatters.currency(coin.price), style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('24h Change', style: TextStyle(color: textSecondary, fontSize: 11)),
                      const SizedBox(height: 2),
                      Text(
                        Formatters.percentage(coin.priceChangePercent),
                        style: TextStyle(color: isProf ? AppColors.profit : AppColors.loss, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // High / Low Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('24h High: ${Formatters.currency(coin.highPrice)}', style: TextStyle(color: textSecondary, fontSize: 12)),
                Text('24h Low: ${Formatters.currency(coin.lowPrice)}', style: TextStyle(color: textSecondary, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 16),

            // TradingView Live Chart Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2962FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => CoinChartScreen(coin: coin)),
                  );
                },
                icon: const Icon(Icons.candlestick_chart_rounded, size: 20),
                label: const Text('TradingView Live Chart & Indicators', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
              ),
            ),
            const SizedBox(height: 12),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProfitCalculatorScreen(initialCoin: coin),
                        ),
                      );
                    },
                    icon: const Icon(Icons.calculate_outlined, size: 18),
                    label: const Text('Calculate Profit', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddTransactionScreen(
                            initialType: 'BUY',
                            preselectedCoin: coin,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add_shopping_cart, size: 18),
                    label: const Text('Trade / DCA', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
