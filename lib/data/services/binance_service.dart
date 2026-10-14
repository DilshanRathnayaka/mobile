import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/binance_ticker_model.dart';

class BinanceService {
  static const String _tickerUrl = 'https://api.binance.com/api/v3/ticker/24hr';
  List<BinanceTickerModel> _lastGoodCache = [];

  Future<List<BinanceTickerModel>> getUsdtTickers() async {
    try {
      final res = await http.get(
        Uri.parse(_tickerUrl),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final List raw = jsonDecode(res.body);
        final now = DateTime.now();

        final List<BinanceTickerModel> results = [];
        for (final item in raw) {
          final sym = item['symbol'] as String? ?? '';
          if (sym.endsWith('USDT')) {
            // Exclude leverage/speculative token variants
            if (sym.endsWith('UPUSDT') ||
                sym.endsWith('DOWNUSDT') ||
                sym.endsWith('BULLUSDT') ||
                sym.endsWith('BEARUSDT')) {
              continue;
            }

            final model = BinanceTickerModel.fromJson(item, observationTime: now);
            if (model.price > 0) {
              results.add(model);
            }
          }
        }

        // Sort descending by 24h trading volume (highest volume coins first)
        results.sort((a, b) => b.quoteVolume.compareTo(a.quoteVolume));

        if (results.isNotEmpty) {
          _lastGoodCache = results;
          return results;
        }
      }
    } catch (_) {
      // Network failed: return cached data marked as stale if available
    }

    if (_lastGoodCache.isNotEmpty) {
      return _lastGoodCache.map((t) => t.copyWith(isStale: true)).toList();
    }

    return _fallbackSeedTickers;
  }

  static List<BinanceTickerModel> get _fallbackSeedTickers => const [
        BinanceTickerModel(
          symbol: 'BTC',
          pair: 'BTCUSDT',
          name: 'Bitcoin',
          price: 68500.0,
          priceChangePercent: 2.15,
          highPrice: 69200.0,
          lowPrice: 67100.0,
          quoteVolume: 1250000000.0,
          volume: 18200.0,
          isStale: true,
        ),
        BinanceTickerModel(
          symbol: 'ETH',
          pair: 'ETHUSDT',
          name: 'Ethereum',
          price: 2650.0,
          priceChangePercent: 1.84,
          highPrice: 2710.0,
          lowPrice: 2590.0,
          quoteVolume: 850000000.0,
          volume: 320000.0,
          isStale: true,
        ),
        BinanceTickerModel(
          symbol: 'SOL',
          pair: 'SOLUSDT',
          name: 'Solana',
          price: 156.0,
          priceChangePercent: 4.12,
          highPrice: 161.0,
          lowPrice: 149.0,
          quoteVolume: 620000000.0,
          volume: 4000000.0,
          isStale: true,
        ),
        BinanceTickerModel(
          symbol: 'BNB',
          pair: 'BNBUSDT',
          name: 'BNB',
          price: 585.0,
          priceChangePercent: 0.95,
          highPrice: 595.0,
          lowPrice: 578.0,
          quoteVolume: 310000000.0,
          volume: 530000.0,
          isStale: true,
        ),
        BinanceTickerModel(
          symbol: 'XRP',
          pair: 'XRPUSDT',
          name: 'XRP',
          price: 0.542,
          priceChangePercent: 1.05,
          highPrice: 0.558,
          lowPrice: 0.531,
          quoteVolume: 240000000.0,
          volume: 440000000.0,
          isStale: true,
        ),
        BinanceTickerModel(
          symbol: 'DOGE',
          pair: 'DOGEUSDT',
          name: 'Dogecoin',
          price: 0.125,
          priceChangePercent: 3.80,
          highPrice: 0.132,
          lowPrice: 0.119,
          quoteVolume: 190000000.0,
          volume: 1500000000.0,
          isStale: true,
        ),
        BinanceTickerModel(
          symbol: 'ADA',
          pair: 'ADAUSDT',
          name: 'Cardano',
          price: 0.355,
          priceChangePercent: -0.42,
          highPrice: 0.368,
          lowPrice: 0.348,
          quoteVolume: 110000000.0,
          volume: 310000000.0,
          isStale: true,
        ),
        BinanceTickerModel(
          symbol: 'AVAX',
          pair: 'AVAXUSDT',
          name: 'Avalanche',
          price: 28.5,
          priceChangePercent: 2.30,
          highPrice: 29.8,
          lowPrice: 27.4,
          quoteVolume: 140000000.0,
          volume: 4900000.0,
          isStale: true,
        ),
        BinanceTickerModel(
          symbol: 'SUI',
          pair: 'SUIUSDT',
          name: 'Sui',
          price: 2.15,
          priceChangePercent: 6.80,
          highPrice: 2.28,
          lowPrice: 1.98,
          quoteVolume: 280000000.0,
          volume: 130000000.0,
          isStale: true,
        ),
        BinanceTickerModel(
          symbol: 'PEPE',
          pair: 'PEPEUSDT',
          name: 'Pepe',
          price: 0.0000104,
          priceChangePercent: 5.40,
          highPrice: 0.0000112,
          lowPrice: 0.0000098,
          quoteVolume: 180000000.0,
          volume: 17000000000.0,
          isStale: true,
        ),
        BinanceTickerModel(
          symbol: 'NEAR',
          pair: 'NEARUSDT',
          name: 'NEAR Protocol',
          price: 5.12,
          priceChangePercent: 3.10,
          highPrice: 5.35,
          lowPrice: 4.90,
          quoteVolume: 95000000.0,
          volume: 18500000.0,
          isStale: true,
        ),
        BinanceTickerModel(
          symbol: 'LINK',
          pair: 'LINKUSDT',
          name: 'Chainlink',
          price: 11.80,
          priceChangePercent: 1.50,
          highPrice: 12.20,
          lowPrice: 11.45,
          quoteVolume: 85000000.0,
          volume: 7200000.0,
          isStale: true,
        ),
      ];
}

