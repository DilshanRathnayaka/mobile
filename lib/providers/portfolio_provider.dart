import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/holding_model.dart';
import '../data/models/live_price_tick.dart';
import '../data/models/portfolio_summary_model.dart';
import '../data/models/transaction_model.dart';
import '../data/models/salary_report_model.dart';
import '../data/services/live_price_service.dart';
import '../data/services/supabase_service.dart';

final supabaseServiceProvider = Provider<SupabaseService>((ref) => SupabaseService());

/// Singleton real-time live price streaming provider
final livePriceServiceProvider = Provider<LivePriceService>((ref) {
  final service = LivePriceService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Real-time live streaming connection status provider (true = WebSocket active)
final livePriceStatusProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(livePriceServiceProvider);
  return service.statusStream;
});

// Balance visibility toggle (e.g. $5,850 vs ****)
final isBalanceHiddenProvider = StateProvider<bool>((ref) => false);

// Portfolio Summary Provider with continuous Real-Time Profit & Loss Updates
final portfolioSummaryProvider =
    StateNotifierProvider<PortfolioNotifier, AsyncValue<PortfolioSummaryModel>>((ref) {
  final supabase = ref.watch(supabaseServiceProvider);
  final livePrices = ref.watch(livePriceServiceProvider);
  return PortfolioNotifier(supabase, livePrices);
});

class PortfolioNotifier extends StateNotifier<AsyncValue<PortfolioSummaryModel>> {
  final SupabaseService _service;
  final LivePriceService _livePriceService;
  StreamSubscription? _priceSubscription;
  RealtimeChannel? _realtimeChannel;

  PortfolioNotifier(this._service, this._livePriceService) : super(const AsyncValue.loading()) {
    refresh();
    _subscribeToLivePrices();
    _subscribeToSupabaseRealtime();
  }

  void _subscribeToLivePrices() {
    _priceSubscription?.cancel();
    _priceSubscription = _livePriceService.priceStream.listen((prices) {
      _applyLivePriceTicks(prices);
    });
  }

  void _subscribeToSupabaseRealtime() {
    try {
      _realtimeChannel = _service.subscribeToPortfolioChanges(
        onChange: () {
          // Silent refresh from database on remote changes
          refresh(silent: true);
        },
      );
    } catch (_) {}
  }

  Future<void> refresh({bool silent = false}) async {
    if (!silent && !state.hasValue) {
      state = const AsyncValue.loading();
    }
    try {
      final summary = await _service.getPortfolioSummary();
      final updated = _recalculateWithLatestPrices(summary);
      state = AsyncValue.data(updated);
    } catch (e, stack) {
      if (!state.hasValue) {
        state = AsyncValue.error(e, stack);
      }
    }
  }

  /// Recalculates unrealized profit/loss, portfolio value, and allocations on every live price tick
  void _applyLivePriceTicks(Map<String, LivePriceTick> prices) {
    final current = state.valueOrNull;
    if (current == null || current.holdings.isEmpty) return;

    bool hasAnyChange = false;
    double newCurrentValue = 0.0;
    final updatedHoldings = <HoldingModel>[];

    for (final h in current.holdings) {
      final tick = prices[h.symbol.toUpperCase()] ??
          prices[h.coinId] ??
          prices['${h.symbol.toUpperCase()}USDT'];

      if (tick != null && tick.price > 0 && (tick.price - h.currentPrice).abs() > 0.00000001) {
        hasAnyChange = true;
        final coinVal = h.totalQuantity * tick.price;
        final unPnl = coinVal - h.totalInvestedCost;
        final unPnlPct = h.totalInvestedCost > 0 ? (unPnl / h.totalInvestedCost) * 100 : 0.0;

        updatedHoldings.add(h.copyWith(
          currentPrice: tick.price,
          change24h: tick.change24h,
          currentValue: coinVal,
          unrealizedPnl: unPnl,
          unrealizedPnlPercentage: unPnlPct,
        ));
        newCurrentValue += coinVal;
      } else {
        updatedHoldings.add(h);
        newCurrentValue += h.currentValue;
      }
    }

    if (!hasAnyChange) return;

    final totalUnrealized = newCurrentValue - current.totalInvested;
    final totalUnrealizedPct =
        current.totalInvested > 0 ? (totalUnrealized / current.totalInvested) * 100 : 0.0;

    final updatedAllocations = updatedHoldings.map((h) => AssetAllocation(
      coinId: h.coinId,
      symbol: h.symbol,
      percentage: newCurrentValue > 0 ? (h.currentValue / newCurrentValue) * 100 : 0.0,
      value: h.currentValue,
    )).toList();

    final netVal = newCurrentValue + current.unallocatedUsdt;

    state = AsyncValue.data(current.copyWith(
      currentValue: newCurrentValue,
      unrealizedPnl: totalUnrealized,
      unrealizedPnlPercentage: totalUnrealizedPct,
      holdings: updatedHoldings,
      allocations: updatedAllocations,
      netPortfolioValue: netVal,
    ));
  }

  PortfolioSummaryModel _recalculateWithLatestPrices(PortfolioSummaryModel summary) {
    if (summary.holdings.isEmpty) return summary;
    final prices = _livePriceService.latestPrices;
    if (prices.isEmpty) return summary;

    double newCurrentValue = 0.0;
    final updatedHoldings = <HoldingModel>[];

    for (final h in summary.holdings) {
      final tick = prices[h.symbol.toUpperCase()] ??
          prices[h.coinId] ??
          prices['${h.symbol.toUpperCase()}USDT'];

      if (tick != null && tick.price > 0) {
        final coinVal = h.totalQuantity * tick.price;
        final unPnl = coinVal - h.totalInvestedCost;
        final unPnlPct = h.totalInvestedCost > 0 ? (unPnl / h.totalInvestedCost) * 100 : 0.0;

        updatedHoldings.add(h.copyWith(
          currentPrice: tick.price,
          change24h: tick.change24h,
          currentValue: coinVal,
          unrealizedPnl: unPnl,
          unrealizedPnlPercentage: unPnlPct,
        ));
        newCurrentValue += coinVal;
      } else {
        updatedHoldings.add(h);
        newCurrentValue += h.currentValue;
      }
    }

    final totalUnrealized = newCurrentValue - summary.totalInvested;
    final totalUnrealizedPct =
        summary.totalInvested > 0 ? (totalUnrealized / summary.totalInvested) * 100 : 0.0;

    final updatedAllocations = updatedHoldings.map((h) => AssetAllocation(
      coinId: h.coinId,
      symbol: h.symbol,
      percentage: newCurrentValue > 0 ? (h.currentValue / newCurrentValue) * 100 : 0.0,
      value: h.currentValue,
    )).toList();

    return summary.copyWith(
      currentValue: newCurrentValue,
      unrealizedPnl: totalUnrealized,
      unrealizedPnlPercentage: totalUnrealizedPct,
      holdings: updatedHoldings,
      allocations: updatedAllocations,
      netPortfolioValue: newCurrentValue + summary.unallocatedUsdt,
    );
  }

  @override
  void dispose() {
    _priceSubscription?.cancel();
    try {
      _realtimeChannel?.unsubscribe();
    } catch (_) {}
    super.dispose();
  }
}

// Transactions Provider
final transactionsProvider =
    StateNotifierProvider<TransactionsNotifier, AsyncValue<List<TransactionModel>>>((ref) {
  return TransactionsNotifier(ref.watch(supabaseServiceProvider), ref);
});

class TransactionsNotifier extends StateNotifier<AsyncValue<List<TransactionModel>>> {
  final SupabaseService _service;
  final Ref _ref;

  TransactionsNotifier(this._service, this._ref) : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh({bool silent = false}) async {
    if (!silent && !state.hasValue) {
      state = const AsyncValue.loading();
    }
    try {
      final list = await _service.getTransactions();
      state = AsyncValue.data(list);
    } catch (e, stack) {
      if (!state.hasValue) {
        state = AsyncValue.error(e, stack);
      }
    }
  }

  Future<bool> addTransaction(Map<String, dynamic> data) async {
    final success = await _service.createTransaction(data);
    if (success) {
      await refresh(silent: true);
      _ref.read(portfolioSummaryProvider.notifier).refresh(silent: true);
    }
    return success;
  }

  Future<bool> updateTransaction(String id, Map<String, dynamic> data) async {
    final success = await _service.updateTransaction(id, data);
    if (success) {
      await refresh(silent: true);
      _ref.read(portfolioSummaryProvider.notifier).refresh(silent: true);
    }
    return success;
  }

  Future<bool> deleteTransaction(String id) async {
    final success = await _service.deleteTransaction(id);
    if (success) {
      await refresh(silent: true);
      _ref.read(portfolioSummaryProvider.notifier).refresh(silent: true);
    }
    return success;
  }
}

// Salary Report Provider
final salaryReportProvider =
    StateNotifierProvider<SalaryReportNotifier, AsyncValue<SalaryReportModel>>((ref) {
  return SalaryReportNotifier(ref.watch(supabaseServiceProvider), ref);
});

class SalaryReportNotifier extends StateNotifier<AsyncValue<SalaryReportModel>> {
  final SupabaseService _service;
  final Ref _ref;

  SalaryReportNotifier(this._service, this._ref) : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh({bool silent = false}) async {
    if (!silent && !state.hasValue) {
      state = const AsyncValue.loading();
    }
    try {
      final report = await _service.getSalaryReport();
      state = AsyncValue.data(report);
    } catch (e, stack) {
      if (!state.hasValue) {
        state = AsyncValue.error(e, stack);
      }
    }
  }

  Future<bool> saveAllocation(Map<String, dynamic> data) async {
    final success = await _service.saveSalaryAllocation(data);
    if (success) {
      await refresh(silent: true);
      _ref.read(transactionsProvider.notifier).refresh(silent: true);
      _ref.read(portfolioSummaryProvider.notifier).refresh(silent: true);
    }
    return success;
  }

  Future<bool> deleteAllocation(String yearMonth) async {
    final success = await _service.deleteSalaryAllocation(yearMonth);
    if (success) {
      await refresh(silent: true);
      _ref.read(transactionsProvider.notifier).refresh(silent: true);
      _ref.read(portfolioSummaryProvider.notifier).refresh(silent: true);
    }
    return success;
  }
}
