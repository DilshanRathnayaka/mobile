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
import 'spring_boot_service.dart';
import '../../core/constants/app_backend_config.dart';

class SupabaseService {
  final BinanceService _binanceService = BinanceService();
  final SpringBootService _springBootService = SpringBootService();
  SpringBootService get springBootService => _springBootService;
  final _uuid = const Uuid();

  SupabaseClient? get _client {
    // When Spring Boot backend is active, NEVER touch Supabase!
    if (AppBackendConfig.isSpringBoot) return null;

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

  User? get currentUser {
    if (AppBackendConfig.isSpringBoot) {
      final sbUser = _springBootService.currentUser;
      if (sbUser == null) return null;
      return User(
        id: sbUser.id,
        appMetadata: {},
        userMetadata: {'display_name': sbUser.displayName},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
        email: sbUser.email,
      );
    }
    return _client?.auth.currentUser;
  }

  bool get isAuthenticated {
    if (AppBackendConfig.isSpringBoot) {
      return _springBootService.isAuthenticated;
    }
    return currentUser != null;
  }

  /// Subscribes to Supabase Realtime changes on holdings and transactions tables.
  RealtimeChannel? subscribeToPortfolioChanges({required void Function() onChange}) {
    if (AppBackendConfig.isSpringBoot) return null;
    if (_client == null || !isAuthenticated) return null;
    final userId = currentUser!.id;
    try {
      final channel = _client!.channel('public_portfolio_$userId');
      channel
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'holdings',
            callback: (payload) {
              debugPrint('[Supabase Realtime] holdings changed: ${payload.eventType}');
              onChange();
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'transactions',
            callback: (payload) {
              debugPrint('[Supabase Realtime] transactions changed: ${payload.eventType}');
              onChange();
            },
          )
          .subscribe();
      return channel;
    } catch (e) {
      debugPrint('[Supabase Realtime] Subscribe error: $e');
      return null;
    }
  }

  // ==========================================
  // 🔐 AUTHENTICATION & PASSWORD RECOVERY
  // ==========================================
  Future<AuthResponse?> signUp(String email, String password) async {
    if (AppBackendConfig.isSpringBoot) {
      final sbUser = await _springBootService.signUp(email, password);
      final user = User(
        id: sbUser.id,
        appMetadata: {},
        userMetadata: {'display_name': sbUser.displayName},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
        email: sbUser.email,
      );
      return AuthResponse(
        session: Session(accessToken: 'sb_jwt', tokenType: 'bearer', user: user),
        user: user,
      );
    }
    if (_client == null) throw Exception('Supabase is not initialized');
    return await _client!.auth.signUp(email: email, password: password);
  }

  Future<AuthResponse?> signIn(String email, String password) async {
    if (AppBackendConfig.isSpringBoot) {
      final sbUser = await _springBootService.signIn(email, password);
      final user = User(
        id: sbUser.id,
        appMetadata: {},
        userMetadata: {'display_name': sbUser.displayName},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
        email: sbUser.email,
      );
      return AuthResponse(
        session: Session(accessToken: 'sb_jwt', tokenType: 'bearer', user: user),
        user: user,
      );
    }
    if (_client == null) throw Exception('Supabase is not initialized');
    return await _client!.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    if (AppBackendConfig.isSpringBoot) {
      await _springBootService.signOut();
      return;
    }
    if (_client != null) {
      await _client!.auth.signOut();
    }
  }

  Future<void> resetPasswordForEmail(String email) async {
    if (AppBackendConfig.isSpringBoot) {
      // In Spring Boot, reset password can trigger backend email or prompt
      return;
    }
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

  Future<PortfolioSummaryModel> getPortfolioSummary() async {
    if (AppBackendConfig.isSpringBoot) {
      return await _springBootService.getPortfolioSummary();
    }
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
    if (AppBackendConfig.isSpringBoot) {
      return await _springBootService.getTransactions();
    }
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
    if (AppBackendConfig.isSpringBoot) {
      return await _springBootService.getTransactions();
    }
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
    if (AppBackendConfig.isSpringBoot) {
      final amount = (data['amount'] as num).toDouble();
      final price = (data['pricePerUnit'] as num).toDouble();
      final rawSymbol = data['symbol']?.toString() ?? 'BTC';
      final coinId = AssetMapper.getCanonicalCoinId(data['coinId'] ?? rawSymbol);
      final tx = TransactionModel(
        id: _uuid.v4(),
        type: data['type'] ?? 'BUY',
        coinId: coinId,
        symbol: rawSymbol.toUpperCase(),
        name: data['name'] ?? rawSymbol,
        amount: amount,
        pricePerUnit: price,
        totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? (amount * price),
        fee: (data['fee'] as num?)?.toDouble() ?? 0.0,
        originalCurrency: data['originalCurrency']?.toString() ?? 'USD',
        originalAmount: (data['originalAmount'] as num?)?.toDouble(),
        fxToBase: (data['fxToBase'] as num?)?.toDouble() ?? 1.0,
        transactionDate: data['transactionDate'] != null ? DateTime.parse(data['transactionDate'].toString()) : DateTime.now(),
        notes: data['notes']?.toString() ?? '',
        leverage: (data['leverage'] as num?)?.toDouble() ?? 1.0,
        margin: (data['margin'] as num?)?.toDouble(),
        liquidationPrice: (data['liquidationPrice'] as num?)?.toDouble(),
      );
      return await _springBootService.addTransaction(tx);
    }
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

        // If RPC executed without error, transaction is committed!
        return true;
      } catch (rpcErr) {
        debugPrint('[Supabase] create_trade RPC error: $rpcErr');
        final errStr = rpcErr.toString().toLowerCase();
        // If error was validation or inventory violation, fail immediately without fallback
        if (errStr.contains('inventory violation') || errStr.contains('unauthorized')) {
          return false;
        }
        // Only attempt fallback if RPC function literally does not exist
        if (!errStr.contains('function') && !errStr.contains('not found') && !errStr.contains('pgrst202')) {
          return false;
        }
      }

      // Fallback: ONLY IF RPC is missing on database
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
    if (AppBackendConfig.isSpringBoot) {
      await _springBootService.deleteTransaction(id);
      return await createTransaction(data);
    }
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
        return true;
      } catch (rpcErr) {
        debugPrint('[Supabase] update_trade RPC error: $rpcErr');
        final errStr = rpcErr.toString().toLowerCase();
        if (errStr.contains('inventory violation') || errStr.contains('unauthorized')) {
          return false;
        }
        if (!errStr.contains('function') && !errStr.contains('not found') && !errStr.contains('pgrst202')) {
          return false;
        }
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
    if (AppBackendConfig.isSpringBoot) {
      return await _springBootService.deleteTransaction(id);
    }
    if (_client == null || !isAuthenticated) return false;

    final opId = _uuid.v4();
    try {
      try {
        final res = await _client!.rpc('delete_trade', params: {
          'p_operation_id': opId,
          'p_tx_id': id,
        });
        return true;
      } catch (rpcErr) {
        debugPrint('[Supabase] delete_trade RPC error: $rpcErr');
        final errStr = rpcErr.toString().toLowerCase();
        if (!errStr.contains('function') && !errStr.contains('not found') && !errStr.contains('pgrst202')) {
          return false;
        }
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
    if (AppBackendConfig.isSpringBoot) {
      return await _springBootService.getSalaryReport();
    }
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
    if (AppBackendConfig.isSpringBoot) {
      return await _springBootService.saveSalaryAllocation(data);
    }
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
    if (AppBackendConfig.isSpringBoot) {
      return await _springBootService.deleteSalaryAllocation(yearMonth);
    }
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
    if (AppBackendConfig.isSpringBoot) {
      return await _springBootService.getCashflowRecords();
    }
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
          final origAmt = (row['original_amount'] as num?)?.toDouble();
          final origCurr = row['original_currency']?.toString();
          final rate = (row['fx_to_base'] as num?)?.toDouble() ??
              (row['price_per_unit'] as num?)?.toDouble();
          final isP2P = notes.toUpperCase().contains('[P2P]') ||
              (row['name']?.toString().toUpperCase().contains('P2P') ?? false) ||
              (rate != null && rate > 1.0) ||
              (origAmt != null && origAmt > 0);

          list.add(CashflowItem(
            id: row['id'].toString(),
            type: isWd ? 'WITHDRAWAL' : 'DEPOSIT',
            amount: amt,
            category: row['name']?.toString() ?? (isDep ? 'Deposit' : 'Withdrawal'),
            date: DateTime.tryParse(row['transaction_date']?.toString() ?? '') ?? DateTime.now(),
            notes: cleanNotes,
            isP2P: isP2P,
            p2pRate: rate != null && rate > 1.0 ? rate : null,
            localCurrency: origCurr,
            localAmount: origAmt,
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
    bool isP2P = false,
    double? p2pRate,
    String? localCurrency,
    double? localAmount,
  }) async {
    if (AppBackendConfig.isSpringBoot) {
      return await _springBootService.addCashflowRecord(
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
    if (_client == null || !isAuthenticated) return null;

    final id = _uuid.v4();
    final isWithdrawal = type.toUpperCase() == 'WITHDRAWAL';
    final rate = p2pRate ?? 1.0;
    final curr = (localCurrency != null && localCurrency.isNotEmpty) ? localCurrency : 'LKR';
    final calcLocal = localAmount ?? (amount * rate);
    final prefix = isP2P ? '[P2P] ' : '';
    final finalNotes = (isP2P && !notes.toUpperCase().contains('[P2P]'))
        ? '$prefix$notes'.trim()
        : notes;

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
            'pricePerUnit': rate,
            'price_per_unit': rate,
            'totalAmount': amount,
            'total_amount': amount,
            'fee': 0.0,
            'transaction_date': date.toIso8601String(),
            'notes': finalNotes,
            'original_currency': curr,
            'original_amount': calcLocal,
            'fx_to_base': rate,
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
            'price_per_unit': rate,
            'total_amount': amount,
            'fee': 0.0,
            'transaction_date': date.toIso8601String(),
            'notes': '[WITHDRAWAL] $finalNotes'.trim(),
            'original_currency': curr,
            'original_amount': calcLocal,
            'fx_to_base': rate,
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
            'amount': amount,
            'price_per_unit': rate,
            'total_amount': amount,
            'fee': 0.0,
            'transaction_date': date.toIso8601String(),
            'notes': finalNotes,
            'original_currency': curr,
            'original_amount': calcLocal,
            'fx_to_base': rate,
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
            'amount': amount,
            'price_per_unit': rate,
            'total_amount': amount,
            'fee': 0.0,
            'transaction_date': date.toIso8601String(),
            'notes': finalNotes,
            'original_currency': curr,
            'original_amount': calcLocal,
            'fx_to_base': rate,
          });
        }
      }

      return CashflowItem(
        id: id,
        type: type,
        amount: amount,
        category: category,
        date: date,
        notes: finalNotes,
        isP2P: isP2P,
        p2pRate: rate > 1.0 ? rate : null,
        localCurrency: curr,
        localAmount: calcLocal,
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
    bool isP2P = false,
    double? p2pRate,
    String? localCurrency,
    double? localAmount,
  }) async {
    if (AppBackendConfig.isSpringBoot) {
      return await _springBootService.updateCashflowRecord(
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
    }
    if (_client == null || !isAuthenticated) return false;

    final isWithdrawal = type.toUpperCase() == 'WITHDRAWAL';
    final rate = p2pRate ?? 1.0;
    final curr = (localCurrency != null && localCurrency.isNotEmpty) ? localCurrency : 'LKR';
    final calcLocal = localAmount ?? (amount * rate);
    final prefix = isP2P ? '[P2P] ' : '';
    final finalNotes = (isP2P && !notes.toUpperCase().contains('[P2P]'))
        ? '$prefix$notes'.trim()
        : notes;

    try {
      await _client!.from('transactions').update({
        'name': category,
        'amount': amount,
        'price_per_unit': rate,
        'total_amount': amount,
        'transaction_date': date.toIso8601String(),
        'notes': isWithdrawal ? '[WITHDRAWAL] $finalNotes'.trim() : finalNotes,
        'original_currency': curr,
        'original_amount': calcLocal,
        'fx_to_base': rate,
      }).eq('id', id).eq('user_id', currentUser!.id);

      return true;
    } catch (e) {
      debugPrint('[Supabase] updateCashflowRecord error: $e');
      return false;
    }
  }

  Future<bool> deleteCashflowRecord(String id) async {
    if (AppBackendConfig.isSpringBoot) {
      return await _springBootService.deleteCashflowRecord(id);
    }
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
    if (AppBackendConfig.isSpringBoot) {
      return await _springBootService.getEmployments();
    }
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
    bool isProbation = false,
    int probationMonths = 3,
    DateTime? probationEndDate,
    bool hasEpfEtfDuringProbation = true,
    bool hasFixedAllowanceDuringProbation = true,
    List<PromotionModel> promotions = const [],
  }) async {
    if (AppBackendConfig.isSpringBoot) {
      final bSalary = basicSalary > 0 ? basicSalary : (monthlySalary ?? 0.0);
      final fAllowance = fixedAllowance;
      final mSalary = (basicSalary > 0 || fixedAllowance > 0)
          ? (bSalary + fAllowance)
          : (monthlySalary ?? bSalary);
      final model = EmploymentModel(
        id: _uuid.v4(),
        userId: _springBootService.currentUserId ?? '',
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
        isProbation: isProbation,
        probationMonths: probationMonths,
        probationEndDate: probationEndDate,
        hasEpfEtfDuringProbation: hasEpfEtfDuringProbation,
        hasFixedAllowanceDuringProbation: hasFixedAllowanceDuringProbation,
        promotions: promotions,
      );
      final ok = await _springBootService.createEmployment(model);
      return ok ? model : null;
    }
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
        'is_probation': isProbation,
        'probation_months': probationMonths,
        'probation_end_date': probationEndDate?.toIso8601String().split('T').first,
        'has_epf_etf_during_probation': hasEpfEtfDuringProbation,
        'has_fixed_allowance_during_probation': hasFixedAllowanceDuringProbation,
        'promotions': promotions.map((p) => p.toJson()).toList(),
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
        isProbation: isProbation,
        probationMonths: probationMonths,
        probationEndDate: probationEndDate,
        hasEpfEtfDuringProbation: hasEpfEtfDuringProbation,
        hasFixedAllowanceDuringProbation: hasFixedAllowanceDuringProbation,
        promotions: promotions,
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
    bool isProbation = false,
    int probationMonths = 3,
    DateTime? probationEndDate,
    bool hasEpfEtfDuringProbation = true,
    bool hasFixedAllowanceDuringProbation = true,
    List<PromotionModel>? promotions,
  }) async {
    if (AppBackendConfig.isSpringBoot) {
      final bSalary = basicSalary > 0 ? basicSalary : (monthlySalary ?? 0.0);
      final fAllowance = fixedAllowance;
      final mSalary = (basicSalary > 0 || fixedAllowance > 0)
          ? (bSalary + fAllowance)
          : (monthlySalary ?? bSalary);
      final model = EmploymentModel(
        id: id,
        userId: _springBootService.currentUserId ?? '',
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
        isProbation: isProbation,
        probationMonths: probationMonths,
        probationEndDate: probationEndDate,
        hasEpfEtfDuringProbation: hasEpfEtfDuringProbation,
        hasFixedAllowanceDuringProbation: hasFixedAllowanceDuringProbation,
        promotions: promotions ?? const [],
      );
      return await _springBootService.createEmployment(model);
    }
    if (_client == null || !isAuthenticated) return false;

    try {
      final bSalary = basicSalary > 0 ? basicSalary : (monthlySalary ?? 0.0);
      final fAllowance = fixedAllowance;
      final mSalary = (basicSalary > 0 || fixedAllowance > 0)
          ? (bSalary + fAllowance)
          : (monthlySalary ?? bSalary);

      final updateData = <String, dynamic>{
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
        'is_probation': isProbation,
        'probation_months': probationMonths,
        'probation_end_date': probationEndDate?.toIso8601String().split('T').first,
        'has_epf_etf_during_probation': hasEpfEtfDuringProbation,
        'has_fixed_allowance_during_probation': hasFixedAllowanceDuringProbation,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (promotions != null) {
        updateData['promotions'] = promotions.map((p) => p.toJson()).toList();
      }

      await _client!.from('employments').update(updateData).eq('id', id).eq('user_id', currentUser!.id);

      return true;
    } catch (e) {
      debugPrint('[Supabase] updateEmployment error: $e');
      return false;
    }
  }

  /// Saves updated promotion history for an employment
  Future<bool> saveEmploymentPromotions({
    required EmploymentModel employment,
  }) async {
    if (AppBackendConfig.isSpringBoot) {
      return await _springBootService.createEmployment(employment);
    }
    if (_client == null || !isAuthenticated) return false;

    try {
      await _client!.from('employments').update({
        'promotions': employment.promotions.map((p) => p.toJson()).toList(),
        'designation': employment.activeDesignation,
        'basic_salary': employment.activeBasicSalary,
        'fixed_allowance': employment.activeFixedAllowance,
        'monthly_salary': employment.activeBasicSalary + employment.activeFixedAllowance,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', employment.id).eq('user_id', currentUser!.id);

      return true;
    } catch (e) {
      debugPrint('[Supabase] saveEmploymentPromotions error: $e');
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
    if (AppBackendConfig.isSpringBoot) {
      return await _springBootService.deleteEmployment(id);
    }
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
    if (AppBackendConfig.isSpringBoot) {
      return await _springBootService.getBankAccount();
    }
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
    if (AppBackendConfig.isSpringBoot) {
      return await _springBootService.upsertBankAccount(account);
    }
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
    if (AppBackendConfig.isSpringBoot) {
      return await _springBootService.getCashRecords(yearMonth: yearMonth);
    }
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
    if (AppBackendConfig.isSpringBoot) {
      return await _springBootService.addCashRecord(record);
    }
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
    if (AppBackendConfig.isSpringBoot) {
      return await _springBootService.deleteCashRecord(recordId);
    }
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
    if (AppBackendConfig.isSpringBoot) {
      return await _springBootService.getBudgetPlan();
    }
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
    if (AppBackendConfig.isSpringBoot) {
      return await _springBootService.upsertBudgetPlan(plan);
    }
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
  // 💼 SUPABASE MONTHLY SALARY AUTOMATION (EPF/ETF, BANK CREDIT, AUTO DCA)
  // ==========================================
  Future<Map<String, dynamic>?> processMonthlySalaryForSupabase({String? yearMonth}) async {
    if (_client == null || !isAuthenticated) return null;

    final targetYearMonth = (yearMonth != null && yearMonth.trim().isNotEmpty)
        ? yearMonth.trim()
        : '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';

    try {
      final user = currentUser!;
      final empList = await _client!
          .from('employments')
          .select()
          .eq('user_id', user.id)
          .order('start_date', ascending: false);

      if ((empList as List).isEmpty) {
        return {
          'status': 'NO_EMPLOYMENT',
          'message': 'No employment found to process salary',
        };
      }

      final activeEmp = (empList as List).firstWhere(
        (e) => (e['is_current'] == true || e['end_date'] == null),
        orElse: () => empList.first,
      );

      final basicSalary = (activeEmp['basic_salary'] as num?)?.toDouble() ?? 0.0;
      final fullFixedAllowance = (activeEmp['fixed_allowance'] as num?)?.toDouble() ?? 0.0;

      final isProbation = activeEmp['is_probation'] == true;
      final hasEpfDuringProbation = activeEmp['has_epf_etf_during_probation'] != false;
      final hasAllowanceDuringProbation = activeEmp['has_fixed_allowance_during_probation'] != false;
      bool currentlyInProbation = false;

      if (isProbation) {
        final probEndStr = activeEmp['probation_end_date']?.toString();
        if (probEndStr != null && probEndStr.isNotEmpty) {
          final probEnd = DateTime.tryParse(probEndStr);
          if (probEnd != null) {
            currentlyInProbation = DateTime.now().isBefore(probEnd);
          }
        } else {
          final startStr = activeEmp['start_date']?.toString();
          final start = DateTime.tryParse(startStr ?? '');
          final pMonths = (activeEmp['probation_months'] as num?)?.toInt() ?? 3;
          if (start != null) {
            final computedEnd = DateTime(start.year, start.month + pMonths, start.day);
            currentlyInProbation = DateTime.now().isBefore(computedEnd);
          } else {
            currentlyInProbation = true;
          }
        }
      }

      final effectiveFixedAllowance = (currentlyInProbation && !hasAllowanceDuringProbation)
          ? 0.0
          : fullFixedAllowance;
      final grossSalary = basicSalary + effectiveFixedAllowance;

      final deductEpf = !(currentlyInProbation && !hasEpfDuringProbation);

      final empEpf8 = deductEpf ? (basicSalary * 0.08) : 0.0;
      final compEpf12 = deductEpf ? (basicSalary * 0.12) : 0.0;
      final compEtf3 = deductEpf ? (basicSalary * 0.03) : 0.0;
      final netTakeHome = grossSalary - empEpf8;

      bool creditedToBank = false;
      final bankData = await _client!
          .from('bank_accounts')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (bankData != null && bankData['auto_credit_salary'] == true) {
        final existingRecords = await _client!
            .from('cash_records')
            .select()
            .eq('user_id', user.id)
            .eq('year_month', targetYearMonth)
            .eq('category', 'SALARY');

        if ((existingRecords as List).isEmpty) {
          final probationTag = currentlyInProbation
              ? (hasEpfDuringProbation ? '[Probation + EPF]' : '[Probation - EPF Exempt]')
              : '[Confirmed]';

          await _client!.from('cash_records').insert({
            'user_id': user.id,
            'account_id': bankData['id'],
            'type': 'INCOME',
            'category': 'SALARY',
            'amount': netTakeHome,
            'record_date': DateTime.now().toIso8601String(),
            'year_month': targetYearMonth,
            'notes': 'Monthly Net Salary (${activeEmp['company_name']}) $probationTag | Gross: $grossSalary | EPF(8%): $empEpf8',
            'source_employment_id': activeEmp['id'],
            'is_auto_generated': true,
          });

          final allCashRecords = await _client!
              .from('cash_records')
              .select('type, amount')
              .eq('user_id', user.id);

          double newBal = (bankData['initial_balance'] as num?)?.toDouble() ?? 0.0;
          for (final cr in allCashRecords as List) {
            final a = (cr['amount'] as num?)?.toDouble() ?? 0.0;
            final t = cr['type']?.toString().toUpperCase();
            if (t == 'INCOME') {
              newBal += a;
            } else {
              newBal -= a;
            }
          }

          await _client!
              .from('bank_accounts')
              .update({'balance': newBal, 'updated_at': DateTime.now().toIso8601String()})
              .eq('id', bankData['id']);

          creditedToBank = true;
        }
      }

      double allocatedDca = 0.0;
      final profile = await _client!
          .from('profiles')
          .select('crypto_allocation_percentage')
          .eq('id', user.id)
          .maybeSingle();

      final allocPct = (profile?['crypto_allocation_percentage'] as num?)?.toDouble() ?? 10.0;
      if (allocPct > 0) {
        final existingAlloc = await _client!
            .from('salary_allocations')
            .select()
            .eq('user_id', user.id)
            .eq('year_month', targetYearMonth)
            .maybeSingle();

        if (existingAlloc == null) {
          allocatedDca = (netTakeHome * allocPct) / 100.0;
          await _client!.from('salary_allocations').insert({
            'user_id': user.id,
            'year_month': targetYearMonth,
            'salary_amount': netTakeHome,
            'allocated_amount': allocatedDca,
            'allocation_percentage': allocPct,
            'notes': 'Auto DCA target allocation ($allocPct% of net salary)',
          });
        }
      }

      return {
        'status': 'SUCCESS',
        'message': 'Monthly salary processed successfully (Supabase Cloud)',
        'yearMonth': targetYearMonth,
        'netSalary': netTakeHome,
        'grossSalary': grossSalary,
        'employeeEpf': empEpf8,
        'employerEpf': compEpf12,
        'employerEtf': compEtf3,
        'creditedToBank': creditedToBank,
        'allocatedDca': allocatedDca,
      };
    } catch (e) {
      debugPrint('[SupabaseService] processMonthlySalaryForSupabase error: $e');
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
