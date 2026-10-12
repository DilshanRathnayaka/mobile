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

    return [];
  }
}

