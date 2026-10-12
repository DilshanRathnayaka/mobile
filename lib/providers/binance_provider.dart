import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/binance_ticker_model.dart';
import '../data/services/binance_service.dart';

final binanceServiceProvider = Provider<BinanceService>((ref) {
  return BinanceService();
});

final binanceTickersProvider = StateNotifierProvider<BinanceTickersNotifier, AsyncValue<List<BinanceTickerModel>>>((ref) {
  final service = ref.watch(binanceServiceProvider);
  return BinanceTickersNotifier(service);
});

class BinanceTickersNotifier extends StateNotifier<AsyncValue<List<BinanceTickerModel>>> {
  final BinanceService _service;

  BinanceTickersNotifier(this._service) : super(const AsyncValue.loading()) {
    fetchTickers();
  }

  Future<void> fetchTickers() async {
    try {
      final list = await _service.getUsdtTickers();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
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
}
