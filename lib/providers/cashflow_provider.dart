import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/cashflow_model.dart';
import '../data/services/supabase_service.dart';
import 'portfolio_provider.dart';

final cashflowProvider =
    StateNotifierProvider<CashflowNotifier, CashflowSummary>((ref) {
  final supabase = ref.watch(supabaseServiceProvider);
  return CashflowNotifier(supabase, ref);
});

class CashflowNotifier extends StateNotifier<CashflowSummary> {
  static const _prefKey = 'user_cashflow_records';
  final SupabaseService _supabaseService;
  final Ref _ref;

  CashflowNotifier(this._supabaseService, this._ref) : super(CashflowSummary.empty()) {
    _loadCashflow();
  }

  Future<void> _loadCashflow() async {
    // 1. Prioritize Supabase cloud database as source of truth
    try {
      final cloudItems = await _supabaseService.getCashflowRecords();
      if (cloudItems.isNotEmpty) {
        _recalculate(cloudItems, syncToCloud: false);
        return;
      }
    } catch (_) {}

    // 2. Offline fallback to local SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_prefKey);

      List<CashflowItem> list = [];
      if (raw != null && raw.isNotEmpty) {
        list = raw.map((str) => CashflowItem.fromJson(jsonDecode(str))).toList();
        list.sort((a, b) => b.date.compareTo(a.date));
        _recalculate(list, syncToCloud: false);
      }
    } catch (_) {}
  }

  void _recalculate(List<CashflowItem> list, {bool syncToCloud = false}) {
    double deposits = 0;
    double withdrawals = 0;

    for (final item in list) {
      if (item.type == 'DEPOSIT') {
        deposits += item.amount;
      } else {
        withdrawals += item.amount;
      }
    }

    state = CashflowSummary(
      totalDeposited: deposits,
      totalWithdrawn: withdrawals,
      netCapital: deposits - withdrawals,
      items: list,
    );

    _saveLocal(list);
  }

  Future<void> _saveLocal(List<CashflowItem> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = list.map((item) => jsonEncode(item.toJson())).toList();
      await prefs.setStringList(_prefKey, raw);
    } catch (_) {}
  }

  Future<void> addRecord({
    required String type, // 'DEPOSIT' or 'WITHDRAWAL'
    required double amount,
    required String category,
    required DateTime date,
    String notes = '',
  }) async {
    // 1. Persist directly to Supabase cloud database
    CashflowItem? cloudItem;
    try {
      cloudItem = await _supabaseService.addCashflowRecord(
        type: type,
        amount: amount,
        category: category,
        date: date,
        notes: notes,
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
  }) async {
    // 1. Sync update to Supabase
    try {
      await _supabaseService.updateCashflowRecord(
        id: id,
        type: type,
        amount: amount,
        category: category,
        date: date,
        notes: notes,
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
    // 1. Sync deletion to Supabase
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
