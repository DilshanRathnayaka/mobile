import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/binance_ticker_model.dart';
import '../data/models/live_price_tick.dart';
import '../data/services/binance_service.dart';
import '../data/services/live_price_service.dart';
import 'portfolio_provider.dart';

final binanceServiceProvider = Provider<BinanceService>((ref) {
  return BinanceService();
});

final binanceTickersProvider =
    StateNotifierProvider<BinanceTickersNotifier, AsyncValue<List<BinanceTickerModel>>>((ref) {
  final service = ref.watch(binanceServiceProvider);
  final liveService = ref.watch(livePriceServiceProvider);
  return BinanceTickersNotifier(service, liveService);
});

class BinanceTickersNotifier extends StateNotifier<AsyncValue<List<BinanceTickerModel>>> {
  final BinanceService _service;
  final LivePriceService _livePriceService;
  StreamSubscription? _priceSubscription;

  BinanceTickersNotifier(this._service, this._livePriceService)
      : super(const AsyncValue.loading()) {
    fetchTickers();
    _subscribeToLivePrices();
  }

  void _subscribeToLivePrices() {
    _priceSubscription?.cancel();
    _priceSubscription = _livePriceService.priceStream.listen((prices) {
      _applyLivePrices(prices);
    });
  }

  void _applyLivePrices(Map<String, LivePriceTick> prices) {
    final currentList = state.valueOrNull;
    if (currentList == null || currentList.isEmpty) return;

    bool hasChanged = false;
    final updatedList = currentList.map((ticker) {
      final tick = prices[ticker.pair] ?? prices[ticker.symbol.toUpperCase()];
      if (tick != null && tick.price > 0 && (tick.price - ticker.price).abs() > 0.00000001) {
        hasChanged = true;
        return ticker.copyWith(
          price: tick.price,
          priceChangePercent: tick.change24h,
          isStale: false,
        );
      }
      return ticker;
    }).toList();

    if (hasChanged) {
      state = AsyncValue.data(updatedList);
    }
  }

  Future<void> fetchTickers() async {
    try {
      final list = await _service.getUsdtTickers();
      state = AsyncValue.data(list);
    } catch (e, st) {
      if (!state.hasValue) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  BinanceTickerModel? getTickerBySymbol(String symbol) {
    return state.valueOrNull?.firstWhere(
      (t) => t.symbol.toUpperCase() == symbol.toUpperCase(),
      orElse: () => BinanceTickerModel(
        symbol: symbol,
        pair: '${symbol}USDT',
        name: symbol,
        price: 0,
        priceChangePercent: 0,
        highPrice: 0,
        lowPrice: 0,
        quoteVolume: 0,
        volume: 0,
      ),
    );
  }

  @override
  void dispose() {
    _priceSubscription?.cancel();
    super.dispose();
  }
}
