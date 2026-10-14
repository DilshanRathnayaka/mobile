import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/formatters.dart';
import '../data/models/binance_ticker_model.dart';
import '../providers/binance_provider.dart';
import '../providers/currency_provider.dart';
import 'add_transaction_screen.dart';
import 'profit_calculator_screen.dart';

class CoinChartScreen extends ConsumerStatefulWidget {
  final BinanceTickerModel coin;

  const CoinChartScreen({
    super.key,
    required this.coin,
  });

  @override
  ConsumerState<CoinChartScreen> createState() => _CoinChartScreenState();
}

class _CoinChartScreenState extends ConsumerState<CoinChartScreen> {
  late final WebViewController _webViewController;
  bool _isLoading = true;
  bool _hasError = false;
  String _selectedInterval = '60'; // 15, 60, 240, D, W
  bool _isLandscape = false;

  final Map<String, String> _intervalLabels = {
    '15': '15m',
    '60': '1H',
    '240': '4H',
    'D': '1D',
    'W': '1W',
  };

  @override
  void initState() {
    super.initState();
    _initWebViewController();
  }

  @override
  void dispose() {
    if (_isLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
    super.dispose();
  }

  void _toggleOrientation() {
    setState(() {
      _isLandscape = !_isLandscape;
    });

    if (_isLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
  }

  void _initWebViewController() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0F172A))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _hasError = false;
              });
            }
          },
          onWebResourceError: (error) {
            // Only flag main frame errors to prevent third-party asset noise
            if (error.isForMainFrame ?? false) {
              if (mounted) {
                setState(() {
                  _hasError = true;
                  _isLoading = false;
                });
              }
            }
          },
        ),
      );

    _loadTradingViewHtml();
  }

  String _cleanSymbol(String rawSymbol) {
    var sym = rawSymbol.trim().toUpperCase();
    if (sym.endsWith('USDT')) {
      return sym;
    }
    return '${sym}USDT';
  }

  void _loadTradingViewHtml() {
    final pair = _cleanSymbol(widget.coin.symbol);
    final html = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body {
      width: 100%;
      height: 100%;
      background-color: #0F172A;
      overflow: hidden;
    }
    #tv_chart_container {
      width: 100vw;
      height: 100vh;
    }
  </style>
  <script type="text/javascript" src="https://s3.tradingview.com/tv.js"></script>
</head>
<body>
  <div id="tv_chart_container"></div>
  <script type="text/javascript">
    function initChart() {
      if (typeof TradingView === 'undefined') {
        setTimeout(initChart, 200);
        return;
      }
      new TradingView.widget({
        "autosize": true,
        "symbol": "BINANCE:$pair",
        "interval": "$_selectedInterval",
        "timezone": "Etc/UTC",
        "theme": "dark",
        "style": "1",
        "locale": "en",
        "toolbar_bg": "#0F172A",
        "enable_publishing": false,
        "hide_top_toolbar": false,
        "hide_legend": false,
        "save_image": false,
        "container_id": "tv_chart_container",
        "studies": [
          "RSI@tv-basicstudies",
          "MASimple@tv-basicstudies"
        ],
        "loading_screen": {
          "backgroundColor": "#0F172A",
          "foregroundColor": "#6366F1"
        }
      });
    }
    initChart();
  </script>
</body>
</html>
''';

    _webViewController.loadHtmlString(html, baseUrl: 'https://s3.tradingview.com');
  }

  void _changeInterval(String newInterval) {
    if (_selectedInterval == newInterval) return;
    setState(() {
      _selectedInterval = newInterval;
      _isLoading = true;
    });
    _loadTradingViewHtml();
  }

  @override
  Widget build(BuildContext context) {
    final tickers = ref.watch(binanceTickersProvider).valueOrNull;
    final liveCoin = tickers?.firstWhere(
          (t) => t.symbol.toUpperCase() == widget.coin.symbol.toUpperCase(),
          orElse: () => widget.coin,
        ) ??
        widget.coin;

    final currency = ref.watch(currencyProvider);
    final isPositive = liveCoin.priceChangePercent >= 0;

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
        backgroundColor: surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.primaryGlow,
              child: Text(
                liveCoin.symbol.length > 3
                    ? liveCoin.symbol.substring(0, 3)
                    : liveCoin.symbol,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${liveCoin.symbol} / USDT',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2962FF).withAlpha(25),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: const Color(0xFF2962FF).withAlpha(80)),
                        ),
                        child: const Text(
                          'TradingView',
                          style: TextStyle(
                            color: Color(0xFF2962FF),
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    liveCoin.name,
                    style: TextStyle(color: textSecondary, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _isLandscape ? 'Portrait Mode' : 'Landscape Fullscreen',
            icon: Icon(
              _isLandscape
                  ? Icons.screen_lock_portrait
                  : Icons.screen_lock_landscape,
              color: AppColors.primary,
              size: 20,
            ),
            onPressed: _toggleOrientation,
          ),
          IconButton(
            tooltip: 'Reload Chart',
            icon: Icon(Icons.refresh, color: textSecondary, size: 20),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadTradingViewHtml();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Live Price & 24h Stats Ribbon (Portrait only to save vertical space in landscape)
            if (!_isLandscape)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  border: Border(bottom: BorderSide(color: borderColor)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Price Block
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              Formatters.currency(liveCoin.price),
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isPositive
                                      ? AppColors.profitBg
                                      : AppColors.loss.withAlpha(25),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  Formatters.percentage(
                                      liveCoin.priceChangePercent),
                                  style: TextStyle(
                                    color: isPositive
                                        ? AppColors.profit
                                        : AppColors.loss,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (currency.code != 'USD' &&
                                  currency.code != 'USDT') ...[
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    Formatters.currency(liveCoin.price, currency),
                                    style: TextStyle(
                                        color: textMuted, fontSize: 11),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 12),

                    // 24h High, Low, Volume Stats
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _statRow('24h High',
                              Formatters.currency(liveCoin.highPrice), textMuted, textPrimary),
                          const SizedBox(height: 3),
                          _statRow('24h Low',
                              Formatters.currency(liveCoin.lowPrice), textMuted, textPrimary),
                          const SizedBox(height: 3),
                          _statRow(
                              '24h Vol',
                              '${Formatters.compactNumber(liveCoin.volume)} ${liveCoin.symbol}',
                              textMuted,
                              textSecondary),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // 2. Timeframe Selector Pills
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              color: surfaceColor,
              child: Row(
                children: [
                  Text(
                    'Timeframe: ',
                    style: TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _intervalLabels.entries.map((entry) {
                          final isSelected = _selectedInterval == entry.key;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: InkWell(
                              onTap: () => _changeInterval(entry.key),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary
                                      : surfaceLight,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary
                                        : borderColor,
                                  ),
                                ),
                                child: Text(
                                  entry.value,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : textSecondary,
                                    fontSize: 11,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 3. Interactive TradingView Chart WebView with Loading & Error Fallbacks
            Expanded(
              child: Stack(
                children: [
                  if (!_hasError)
                    WebViewWidget(controller: _webViewController),

                  // Loading Overlay
                  if (_isLoading && !_hasError)
                    Container(
                      color: const Color(0xFF0F172A),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.primary,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Loading TradingView Chart...',
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Streaming live Binance candlestick data for ${liveCoin.symbol}',
                              style: TextStyle(color: textMuted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Error Overlay (if offline or blocked)
                  if (_hasError)
                    Container(
                      color: bgColor,
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.wifi_off_rounded,
                              size: 44,
                              color: AppColors.loss,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Failed to connect to TradingView',
                              style: TextStyle(
                                color: textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Check your internet connection and retry.',
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () {
                                setState(() {
                                  _isLoading = true;
                                  _hasError = false;
                                });
                                _loadTradingViewHtml();
                              },
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('Retry Connection'),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // 4. Quick Action Trade / DCA Bar (Portrait only)
            if (!_isLandscape)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  border: Border(top: BorderSide(color: borderColor)),
                ),
                child: Row(
                  children: [
                    // Calculator Shortcut
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(color: AppColors.primary.withAlpha(120)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProfitCalculatorScreen(initialCoin: liveCoin),
                          ),
                        );
                      },
                      icon: const Icon(Icons.calculate_outlined, size: 17),
                      label: const Text('Calculator', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),

                    // Buy / DCA Button
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.profit,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddTransactionScreen(
                                initialType: 'BUY',
                                preselectedCoin: liveCoin,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add_shopping_cart, size: 16),
                        label: Text(
                          'Buy / DCA ${liveCoin.symbol}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Sell / Short Button
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.loss,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddTransactionScreen(
                                initialType: 'SELL',
                                preselectedCoin: liveCoin,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.sell_outlined, size: 16),
                        label: Text(
                          'Sell ${liveCoin.symbol}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _statRow(String label, String value, Color lblColor, Color valColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: TextStyle(color: lblColor, fontSize: 10.5),
        ),
        Text(
          value,
          style: TextStyle(color: valColor, fontSize: 10.5, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
