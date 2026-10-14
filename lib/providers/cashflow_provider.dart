import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/cashflow_model.dart';
import '../data/services/supabase_service.dart';
import 'portfolio_provider.dart';

final cashflowProvider =
    StateNotifierProvider<CashflowNotifier, CashflowSummary>((ref) {
  final supabase = ref.watch(supabaseServiceProvider);
  return CashflowNotifier(supabase, ref);
});

class CashflowNotifier extends StateNotifier<CashflowSummary> {
  final SupabaseService _supabaseService;
  final Ref _ref;

  CashflowNotifier(this._supabaseService, this._ref) : super(CashflowSummary.empty()) {
    _loadCashflow();
  }

  Future<void> _loadCashflow() async {
    // Cloud database is the sole source of truth for user financial data
    try {
      final cloudItems = await _supabaseService.getCashflowRecords();
      _recalculate(cloudItems);
    } catch (_) {
      _recalculate([]);
    }
  }

  void _recalculate(List<CashflowItem> list) {
    double deposits = 0;
    double withdrawals = 0;

    double p2pDepUsdt = 0;
    double p2pDepLocal = 0;
    double p2pWdUsdt = 0;
    double p2pWdLocal = 0;
    int p2pCount = 0;

    for (final item in list) {
      if (item.type == 'DEPOSIT') {
        deposits += item.amount;
        if (item.isP2P) {
          p2pDepUsdt += item.amount;
          p2pDepLocal += item.effectiveLocalAmount;
          p2pCount++;
        }
      } else {
        withdrawals += item.amount;
        if (item.isP2P) {
          p2pWdUsdt += item.amount;
          p2pWdLocal += item.effectiveLocalAmount;
          p2pCount++;
        }
      }
    }

    final avgBuy = p2pDepUsdt > 0 ? (p2pDepLocal / p2pDepUsdt) : 0.0;
    final avgSell = p2pWdUsdt > 0 ? (p2pWdLocal / p2pWdUsdt) : 0.0;
    
    // Merchant spread profit: if sold at higher rate than bought on matched volume
    double merchantProfit = 0.0;
    if (avgBuy > 0 && avgSell > 0) {
      final matchedVolume = p2pDepUsdt < p2pWdUsdt ? p2pDepUsdt : p2pWdUsdt;
      merchantProfit = matchedVolume * (avgSell - avgBuy);
    }

    state = CashflowSummary(
      totalDeposited: deposits,
      totalWithdrawn: withdrawals,
      netCapital: deposits - withdrawals,
      items: list,
      totalP2pDepositedUsdt: p2pDepUsdt,
      totalP2pDepositedLocal: p2pDepLocal,
      avgP2pBuyRate: avgBuy,
      totalP2pWithdrawnUsdt: p2pWdUsdt,
      totalP2pWithdrawnLocal: p2pWdLocal,
      avgP2pSellRate: avgSell,
      p2pNetProfitLocal: merchantProfit,
      p2pTradeCount: p2pCount,
    );
  }

  Future<void> addRecord({
    required String type, // 'DEPOSIT' or 'WITHDRAWAL'
    required double amount,
    required String category,
    required DateTime date,
    String notes = '',
    bool isP2P = false,
    double? p2pRate,
    String? localCurrency,
    double? localAmount,
  }) async {
    // 1. Persist directly to cloud database (strictly scoped by active user)
    CashflowItem? cloudItem;
    try {
      cloudItem = await _supabaseService.addCashflowRecord(
        type: type,
        amount: amount,
        category: category,
        date: date,
        notes: notes,
        isP2P: isP2P,
        p2pRate: p2pRate,
        localCurrency: localCurrency,
        localAmount: localAmount,
      );
    } catch (_) {}

    final newItem = cloudItem ??
        CashflowItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: type,
          amount: amount,
          category: category,
          date: date,
          notes: notes,
          isP2P: isP2P,
          p2pRate: p2pRate,
          localCurrency: localCurrency,
          localAmount: localAmount,
        );

    final updated = [newItem, ...state.items];
    _recalculate(updated);

    // Synchronize transactions and dashboard providers
    try {
      _ref.read(transactionsProvider.notifier).refresh();
      _ref.read(portfolioSummaryProvider.notifier).refresh();
    } catch (_) {}
  }

  Future<void> updateRecord({
    required String id,
    required String type,
    required double amount,
    required String category,
    required DateTime date,
    String notes = '',
    bool isP2P = false,
    double? p2pRate,
    String? localCurrency,
    double? localAmount,
  }) async {
    // 1. Sync update to cloud database
    try {
      await _supabaseService.updateCashflowRecord(
        id: id,
        type: type,
        amount: amount,
        category: category,
        date: date,
        notes: notes,
        isP2P: isP2P,
        p2pRate: p2pRate,
        localCurrency: localCurrency,
        localAmount: localAmount,
      );
    } catch (_) {}

    final updated = state.items.map((item) {
      if (item.id == id) {
        return item.copyWith(
          type: type,
          amount: amount,
          category: category,
          date: date,
          notes: notes,
          isP2P: isP2P,
          p2pRate: p2pRate,
          localCurrency: localCurrency,
          localAmount: localAmount,
        );
      }
      return item;
    }).toList();

    _recalculate(updated);

    try {
      _ref.read(transactionsProvider.notifier).refresh();
      _ref.read(portfolioSummaryProvider.notifier).refresh();
    } catch (_) {}
  }

  Future<void> deleteRecord(String id) async {
    // 1. Sync deletion to cloud database
    try {
      await _supabaseService.deleteCashflowRecord(id);
    } catch (_) {}

    final updated = state.items.where((i) => i.id != id).toList();
    _recalculate(updated);

    try {
      _ref.read(transactionsProvider.notifier).refresh();
      _ref.read(portfolioSummaryProvider.notifier).refresh();
    } catch (_) {}
  }

  Future<void> refresh() async {
    await _loadCashflow();
  }
}
