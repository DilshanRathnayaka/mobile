import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/utils/asset_mapper.dart';
import '../models/bank_budget_model.dart';
import '../models/cashflow_model.dart';
import '../models/employment_model.dart';
import '../models/holding_model.dart';
import '../models/mfa_status_model.dart';
import '../models/portfolio_summary_model.dart';
import '../models/salary_report_model.dart';
import '../models/transaction_model.dart';
import 'binance_service.dart';

class SupabaseService {
  final BinanceService _binanceService = BinanceService();
  final _uuid = const Uuid();

  SupabaseClient? get _client {
    try {
      if (Supabase.instance.client.auth.currentSession != null ||
          Supabase.instance.client.auth.currentUser != null) {
        return Supabase.instance.client;
      }
      return Supabase.instance.client;
    } catch (e) {
      debugPrint('[Supabase] Client access error: $e');
    }
    return null;
  }

  User? get currentUser => _client?.auth.currentUser;
  bool get isAuthenticated => currentUser != null;

  // ==========================================
  // 🔐 AUTHENTICATION & PASSWORD RECOVERY
  // ==========================================
  Future<AuthResponse?> signUp(String email, String password) async {
    if (_client == null) throw Exception('Supabase is not initialized');
    return await _client!.auth.signUp(email: email, password: password);
  }

  Future<AuthResponse?> signIn(String email, String password) async {
    if (_client == null) throw Exception('Supabase is not initialized');
    return await _client!.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    if (_client != null) {
      await _client!.auth.signOut();
    }
  }

  Future<void> resetPasswordForEmail(String email) async {
    if (_client == null) throw Exception('Supabase is not initialized');
    await _client!.auth.resetPasswordForEmail(email);
  }

  // ==========================================
  // 🛡️ SUPABASE MFA (GOOGLE AUTHENTICATOR / TOTP)
  // ==========================================
  Future<AuthMFAEnrollResponse> enrollMfaTotp({String? friendlyName}) async {
    if (_client == null || !isAuthenticated) throw Exception('User not authenticated');
    return await _client!.auth.mfa.enroll(
      factorType: FactorType.totp,
      issuer: 'AssetManager',
      friendlyName: friendlyName ?? 'Google Authenticator',
    );
  }

  Future<AuthMFAVerifyResponse> challengeAndVerifyMfaTotp({
    required String factorId,
    required String code,
  }) async {
    if (_client == null || !isAuthenticated) throw Exception('User not authenticated');
    return await _client!.auth.mfa.challengeAndVerify(
      factorId: factorId,
      code: code.trim(),
    );
  }

  Future<void> unenrollMfaTotp(String factorId) async {
    if (_client == null || !isAuthenticated) throw Exception('User not authenticated');
    await _client!.auth.mfa.unenroll(factorId);
  }

  Future<MfaStatusModel> getMfaStatus() async {
    if (_client == null || !isAuthenticated) {
      return const MfaStatusModel(isEnrolled: false, isAal2: false, factors: []);
    }
    try {
      final factorsRes = await _client!.auth.mfa.listFactors();
      final verified = factorsRes.totp.where((f) => f.status == FactorStatus.verified).toList();
      final aalRes = _client!.auth.mfa.getAuthenticatorAssuranceLevel();
      final isAal2 = aalRes.currentLevel?.name == 'aal2';
      return MfaStatusModel(
        isEnrolled: verified.isNotEmpty,
        isAal2: isAal2,
        factors: verified,
      );
    } catch (e) {
      debugPrint('[Supabase] getMfaStatus error: $e');
      return const MfaStatusModel(isEnrolled: false, isAal2: false, factors: []);
    }
  }

  // ==========================================
  // 📊 PORTFOLIO & HOLDINGS
  // ==========================================
  Future<PortfolioSummaryModel> getPortfolioSummary() async {
    if (_client == null || !isAuthenticated) {
      return PortfolioSummaryModel.empty();
    }

    try {
      final user = currentUser!;
      // 1. Fetch total cashflow deposits and withdrawals (USDT cash) to calculate unallocated balance
      double totalDeposited = 0;
      double totalWithdrawn = 0;
      try {
        final cashflowData = await _client!
            .from('transactions')
            .select('type, coin_id, amount, total_amount, notes')
            .eq('user_id', user.id);

        for (final d in cashflowData) {
          final t = (d['type'] ?? '').toString().toUpperCase();
          final cid = d['coin_id'];
          final notes = (d['notes'] ?? '').toString();
          final amt = (d['total_amount'] as num?)?.toDouble() ??
              (d['amount'] as num?)?.toDouble() ??
              0.0;

          if (t == 'SALARY_DEPOSIT' || t == 'DEPOSIT') {
            totalDeposited += amt;
          } else if (t == 'WITHDRAWAL' || (t == 'SELL' && cid == null && notes.contains('[WITHDRAWAL]'))) {
            totalWithdrawn += amt;
          }
        }
      } catch (e) {
        debugPrint('[Supabase] Error fetching cashflow balance: $e');
      }

      final netDeposited = (totalDeposited - totalWithdrawn).clamp(0.0, double.infinity);

      // Query ALL holdings so realized P&L from closed positions is preserved
      final allHoldingsData = await _client!
          .from('holdings')
          .select()
          .eq('user_id', user.id);

      if (allHoldingsData.isEmpty) {
        return PortfolioSummaryModel(
          totalInvested: 0,
          currentValue: 0,
          unrealizedPnl: 0,
          unrealizedPnlPercentage: 0,
          realizedPnl: 0,
          coinsCount: 0,
          holdings: [],
          allocations: [],
          unallocatedUsdt: netDeposited,
          netPortfolioValue: netDeposited,
        );
      }

      // Separate open positions from liquidated positions
      final openPositionsData = allHoldingsData
          .where((h) => ((h['total_quantity'] as num?)?.toDouble() ?? 0.0) > 0.00000001)
          .toList();

      // Total realized P&L is summed across ALL holdings (including closed ones)
      double totalRealizedPnl = 0;
      for (final h in allHoldingsData) {
        totalRealizedPnl += (h['realized_pnl'] as num?)?.toDouble() ?? 0.0;
      }

      if (openPositionsData.isEmpty) {
        return PortfolioSummaryModel(
          totalInvested: 0,
          currentValue: 0,
          unrealizedPnl: 0,
          unrealizedPnlPercentage: 0,
          realizedPnl: totalRealizedPnl,
          coinsCount: 0,
          holdings: [],
          allocations: [],
          unallocatedUsdt: netDeposited,
          netPortfolioValue: netDeposited,
        );
      }

      final livePrices = await _fetchLivePricesWithFallback(openPositionsData);

      double totalInvested = 0;
      double currentValue = 0;
      final holdingsList = <HoldingModel>[];

      for (final h in openPositionsData) {
        final rawCoinId = h['coin_id'].toString();
        final canonicalId = AssetMapper.getCanonicalCoinId(rawCoinId);
        final symbol = (h['symbol'] ?? '').toString().toUpperCase();
        final totalQty = (h['total_quantity'] as num).toDouble();
        final avgBuyPrice = (h['average_buy_price'] as num).toDouble();
        final investedCost = (h['total_invested_cost'] as num).toDouble();
        final realized = (h['realized_pnl'] as num?)?.toDouble() ?? 0.0;

        final priceData = livePrices[canonicalId] ??
            livePrices[rawCoinId] ??
            livePrices[symbol] ??
            {'price': avgBuyPrice, 'change24h': 0.0, 'isStale': true};

        final currentPrice = (priceData['price'] as num).toDouble();
        final change24h = (priceData['change24h'] as num).toDouble();

        final coinCurrentValue = totalQty * currentPrice;
        final coinUnrealizedPnl = coinCurrentValue - investedCost;
        final coinUnrealizedPnlPercentage =
            investedCost > 0 ? (coinUnrealizedPnl / investedCost) * 100 : 0.0;

        totalInvested += investedCost;
        currentValue += coinCurrentValue;

        holdingsList.add(HoldingModel(
          id: h['id'],
          coinId: canonicalId,
          symbol: symbol,
          name: h['name'] ?? symbol,
          totalQuantity: totalQty,
          averageBuyPrice: avgBuyPrice,
          currentPrice: currentPrice,
          change24h: change24h,
          totalInvestedCost: investedCost,
          currentValue: coinCurrentValue,
          unrealizedPnl: coinUnrealizedPnl,
          unrealizedPnlPercentage: coinUnrealizedPnlPercentage,
          realizedPnl: realized,
        ));
      }

      final totalUnrealizedPnl = currentValue - totalInvested;
      final totalUnrealizedPnlPct =
          totalInvested > 0 ? (totalUnrealizedPnl / totalInvested) * 100 : 0.0;

      final allocations = holdingsList
          .map((h) => AssetAllocation(
                coinId: h.coinId,
                symbol: h.symbol,
                percentage: currentValue > 0 ? (h.currentValue / currentValue) * 100 : 0,
                value: h.currentValue,
              ))
          .toList();

      final unallocated = (netDeposited - totalInvested).clamp(0.0, double.infinity);
      final netPortfolio = currentValue + unallocated;

      return PortfolioSummaryModel(
        totalInvested: totalInvested,
        currentValue: currentValue,
        unrealizedPnl: totalUnrealizedPnl,
        unrealizedPnlPercentage: totalUnrealizedPnlPct,
        realizedPnl: totalRealizedPnl,
        coinsCount: holdingsList.length,
        holdings: holdingsList,
        allocations: allocations,
        unallocatedUsdt: unallocated,
        netPortfolioValue: netPortfolio,
      );
    } catch (e) {
      debugPrint('[Supabase] getPortfolioSummary error: $e');
      rethrow;
    }
  }

  // ==========================================
  // 📝 TRANSACTIONS (CRUD WITH ATOMIC RPCS)
  // ==========================================
  Future<List<TransactionModel>> getTransactions({int limit = 100, int offset = 0}) async {
    if (_client == null || !isAuthenticated) {
      return [];
    }

    try {
      final res = await _client!
          .from('transactions')
          .select()
          .eq('user_id', currentUser!.id)
          .order('transaction_date', ascending: false)
          .range(offset, offset + limit - 1);

      return (res as List).map((row) => TransactionModel(
            id: row['id'],
            type: row['type'],
            coinId: row['coin_id'],
            symbol: row['symbol'],
            name: row['name'],
            amount: (row['amount'] as num).toDouble(),
            pricePerUnit: (row['price_per_unit'] as num).toDouble(),
            totalAmount: (row['total_amount'] as num).toDouble(),
            fee: (row['fee'] as num?)?.toDouble() ?? 0.0,
            transactionDate: DateTime.parse(row['transaction_date']),
            notes: row['notes'] ?? '',
            originalCurrency: row['original_currency'] ?? 'USD',
            originalAmount: (row['original_amount'] as num?)?.toDouble(),
            fxToBase: (row['fx_to_base'] as num?)?.toDouble() ?? 1.0,
          )).toList();
    } catch (e) {
      debugPrint('[Supabase] getTransactions error: $e');
      rethrow;
    }
  }

  Future<List<TransactionModel>> getAllTransactionsForExport() async {
    if (_client == null || !isAuthenticated) return [];

    final allList = <TransactionModel>[];
    int offset = 0;
    const batchSize = 500;

    while (true) {
      final batch = await getTransactions(limit: batchSize, offset: offset);
      if (batch.isEmpty) break;
      allList.addAll(batch);
      if (batch.length < batchSize) break;
      offset += batchSize;
    }

    return allList;
  }

  Future<bool> createTransaction(Map<String, dynamic> data) async {
    if (_client == null || !isAuthenticated) return false;

    final opId = _uuid.v4();
    try {
      final amount = (data['amount'] as num).toDouble();
      final price = (data['pricePerUnit'] as num).toDouble();
      final rawSymbol = data['symbol']?.toString() ?? 'BTC';
      final coinId = AssetMapper.getCanonicalCoinId(data['coinId'] ?? rawSymbol);

      // Attempt atomic database RPC
      try {
        final res = await _client!.rpc('create_trade', params: {
          'p_operation_id': opId,
          'p_type': data['type'] ?? 'BUY',
          'p_symbol': rawSymbol.toUpperCase(),
          'p_name': data['name'] ?? rawSymbol,
          'p_coin_id': coinId,
          'p_amount': amount,
          'p_price': price,
          'p_fee': (data['fee'] as num?)?.toDouble() ?? 0.0,
          'p_date': data['transactionDate'] ?? DateTime.now().toIso8601String(),
          'p_notes': data['notes'] ?? '',
          'p_original_currency': data['originalCurrency'] ?? 'USD',
          'p_original_amount': (data['originalAmount'] as num?)?.toDouble() ?? amount,
          'p_fx_to_base': (data['fxToBase'] as num?)?.toDouble() ?? 1.0,
        });
        if (res != null && res['success'] == true) {
          return true;
        }
      } catch (rpcErr) {
        debugPrint('[Supabase] create_trade RPC fallback: $rpcErr');
      }

      // Fallback: standard direct table insert
      final total = amount * price;
      await _client!.from('transactions').insert({
        'user_id': currentUser!.id,
        'type': data['type'],
        'coin_id': coinId,
        'symbol': rawSymbol.toUpperCase(),
        'name': data['name'],
        'amount': amount,
        'price_per_unit': price,
        'total_amount': total,
        'fee': (data['fee'] as num?)?.toDouble() ?? 0.0,
        'transaction_date': data['transactionDate'] ?? DateTime.now().toIso8601String(),
        'notes': data['notes'] ?? '',
        'original_currency': data['originalCurrency'] ?? 'USD',
        'original_amount': (data['originalAmount'] as num?)?.toDouble() ?? amount,
        'fx_to_base': (data['fxToBase'] as num?)?.toDouble() ?? 1.0,
        'operation_id': opId,
      });
      return true;
    } catch (e) {
      debugPrint('[Supabase] createTransaction error: $e');
      return false;
    }
  }

  Future<bool> updateTransaction(String id, Map<String, dynamic> data) async {
    if (_client == null || !isAuthenticated) return false;

    final opId = _uuid.v4();
    try {
      final amount = (data['amount'] as num).toDouble();
      final price = (data['pricePerUnit'] as num).toDouble();
      final rawSymbol = data['symbol']?.toString() ?? 'BTC';
      final coinId = AssetMapper.getCanonicalCoinId(data['coinId'] ?? rawSymbol);

      // Attempt atomic database RPC
      try {
        final res = await _client!.rpc('update_trade', params: {
          'p_operation_id': opId,
          'p_tx_id': id,
          'p_type': data['type'] ?? 'BUY',
          'p_symbol': rawSymbol.toUpperCase(),
          'p_name': data['name'] ?? rawSymbol,
          'p_coin_id': coinId,
          'p_amount': amount,
          'p_price': price,
          'p_fee': (data['fee'] as num?)?.toDouble() ?? 0.0,
          'p_date': data['transactionDate'] ?? DateTime.now().toIso8601String(),
          'p_notes': data['notes'] ?? '',
          'p_original_currency': data['originalCurrency'] ?? 'USD',
          'p_original_amount': (data['originalAmount'] as num?)?.toDouble() ?? amount,
          'p_fx_to_base': (data['fxToBase'] as num?)?.toDouble() ?? 1.0,
        });
        if (res != null && res['success'] == true) {
          return true;
        }
      } catch (rpcErr) {
        debugPrint('[Supabase] update_trade RPC fallback: $rpcErr');
      }

      // Fallback
      final total = amount * price;
      await _client!.from('transactions').update({
        'type': data['type'],
        'coin_id': coinId,
        'symbol': rawSymbol.toUpperCase(),
        'name': data['name'],
        'amount': amount,
        'price_per_unit': price,
        'total_amount': total,
        'fee': (data['fee'] as num?)?.toDouble() ?? 0.0,
        'transaction_date': data['transactionDate'] ?? DateTime.now().toIso8601String(),
        'notes': data['notes'] ?? '',
        'original_currency': data['originalCurrency'] ?? 'USD',
        'original_amount': (data['originalAmount'] as num?)?.toDouble() ?? amount,
        'fx_to_base': (data['fxToBase'] as num?)?.toDouble() ?? 1.0,
      }).eq('id', id).eq('user_id', currentUser!.id);
      return true;
    } catch (e) {
      debugPrint('[Supabase] updateTransaction error: $e');
      return false;
    }
  }

  Future<bool> deleteTransaction(String id) async {
    if (_client == null || !isAuthenticated) return false;

    final opId = _uuid.v4();
    try {
      try {
        final res = await _client!.rpc('delete_trade', params: {
          'p_operation_id': opId,
          'p_tx_id': id,
        });
        if (res != null && res['success'] == true) {
          return true;
        }
      } catch (rpcErr) {
        debugPrint('[Supabase] delete_trade RPC fallback: $rpcErr');
      }

      await _client!
          .from('transactions')
          .delete()
          .eq('id', id)
          .eq('user_id', currentUser!.id);
      return true;
    } catch (e) {
      debugPrint('[Supabase] deleteTransaction error: $e');
      return false;
    }
  }

  // ==========================================
  // 💰 SALARY DCA TRACKING (ATOMIC)
  // ==========================================
  Future<SalaryReportModel> getSalaryReport() async {
    if (_client == null || !isAuthenticated) {
      return SalaryReportModel.empty();
    }

    try {
      final profile = await _client!
          .from('profiles')
          .select()
          .eq('id', currentUser!.id)
          .maybeSingle();

      final allocations = await _client!
          .from('salary_allocations')
          .select()
          .eq('user_id', currentUser!.id)
          .order('year_month', ascending: false);

      final totalAllocated = (allocations as List).fold<double>(
        0.0,
        (sum, a) => sum + ((a['allocated_amount'] as num).toDouble()),
      );

      final items = allocations.map((a) => SalaryAllocationItem(
            yearMonth: a['year_month'],
            salaryAmount: (a['salary_amount'] as num).toDouble(),
            allocatedAmount: (a['allocated_amount'] as num).toDouble(),
            allocationPercentage: (a['allocation_percentage'] as num).toDouble(),
            notes: a['notes'] ?? '',
            originalCurrency: a['original_currency'] ?? 'USD',
            originalSalaryAmount: (a['original_salary_amount'] as num?)?.toDouble(),
            originalAllocatedAmount: (a['original_allocated_amount'] as num?)?.toDouble(),
            fxToBase: (a['fx_to_base'] as num?)?.toDouble() ?? 1.0,
          )).toList();

      return SalaryReportModel(
        userSalary: (profile?['monthly_salary'] as num?)?.toDouble() ?? 0.0,
        targetAllocationPercent:
            (profile?['crypto_allocation_percentage'] as num?)?.toDouble() ?? 10.0,
        totalDepositedToCrypto: totalAllocated,
        allocations: items,
      );
    } catch (e) {
      debugPrint('[Supabase] getSalaryReport error: $e');
      rethrow;
    }
  }

  Future<bool> saveSalaryAllocation(Map<String, dynamic> data) async {
    if (_client == null || !isAuthenticated) return false;

    final opId = _uuid.v4();
    try {
      final salary = (data['salaryAmount'] as num).toDouble();
      final allocated = (data['allocatedAmount'] as num).toDouble();
      final pct = salary > 0 ? (allocated / salary) * 100 : 0.0;
      final yearMonth = data['yearMonth'] as String;

      // Attempt atomic database RPC
      try {
        final res = await _client!.rpc('save_salary_allocation', params: {
          'p_operation_id': opId,
          'p_year_month': yearMonth,
          'p_salary': salary,
          'p_allocated': allocated,
          'p_percentage': pct,
          'p_notes': data['notes'] ?? '',
          'p_original_currency': data['originalCurrency'] ?? 'USD',
          'p_fx_to_base': (data['fxToBase'] as num?)?.toDouble() ?? 1.0,
          'p_effective_date': data['effectiveDate'] ?? DateTime.now().toIso8601String(),
        });
        if (res != null && res['success'] == true) {
          return true;
        }
      } catch (rpcErr) {
        debugPrint('[Supabase] save_salary_allocation RPC fallback: $rpcErr');
      }

      // Fallback: standard upsert
      final allocRes = await _client!.from('salary_allocations').upsert({
        'user_id': currentUser!.id,
        'year_month': yearMonth,
        'salary_amount': salary,
        'allocated_amount': allocated,
        'allocation_percentage': pct,
        'notes': data['notes'] ?? '',
        'original_currency': data['originalCurrency'] ?? 'USD',
        'fx_to_base': (data['fxToBase'] as num?)?.toDouble() ?? 1.0,
        'operation_id': opId,
      }, onConflict: 'user_id,year_month').select('id').maybeSingle();

      final allocId = allocRes?['id'];

      // Check if linked deposit transaction exists
      final existingTx = allocId != null
          ? await _client!
              .from('transactions')
              .select('id')
              .eq('salary_allocation_id', allocId)
              .maybeSingle()
          : null;

      if (existingTx != null) {
        await _client!.from('transactions').update({
          'price_per_unit': allocated,
          'total_amount': allocated,
          'notes': 'Salary Deposit for $yearMonth',
          'original_amount': allocated,
        }).eq('id', existingTx['id']);
      } else {
        await _client!.from('transactions').insert({
          'user_id': currentUser!.id,
          'type': 'SALARY_DEPOSIT',
          'amount': 1,
          'price_per_unit': allocated,
          'total_amount': allocated,
          'fee': 0,
          'notes': 'Salary Deposit for $yearMonth',
          'original_currency': data['originalCurrency'] ?? 'USD',
          'original_amount': allocated,
          'fx_to_base': (data['fxToBase'] as num?)?.toDouble() ?? 1.0,
          'salary_allocation_id': allocId,
        });
      }

      return true;
    } catch (e) {
      debugPrint('[Supabase] saveSalaryAllocation error: $e');
      return false;
    }
  }

  Future<bool> deleteSalaryAllocation(String yearMonth) async {
    if (_client == null || !isAuthenticated) return false;

    final opId = _uuid.v4();
    try {
      try {
        final res = await _client!.rpc('delete_salary_allocation', params: {
          'p_operation_id': opId,
          'p_year_month': yearMonth,
        });
        if (res != null && res['success'] == true) {
          return true;
        }
      } catch (rpcErr) {
        debugPrint('[Supabase] delete_salary_allocation RPC fallback: $rpcErr');
      }

      final alloc = await _client!
          .from('salary_allocations')
          .select('id')
          .eq('year_month', yearMonth)
          .eq('user_id', currentUser!.id)
          .maybeSingle();

      if (alloc != null) {
        // Delete linked deposit
        await _client!
            .from('transactions')
            .delete()
            .eq('salary_allocation_id', alloc['id']);

        await _client!
            .from('salary_allocations')
            .delete()
            .eq('id', alloc['id']);
      }
      return true;
    } catch (e) {
      debugPrint('[Supabase] deleteSalaryAllocation error: $e');
      return false;
    }
  }

  // ==========================================
  // 💵 CASHFLOW DEPOSITS & WITHDRAWALS (CLOUD SYNCED)
  // ==========================================
  Future<List<CashflowItem>> getCashflowRecords() async {
    if (_client == null || !isAuthenticated) return [];

    try {
      final res = await _client!
          .from('transactions')
          .select()
          .eq('user_id', currentUser!.id)
          .order('transaction_date', ascending: false);

      final list = <CashflowItem>[];
      for (final row in res) {
        final t = (row['type'] ?? '').toString().toUpperCase();
        final cid = row['coin_id'];
        final notes = (row['notes'] ?? '').toString();
        final isDep = t == 'SALARY_DEPOSIT' || t == 'DEPOSIT';
        final isWd = t == 'WITHDRAWAL' || (t == 'SELL' && cid == null && notes.contains('[WITHDRAWAL]'));

        if (isDep || isWd) {
          final amt = (row['total_amount'] as num?)?.toDouble() ??
              (row['amount'] as num?)?.toDouble() ??
              0.0;
          final cleanNotes = notes
              .replaceAll('[WITHDRAWAL] ', '')
              .replaceAll('[WITHDRAWAL]', '')
              .trim();

          list.add(CashflowItem(
            id: row['id'].toString(),
            type: isWd ? 'WITHDRAWAL' : 'DEPOSIT',
            amount: amt,
            category: row['name']?.toString() ?? (isDep ? 'Deposit' : 'Withdrawal'),
            date: DateTime.tryParse(row['transaction_date']?.toString() ?? '') ?? DateTime.now(),
            notes: cleanNotes,
          ));
        }
      }

      // If no records in transactions, attempt legacy import from salary_allocations
      if (list.isEmpty) {
        try {
          final legacyAllocations = await _client!
              .from('salary_allocations')
              .select()
              .eq('user_id', currentUser!.id)
              .order('year_month', ascending: false);

          for (final a in legacyAllocations) {
            final amt = (a['allocated_amount'] as num?)?.toDouble() ?? 0.0;
            if (amt > 0) {
              final ym = a['year_month']?.toString() ?? '';
              list.add(CashflowItem(
                id: a['id']?.toString() ?? 'sal_$ym',
                type: 'DEPOSIT',
                amount: amt,
                category: 'Salary Inflow',
                date: DateTime.tryParse('$ym-01') ?? DateTime.now(),
                notes: a['notes']?.toString() ?? 'Monthly Salary Allocation',
              ));
            }
          }
        } catch (_) {}
      }

      // Sort descending
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    } catch (e) {
      debugPrint('[Supabase] getCashflowRecords error: $e');
      return [];
    }
  }

  Future<CashflowItem?> addCashflowRecord({
    required String type, // 'DEPOSIT' or 'WITHDRAWAL'
    required double amount,
    required String category,
    required DateTime date,
    String notes = '',
  }) async {
    if (_client == null || !isAuthenticated) return null;

    final id = _uuid.v4();
    final isWithdrawal = type.toUpperCase() == 'WITHDRAWAL';

    try {
      if (isWithdrawal) {
        bool inserted = false;
        try {
          await _client!.from('transactions').insert({
            'id': id,
            'user_id': currentUser!.id,
            'type': 'WITHDRAWAL',
            'symbol': 'USDT',
            'coin_id': null,
            'name': category,
            'amount': amount,
            'price_per_unit': 1.0,
            'total_amount': amount,
            'fee': 0.0,
            'transaction_date': date.toIso8601String(),
            'notes': notes,
            'original_currency': 'USD',
            'original_amount': amount,
            'fx_to_base': 1.0,
          });
          inserted = true;
        } catch (wdErr) {
          debugPrint('[Supabase] WITHDRAWAL direct type fallback: $wdErr');
        }

        if (!inserted) {
          await _client!.from('transactions').insert({
            'id': id,
            'user_id': currentUser!.id,
            'type': 'SELL',
            'symbol': 'USDT',
            'coin_id': null,
            'name': category,
            'amount': amount,
            'price_per_unit': 1.0,
            'total_amount': amount,
            'fee': 0.0,
            'transaction_date': date.toIso8601String(),
            'notes': '[WITHDRAWAL] $notes'.trim(),
            'original_currency': 'USD',
            'original_amount': amount,
            'fx_to_base': 1.0,
          });
        }
      } else {
        bool inserted = false;
        try {
          await _client!.from('transactions').insert({
            'id': id,
            'user_id': currentUser!.id,
            'type': 'DEPOSIT',
            'symbol': 'USDT',
            'coin_id': null,
            'name': category,
            'amount': 1.0,
            'price_per_unit': amount,
            'total_amount': amount,
            'fee': 0.0,
            'transaction_date': date.toIso8601String(),
            'notes': notes,
            'original_currency': 'USD',
            'original_amount': amount,
            'fx_to_base': 1.0,
          });
          inserted = true;
        } catch (depErr) {
          debugPrint('[Supabase] DEPOSIT direct type fallback: $depErr');
        }

        if (!inserted) {
          await _client!.from('transactions').insert({
            'id': id,
            'user_id': currentUser!.id,
            'type': 'SALARY_DEPOSIT',
            'symbol': 'USDT',
            'coin_id': null,
            'name': category,
            'amount': 1.0,
            'price_per_unit': amount,
            'total_amount': amount,
            'fee': 0.0,
            'transaction_date': date.toIso8601String(),
            'notes': notes,
            'original_currency': 'USD',
            'original_amount': amount,
            'fx_to_base': 1.0,
          });
        }
      }

      return CashflowItem(
        id: id,
        type: type,
        amount: amount,
        category: category,
        date: date,
        notes: notes,
      );
    } catch (e) {
      debugPrint('[Supabase] addCashflowRecord error: $e');
      return null;
    }
  }

  Future<bool> updateCashflowRecord({
    required String id,
    required String type,
    required double amount,
    required String category,
    required DateTime date,
    String notes = '',
  }) async {
    if (_client == null || !isAuthenticated) return false;

    final isWithdrawal = type.toUpperCase() == 'WITHDRAWAL';
    try {
      await _client!.from('transactions').update({
        'name': category,
        'amount': isWithdrawal ? amount : 1.0,
        'price_per_unit': isWithdrawal ? 1.0 : amount,
        'total_amount': amount,
        'transaction_date': date.toIso8601String(),
        'notes': isWithdrawal ? '[WITHDRAWAL] $notes'.trim() : notes,
        'original_amount': amount,
      }).eq('id', id).eq('user_id', currentUser!.id);

      return true;
    } catch (e) {
      debugPrint('[Supabase] updateCashflowRecord error: $e');
      return false;
    }
  }

  Future<bool> deleteCashflowRecord(String id) async {
    if (_client == null || !isAuthenticated) return false;

    try {
      await _client!
          .from('transactions')
          .delete()
          .eq('id', id)
          .eq('user_id', currentUser!.id);
      return true;
    } catch (e) {
      debugPrint('[Supabase] deleteCashflowRecord error: $e');
      return false;
    }
  }

  // ==========================================
  // 💼 EMPLOYMENT, SALARY, EPF & ETF CAREER ENGINE
  // ==========================================
  Future<List<EmploymentModel>> getEmployments() async {
    if (_client == null || !isAuthenticated) return [];

    try {
      final res = await _client!
          .from('employments')
          .select()
          .eq('user_id', currentUser!.id)
          .order('start_date', ascending: false);

      return (res as List).map((row) => EmploymentModel.fromJson(row)).toList();
    } catch (e) {
      debugPrint('[Supabase] getEmployments error: $e');
      return [];
    }
  }

  Future<EmploymentModel?> addEmployment({
    required String companyName,
    required String designation,
    double basicSalary = 0.0,
    double fixedAllowance = 0.0,
    double? monthlySalary,
    int salaryDay = 25,
    required DateTime startDate,
    DateTime? endDate,
    bool isCurrent = true,
    String notes = '',
    String currency = 'LKR',
  }) async {
    if (_client == null || !isAuthenticated) return null;

    final id = _uuid.v4();
    try {
      if (isCurrent && endDate == null) {
        try {
          await _client!
              .from('employments')
              .update({'is_current': false})
              .eq('user_id', currentUser!.id)
              .isFilter('end_date', null);
        } catch (_) {}
      }

      final bSalary = basicSalary > 0 ? basicSalary : (monthlySalary ?? 0.0);
      final fAllowance = fixedAllowance;
      final mSalary = (basicSalary > 0 || fixedAllowance > 0)
          ? (bSalary + fAllowance)
          : (monthlySalary ?? bSalary);

      final data = {
        'id': id,
        'user_id': currentUser!.id,
        'company_name': companyName.trim(),
        'designation': designation.trim(),
        'basic_salary': bSalary,
        'fixed_allowance': fAllowance,
        'monthly_salary': mSalary,
        'salary_day': salaryDay,
        'start_date': startDate.toIso8601String().split('T').first,
        'end_date': endDate?.toIso8601String().split('T').first,
        'is_current': isCurrent,
        'notes': notes.trim(),
        'currency': currency,
      };

      await _client!.from('employments').insert(data);

      return EmploymentModel(
        id: id,
        userId: currentUser!.id,
        companyName: companyName,
        designation: designation,
        basicSalary: bSalary,
        fixedAllowance: fAllowance,
        monthlySalary: mSalary,
        salaryDay: salaryDay,
        startDate: startDate,
        endDate: endDate,
        isCurrent: isCurrent,
        notes: notes,
        currency: currency,
      );
    } catch (e) {
      debugPrint('[Supabase] addEmployment error: $e');
      return null;
    }
  }

  Future<bool> updateEmployment({
    required String id,
    required String companyName,
    required String designation,
    double basicSalary = 0.0,
    double fixedAllowance = 0.0,
    double? monthlySalary,
    required int salaryDay,
    required DateTime startDate,
    DateTime? endDate,
    required bool isCurrent,
    String notes = '',
    String currency = 'LKR',
  }) async {
    if (_client == null || !isAuthenticated) return false;

    try {
      final bSalary = basicSalary > 0 ? basicSalary : (monthlySalary ?? 0.0);
      final fAllowance = fixedAllowance;
      final mSalary = (basicSalary > 0 || fixedAllowance > 0)
          ? (bSalary + fAllowance)
          : (monthlySalary ?? bSalary);

      await _client!.from('employments').update({
        'company_name': companyName.trim(),
        'designation': designation.trim(),
        'basic_salary': bSalary,
        'fixed_allowance': fAllowance,
        'monthly_salary': mSalary,
        'salary_day': salaryDay,
        'start_date': startDate.toIso8601String().split('T').first,
        'end_date': endDate?.toIso8601String().split('T').first,
        'is_current': isCurrent,
        'notes': notes.trim(),
        'currency': currency,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id).eq('user_id', currentUser!.id);

      return true;
    } catch (e) {
      debugPrint('[Supabase] updateEmployment error: $e');
      return false;
    }
  }

  Future<bool> markJobResigned({
    required String id,
    required DateTime resignationDate,
  }) async {
    if (_client == null || !isAuthenticated) return false;

    try {
      await _client!.from('employments').update({
        'end_date': resignationDate.toIso8601String().split('T').first,
        'is_current': false,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id).eq('user_id', currentUser!.id);

      return true;
    } catch (e) {
      debugPrint('[Supabase] markJobResigned error: $e');
      return false;
    }
  }

  Future<bool> deleteEmployment(String id) async {
    if (_client == null || !isAuthenticated) return false;

    try {
      await _client!
          .from('employments')
          .delete()
          .eq('id', id)
          .eq('user_id', currentUser!.id);

      return true;
    } catch (e) {
      debugPrint('[Supabase] deleteEmployment error: $e');
      return false;
    }
  }

  // ==========================================
  // 🏦 BANK ACCOUNT & INITIAL BALANCE
  // ==========================================
  Future<BankAccountModel?> getBankAccount() async {
    if (_client == null || !isAuthenticated) return null;

    try {
      final res = await _client!
          .from('bank_accounts')
          .select()
          .eq('user_id', currentUser!.id)
          .maybeSingle();

      if (res != null) {
        return BankAccountModel.fromJson(res);
      }
    } catch (e) {
      debugPrint('[Supabase] getBankAccount error: $e');
    }
    return null;
  }

  Future<BankAccountModel?> upsertBankAccount(BankAccountModel account) async {
    if (_client == null || !isAuthenticated) return null;

    try {
      final payload = {
        'user_id': currentUser!.id,
        'bank_name': account.bankName.trim(),
        'account_number': account.accountNumber.trim(),
        'initial_balance': account.initialBalance,
        'initial_balance_date': account.initialBalanceDate.toIso8601String().split('T').first,
        'currency': account.currency,
        'auto_credit_salary': account.autoCreditSalary,
        'salary_start_month': account.salaryStartMonth,
        'notes': account.notes.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final res = await _client!
          .from('bank_accounts')
          .upsert(payload, onConflict: 'user_id')
          .select()
          .single();

      return BankAccountModel.fromJson(res);
    } catch (e) {
      debugPrint('[Supabase] upsertBankAccount error: $e');
      return null;
    }
  }

  // ==========================================
  // 💸 CASH RECORDS (INCOME, EXPENSE, INVEST)
  // ==========================================
  Future<List<CashRecordModel>> getCashRecords({String? yearMonth}) async {
    if (_client == null || !isAuthenticated) return [];

    try {
      var query = _client!
          .from('cash_records')
          .select()
          .eq('user_id', currentUser!.id);

      if (yearMonth != null && yearMonth.isNotEmpty) {
        query = query.eq('year_month', yearMonth);
      }

      final res = await query.order('record_date', ascending: false);
      return (res as List).map((row) => CashRecordModel.fromJson(row)).toList();
    } catch (e) {
      debugPrint('[Supabase] getCashRecords error: $e');
      return [];
    }
  }

  Future<CashRecordModel?> addCashRecord(CashRecordModel record) async {
    if (_client == null || !isAuthenticated) return null;

    try {
      final payload = {
        'user_id': currentUser!.id,
        'type': record.type,
        'category': record.category,
        'amount': record.amount,
        'record_date': record.recordDate.toIso8601String().split('T').first,
        'year_month': record.yearMonth,
        'notes': record.notes.trim(),
        'source_employment_id': record.sourceEmploymentId,
        'is_auto_generated': record.isAutoGenerated,
      };

      final res = await _client!
          .from('cash_records')
          .insert(payload)
          .select()
          .single();

      return CashRecordModel.fromJson(res);
    } catch (e) {
      debugPrint('[Supabase] addCashRecord error: $e');
      return null;
    }
  }

  Future<bool> deleteCashRecord(String recordId) async {
    if (_client == null || !isAuthenticated) return false;

    try {
      await _client!
          .from('cash_records')
          .delete()
          .eq('id', recordId)
          .eq('user_id', currentUser!.id);
      return true;
    } catch (e) {
      debugPrint('[Supabase] deleteCashRecord error: $e');
      return false;
    }
  }

  // ==========================================
  // 📊 BUDGET & INVESTMENT ALLOCATION PLANS
  // ==========================================
  Future<MonthlyBudgetPlanModel?> getBudgetPlan() async {
    if (_client == null || !isAuthenticated) return null;

    try {
      final res = await _client!
          .from('monthly_budget_plans')
          .select()
          .eq('user_id', currentUser!.id)
          .maybeSingle();

      if (res != null) {
        return MonthlyBudgetPlanModel.fromJson(res);
      }
    } catch (e) {
      debugPrint('[Supabase] getBudgetPlan error: $e');
    }
    return null;
  }

  Future<MonthlyBudgetPlanModel?> upsertBudgetPlan(MonthlyBudgetPlanModel plan) async {
    if (_client == null || !isAuthenticated) return null;

    try {
      final payload = {
        'user_id': currentUser!.id,
        'savings_percentage': plan.savingsPercentage,
        'crypto_percentage': plan.cryptoPercentage,
        'other_invest_percentage': plan.otherInvestPercentage,
        'expenses_percentage': plan.expensesPercentage,
        'emergency_fund_target': plan.emergencyFundTarget,
        'notes': plan.notes,
        'updated_at': DateTime.now().toIso8601String(),
      };

      final res = await _client!
          .from('monthly_budget_plans')
          .upsert(payload, onConflict: 'user_id')
          .select()
          .single();

      return MonthlyBudgetPlanModel.fromJson(res);
    } catch (e) {
      debugPrint('[Supabase] upsertBudgetPlan error: $e');
      return null;
    }
  }

  // ==========================================
  // 🌐 LIVE CRYPTO PRICES WITH BINANCE FALLBACK
  // ==========================================
  Future<Map<String, dynamic>> _fetchLivePricesWithFallback(List<dynamic> holdings) async {
    final Map<String, dynamic> priceMap = {};

    // 1. Fetch Binance live tickers for 400+ coins
    try {
      final binanceTickers = await _binanceService.getUsdtTickers();
      for (final t in binanceTickers) {
        priceMap[t.symbol.toUpperCase()] = {
          'price': t.price,
          'change24h': t.priceChangePercent,
          'isStale': t.isStale,
        };
        final canonId = AssetMapper.getCanonicalCoinId(t.symbol);
        priceMap[canonId] = priceMap[t.symbol.toUpperCase()];
      }
    } catch (e) {
      debugPrint('[SupabaseService] Binance tickers fetch notice: $e');
    }

    // 2. Fetch CoinGecko prices for any missing assets
    final missingIds = <String>[];
    for (final h in holdings) {
      final rawCoinId = h['coin_id']?.toString() ?? '';
      final symbol = (h['symbol'] ?? '').toString().toUpperCase();
      final canonId = AssetMapper.getCanonicalCoinId(rawCoinId.isNotEmpty ? rawCoinId : symbol);

      if (!priceMap.containsKey(canonId) && !priceMap.containsKey(symbol)) {
        missingIds.add(canonId);
      }
    }

    if (missingIds.isNotEmpty) {
      try {
        final idsParam = missingIds.toSet().join(',');
        final res = await http.get(
          Uri.parse('https://api.coingecko.com/api/v3/simple/price?ids=$idsParam&vs_currencies=usd&include_24hr_change=true'),
        ).timeout(const Duration(seconds: 4));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          for (final id in missingIds) {
            if (data[id] != null) {
              priceMap[id] = {
                'price': (data[id]['usd'] as num?)?.toDouble() ?? 0.0,
                'change24h': (data[id]['usd_24h_change'] as num?)?.toDouble() ?? 0.0,
                'isStale': false,
              };
            }
          }
        }
      } catch (_) {}
    }

    return priceMap;
  }
}
