import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/services/trading_news_service.dart';

final tradingNewsServiceProvider = Provider<TradingNewsService>((ref) {
  return TradingNewsService();
});

final tradingIntelligenceProvider =
    StateNotifierProvider<TradingIntelligenceNotifier, AsyncValue<TradingIntelligenceData>>((ref) {
  final service = ref.watch(tradingNewsServiceProvider);
  return TradingIntelligenceNotifier(service);
});

class TradingIntelligenceNotifier extends StateNotifier<AsyncValue<TradingIntelligenceData>> {
  final TradingNewsService _service;

  TradingIntelligenceNotifier(this._service) : super(const AsyncValue.loading()) {
    fetchIntelligence();
  }

  Future<void> fetchIntelligence({bool forceRefresh = false}) async {
    // If we already have data, don't flash a full loading spinner to prevent UI jumping
    if (!state.hasValue) {
      state = const AsyncValue.loading();
    }
    try {
      final data = await _service.getIntelligence(forceRefresh: forceRefresh);
      state = AsyncValue.data(data);
    } catch (e, stack) {
      if (!state.hasValue) {
        state = AsyncValue.error(e, stack);
      }
    }
  }
}
