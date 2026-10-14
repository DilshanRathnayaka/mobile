import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../../core/constants/app_backend_config.dart';
import '../models/bank_budget_model.dart';
import '../models/cashflow_model.dart';
import '../models/employment_model.dart';
import '../models/portfolio_summary_model.dart';
import '../models/salary_report_model.dart';
import '../models/transaction_model.dart';

class SpringBootUser {
  final String id;
  final String email;
  final String displayName;

  SpringBootUser({required this.id, required this.email, required this.displayName});
}

class SpringBootService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const String _keyToken = 'sb_jwt_token';
  static const String _keyUserId = 'sb_user_id';
  static const String _keyUserEmail = 'sb_user_email';
  static const String _keyUserName = 'sb_user_name';

  String? _cachedToken;
  String? _cachedUserId;
  String? _cachedEmail;
  String? _cachedDisplayName;

  String get baseUrl => AppBackendConfig.springBootBaseUrl;

  Future<void> init() async {
    try {
      _cachedToken = await _storage.read(key: _keyToken);
      _cachedUserId = await _storage.read(key: _keyUserId);
      _cachedEmail = await _storage.read(key: _keyUserEmail);
      _cachedDisplayName = await _storage.read(key: _keyUserName);
    } catch (e) {
      debugPrint('[SpringBootService] Init error: $e');
    }
  }

  bool get isAuthenticated => _cachedToken != null && _cachedToken!.isNotEmpty;

  SpringBootUser? get currentUser {
    if (!isAuthenticated || _cachedUserId == null) return null;
    return SpringBootUser(
      id: _cachedUserId!,
      email: _cachedEmail ?? '',
      displayName: _cachedDisplayName ?? '',
    );
  }

  String? get currentUserId => _cachedUserId;

  Map<String, String> get _headers {
    final map = {'Content-Type': 'application/json', 'Accept': 'application/json'};
    if (_cachedToken != null && _cachedToken!.isNotEmpty) {
      map['Authorization'] = 'Bearer $_cachedToken';
    }
    return map;
  }

  // ==========================================
  // 🔐 AUTHENTICATION (STRICT USER ISOLATION)
  // ==========================================
  Future<SpringBootUser> signUp(String email, String password, {String? displayName}) async {
    await signOut(); // Clear any previous user state immediately
    final url = Uri.parse('$baseUrl/auth/signup');
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({'email': email, 'password': password, 'displayName': displayName ?? ''}),
    );

    final body = jsonDecode(res.body);
    if (res.statusCode == 200 && body['success'] == true) {
      final data = body['data'];
      await _persistSession(data['token'], data['userId'], data['email'], data['displayName'] ?? '');
      return currentUser!;
    } else {
      throw Exception(body['message'] ?? 'Signup failed with status ${res.statusCode}');
    }
  }

  Future<SpringBootUser> signIn(String email, String password) async {
    await signOut(); // Clear any previous user state immediately
    final url = Uri.parse('$baseUrl/auth/login');
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    final body = jsonDecode(res.body);
    if (res.statusCode == 200 && body['success'] == true) {
      final data = body['data'];
      await _persistSession(data['token'], data['userId'], data['email'], data['displayName'] ?? '');
      return currentUser!;
    } else {
      throw Exception(body['message'] ?? 'Login failed with status ${res.statusCode}');
    }
  }

  Future<void> signOut() async {
    _cachedToken = null;
    _cachedUserId = null;
    _cachedEmail = null;
    _cachedDisplayName = null;
    await _storage.delete(key: _keyToken);
    await _storage.delete(key: _keyUserId);
    await _storage.delete(key: _keyUserEmail);
    await _storage.delete(key: _keyUserName);
  }

  Future<void> _persistSession(String token, String userId, String email, String name) async {
    _cachedToken = token;
    _cachedUserId = userId;
    _cachedEmail = email;
    _cachedDisplayName = name;
    await _storage.write(key: _keyToken, value: token);
    await _storage.write(key: _keyUserId, value: userId);
    await _storage.write(key: _keyUserEmail, value: email);
    await _storage.write(key: _keyUserName, value: name);
  }

  // ==========================================
  // 📊 PORTFOLIO & HOLDINGS
  // ==========================================
  Future<PortfolioSummaryModel> getPortfolioSummary() async {
    final url = Uri.parse('$baseUrl/portfolio/summary');
    final res = await http.get(url, headers: _headers);

    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      if (body['success'] == true && body['data'] != null) {
        return PortfolioSummaryModel.fromJson(body['data']);
      }
    }
    return PortfolioSummaryModel.empty();
  }

  // ==========================================
  // 💸 TRANSACTIONS
  // ==========================================
  Future<List<TransactionModel>> getTransactions() async {
    final url = Uri.parse('$baseUrl/transactions');
    final res = await http.get(url, headers: _headers);

    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      if (body['success'] == true && body['data'] is List) {
        final list = body['data'] as List;
        return list.map((item) => _mapTransaction(item)).toList();
      }
    }
    return [];
  }

  Future<bool> addTransaction(TransactionModel tx) async {
    final url = Uri.parse('$baseUrl/transactions');
    final payload = {
      'id': tx.id,
      'type': tx.type,
      'coinId': tx.coinId,
      'symbol': tx.symbol,
      'name': tx.name,
      'amount': tx.amount,
      'pricePerUnit': tx.pricePerUnit,
      'totalAmount': tx.totalAmount,
      'fee': tx.fee,
      'originalCurrency': tx.originalCurrency,
      'originalAmount': tx.originalAmount,
      'fxToBase': tx.fxToBase,
      'transactionDate': tx.transactionDate.toIso8601String(),
      'notes': tx.notes,
      'leverage': tx.leverage,
      'margin': tx.margin,
      'liquidationPrice': tx.liquidationPrice,
    };

    final res = await http.post(url, headers: _headers, body: jsonEncode(payload));
    return res.statusCode == 200;
  }

  Future<bool> deleteTransaction(String id) async {
    final url = Uri.parse('$baseUrl/transactions/$id');
    final res = await http.delete(url, headers: _headers);
    return res.statusCode == 200;
  }

  // ==========================================
  // 🏦 BANK ACCOUNTS & BUDGET (SINGLE SOURCE OF TRUTH)
  // ==========================================
  Future<BankAccountModel?> getBankAccount() async {
    final url = Uri.parse('$baseUrl/bank/account');
    try {
      final res = await http.get(url, headers: _headers);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['data'] != null) {
          return _mapBankAccount(body['data']);
        }
      }
    } catch (e) {
      debugPrint('[SpringBootService] getBankAccount error: $e');
    }
    return null;
  }

  Future<List<BankAccountModel>> getBankAccounts() async {
    final url = Uri.parse('$baseUrl/bank/accounts');
    try {
      final res = await http.get(url, headers: _headers);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['data'] is List) {
          final list = body['data'] as List;
          return list.map((item) => _mapBankAccount(item)).toList();
        }
      }
    } catch (e) {
      debugPrint('[SpringBootService] getBankAccounts error: $e');
    }
    return [];
  }

  Future<BankAccountModel?> upsertBankAccount(BankAccountModel account) async {
    final url = Uri.parse('$baseUrl/bank/account');
    final payload = {
      'id': account.id.isNotEmpty ? account.id : null,
      'name': account.bankName,
      'accountNumber': account.accountNumber,
      'initialBalance': account.initialBalance,
      'currency': account.currency,
      'institution': account.bankName,
      'autoCreditSalary': account.autoCreditSalary,
      'salaryStartMonth': account.salaryStartMonth,
      'notes': account.notes,
    };
    try {
      final res = await http.post(url, headers: _headers, body: jsonEncode(payload));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['data'] != null) {
          return _mapBankAccount(body['data']);
        }
      }
    } catch (e) {
      debugPrint('[SpringBootService] upsertBankAccount error: $e');
    }
    return null;
  }

  Future<List<CashRecordModel>> getCashRecords({String? yearMonth}) async {
    final uri = yearMonth != null && yearMonth.isNotEmpty
        ? Uri.parse('$baseUrl/cash/records?yearMonth=$yearMonth')
        : Uri.parse('$baseUrl/cash/records');
    try {
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['data'] is List) {
          final list = body['data'] as List;
          return list.map((item) => _mapCashRecord(item)).toList();
        }
      }
    } catch (e) {
      debugPrint('[SpringBootService] getCashRecords error: $e');
    }
    return [];
  }

  Future<CashRecordModel?> addCashRecord(CashRecordModel record) async {
    final url = Uri.parse('$baseUrl/cash/records');
    final payload = {
      'id': record.id.isNotEmpty ? record.id : null,
      'type': record.type,
      'amount': record.amount,
      'category': record.category,
      'recordDate': record.recordDate.toIso8601String(),
      'yearMonth': record.yearMonth,
      'sourceEmploymentId': record.sourceEmploymentId,
      'isAutoGenerated': record.isAutoGenerated,
      'notes': record.notes,
    };
    try {
      final res = await http.post(url, headers: _headers, body: jsonEncode(payload));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['data'] != null) {
          return _mapCashRecord(body['data']);
        }
      }
    } catch (e) {
      debugPrint('[SpringBootService] addCashRecord error: $e');
    }
    return null;
  }

  Future<bool> deleteCashRecord(String id) async {
    final url = Uri.parse('$baseUrl/cash/records/$id');
    try {
      final res = await http.delete(url, headers: _headers);
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[SpringBootService] deleteCashRecord error: $e');
      return false;
    }
  }

  Future<MonthlyBudgetPlanModel?> getBudgetPlan() async {
    final url = Uri.parse('$baseUrl/budget/plan');
    try {
      final res = await http.get(url, headers: _headers);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['data'] != null) {
          return _mapBudgetPlan(body['data']);
        }
      }
    } catch (e) {
      debugPrint('[SpringBootService] getBudgetPlan error: $e');
    }
    return null;
  }

  Future<MonthlyBudgetPlanModel?> upsertBudgetPlan(MonthlyBudgetPlanModel plan) async {
    final url = Uri.parse('$baseUrl/budget/plan');
    final payload = {
      'savingsPercentage': plan.savingsPercentage,
      'cryptoPercentage': plan.cryptoPercentage,
      'otherInvestPercentage': plan.otherInvestPercentage,
      'expensesPercentage': plan.expensesPercentage,
      'emergencyFundTarget': plan.emergencyFundTarget,
      'notes': plan.notes,
    };
    try {
      final res = await http.post(url, headers: _headers, body: jsonEncode(payload));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['data'] != null) {
          return _mapBudgetPlan(body['data']);
        }
      }
    } catch (e) {
      debugPrint('[SpringBootService] upsertBudgetPlan error: $e');
    }
    return null;
  }

  Future<List<CashflowItem>> getCashflowRecords() async {
    try {
      final txs = await getTransactions();
      final items = <CashflowItem>[];
      for (final t in txs) {
        final upper = t.type.toUpperCase();
        final isDep = upper == 'DEPOSIT' || upper == 'SALARY_DEPOSIT';
        final isWd = upper == 'WITHDRAWAL';
        if (isDep || isWd) {
          final isP2P = t.notes.toUpperCase().contains('[P2P]') ||
              (t.name?.toUpperCase().contains('P2P') ?? false) ||
              t.fxToBase > 1.0 ||
              (t.originalAmount != null && t.originalAmount! > 0);
          final rate = t.fxToBase > 1.0 ? t.fxToBase : (t.pricePerUnit > 1.0 ? t.pricePerUnit : null);
          items.add(CashflowItem(
            id: t.id,
            type: isWd ? 'WITHDRAWAL' : 'DEPOSIT',
            amount: t.amount,
            category: t.name ?? (isWd ? 'Withdrawal' : 'Deposit'),
            date: t.transactionDate,
            notes: t.notes.replaceAll('[WITHDRAWAL]', '').trim(),
            isP2P: isP2P,
            p2pRate: rate,
            localCurrency: t.originalCurrency,
            localAmount: t.originalAmount,
          ));
        }
      }
      if (items.isNotEmpty) return items;

      // Fallback to cash records if no transactions found
      final records = await getCashRecords();
      return records
          .where((r) => r.type == 'INCOME' || r.type == 'EXPENSE')
          .map((r) => CashflowItem(
                id: r.id,
                type: r.type == 'INCOME' ? 'DEPOSIT' : 'WITHDRAWAL',
                amount: r.amount,
                category: r.category,
                date: r.recordDate,
                notes: r.notes,
              ))
          .toList();
    } catch (e) {
      debugPrint('[SpringBootService] getCashflowRecords error: $e');
      return [];
    }
  }

  Future<CashflowItem?> addCashflowRecord({
    required String type,
    required double amount,
    String category = 'Deposit',
    required DateTime date,
    String? notes,
    bool isP2P = false,
    double? p2pRate,
    String? localCurrency,
    double? localAmount,
  }) async {
    final id = const Uuid().v4();
    final rate = p2pRate ?? 1.0;
    final curr = (localCurrency != null && localCurrency.isNotEmpty) ? localCurrency : 'LKR';
    final calcLocal = localAmount ?? (amount * rate);
    final prefix = isP2P ? '[P2P] ' : '';
    final rawNotes = notes ?? '';
    final finalNotes = (isP2P && !rawNotes.toUpperCase().contains('[P2P]'))
        ? '$prefix$rawNotes'.trim()
        : rawNotes;

    final tx = TransactionModel(
      id: id,
      type: type,
      symbol: 'USDT',
      coinId: null,
      name: category,
      amount: amount,
      pricePerUnit: rate,
      totalAmount: amount,
      fee: 0.0,
      transactionDate: date,
      notes: finalNotes,
      originalCurrency: curr,
      originalAmount: calcLocal,
      fxToBase: rate,
    );

    final ok = await addTransaction(tx);
    if (ok) {
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
    }
    return null;
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
    await deleteTransaction(id);
    final created = await addCashflowRecord(
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
    return created != null;
  }

  Future<bool> deleteCashflowRecord(String id) async {
    final ok = await deleteTransaction(id);
    if (!ok) {
      return await deleteCashRecord(id);
    }
    return true;
  }

  // ==========================================
  // 💼 EMPLOYMENT & SALARY
  // ==========================================
  Future<List<EmploymentModel>> getEmployments() async {
    final url = Uri.parse('$baseUrl/employment');
    final res = await http.get(url, headers: _headers);

    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      if (body['success'] == true && body['data'] is List) {
        final list = body['data'] as List;
        return list.map((item) => EmploymentModel.fromJson(item)).toList();
      }
    }
    return [];
  }

  Future<bool> createEmployment(EmploymentModel emp) async {
    final url = Uri.parse('$baseUrl/employment');
    final payload = {
      'id': emp.id,
      'companyName': emp.companyName,
      'designation': emp.designation,
      'basicSalary': emp.basicSalary,
      'fixedAllowance': emp.fixedAllowance,
      'monthlySalary': emp.monthlySalary,
      'active': emp.isCurrent,
      'startDate': emp.startDate.toIso8601String().substring(0, 10),
      'endDate': emp.endDate?.toIso8601String().substring(0, 10),
      'isProbation': emp.isProbation,
      'probationMonths': emp.probationMonths,
      'probationEndDate': emp.probationEndDate?.toIso8601String().substring(0, 10),
      'hasEpfEtfDuringProbation': emp.hasEpfEtfDuringProbation,
      'hasFixedAllowanceDuringProbation': emp.hasFixedAllowanceDuringProbation,
      'promotionsJson': jsonEncode(emp.promotions.map((p) => p.toJson()).toList()),
    };
    final res = await http.post(url, headers: _headers, body: jsonEncode(payload));
    return res.statusCode == 200;
  }

  Future<Map<String, dynamic>?> triggerMonthlySalaryProcessing({String? yearMonth}) async {
    final ymParam = yearMonth != null ? '?yearMonth=$yearMonth' : '';
    final url = Uri.parse('$baseUrl/salary/process-monthly$ymParam');
    try {
      final res = await http.post(url, headers: _headers);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['data'] is Map<String, dynamic>) {
          return body['data'] as Map<String, dynamic>;
        }
      }
    } catch (e) {
      debugPrint('[SpringBootService] triggerMonthlySalaryProcessing error: $e');
    }
    return null;
  }

  Future<SalaryReportModel> getSalaryReport() async {
    final url = Uri.parse('$baseUrl/salary/report');
    final res = await http.get(url, headers: _headers);

    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      if (body['success'] == true && body['data'] != null) {
        return SalaryReportModel.fromJson(body['data']);
      }
    }
    return SalaryReportModel(userSalary: 0, targetAllocationPercent: 10, totalDepositedToCrypto: 0, allocations: []);
  }

  Future<bool> saveSalaryAllocation(Map<String, dynamic> data) async {
    final url = Uri.parse('$baseUrl/salary/allocations');
    final res = await http.post(url, headers: _headers, body: jsonEncode(data));
    return res.statusCode == 200;
  }

  Future<bool> deleteSalaryAllocation(String yearMonth) async {
    final url = Uri.parse('$baseUrl/salary/allocations/$yearMonth');
    try {
      final res = await http.delete(url, headers: _headers);
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[SpringBootService] deleteSalaryAllocation error: $e');
      return false;
    }
  }

  Future<bool> deleteEmployment(String id) async {
    final url = Uri.parse('$baseUrl/employment/$id');
    try {
      final res = await http.delete(url, headers: _headers);
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[SpringBootService] deleteEmployment error: $e');
      return false;
    }
  }

  TransactionModel _mapTransaction(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'BUY',
      coinId: json['coinId']?.toString(),
      symbol: json['symbol']?.toString(),
      name: json['name']?.toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      pricePerUnit: (json['pricePerUnit'] as num?)?.toDouble() ?? 1.0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      fee: (json['fee'] as num?)?.toDouble() ?? 0.0,
      originalCurrency: json['originalCurrency']?.toString() ?? 'USD',
      originalAmount: (json['originalAmount'] as num?)?.toDouble(),
      fxToBase: (json['fxToBase'] as num?)?.toDouble() ?? 1.0,
      transactionDate: json['transactionDate'] != null ? DateTime.parse(json['transactionDate'].toString()) : DateTime.now(),
      notes: json['notes']?.toString() ?? '',
      leverage: (json['leverage'] as num?)?.toDouble() ?? 1.0,
      margin: (json['margin'] as num?)?.toDouble(),
      liquidationPrice: (json['liquidationPrice'] as num?)?.toDouble() ?? (json['liquidation_price'] as num?)?.toDouble(),
    );
  }

  BankAccountModel _mapBankAccount(Map<String, dynamic> json) {
    return BankAccountModel(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? json['user_id']?.toString() ?? '',
      bankName: json['name']?.toString() ?? json['bank_name']?.toString() ?? 'Bank',
      accountNumber: json['accountNumber']?.toString() ?? json['account_number']?.toString() ?? '',
      initialBalance: (json['initialBalance'] as num?)?.toDouble() ?? (json['initial_balance'] as num?)?.toDouble() ?? (json['balance'] as num?)?.toDouble() ?? 0.0,
      initialBalanceDate: json['initialBalanceDate'] != null
          ? DateTime.tryParse(json['initialBalanceDate'].toString()) ?? DateTime.now()
          : (json['initial_balance_date'] != null
              ? DateTime.tryParse(json['initial_balance_date'].toString()) ?? DateTime.now()
              : DateTime.now()),
      currency: json['currency']?.toString() ?? 'LKR',
      autoCreditSalary: json['autoCreditSalary'] as bool? ?? json['auto_credit_salary'] as bool? ?? true,
      salaryStartMonth: json['salaryStartMonth']?.toString() ?? json['salary_start_month']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
    );
  }

  CashRecordModel _mapCashRecord(Map<String, dynamic> json) {
    return CashRecordModel(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? json['user_id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'EXPENSE',
      category: json['category']?.toString() ?? 'GENERAL',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      recordDate: json['recordDate'] != null
          ? DateTime.tryParse(json['recordDate'].toString()) ?? DateTime.now()
          : (json['record_date'] != null
              ? DateTime.tryParse(json['record_date'].toString()) ?? DateTime.now()
              : DateTime.now()),
      yearMonth: json['yearMonth']?.toString() ?? json['year_month']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      sourceEmploymentId: json['sourceEmploymentId']?.toString() ?? json['source_employment_id']?.toString(),
      isAutoGenerated: json['isAutoGenerated'] as bool? ?? json['is_auto_generated'] as bool? ?? false,
    );
  }

  MonthlyBudgetPlanModel _mapBudgetPlan(Map<String, dynamic> json) {
    return MonthlyBudgetPlanModel(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? json['user_id']?.toString() ?? '',
      savingsPercentage: (json['savingsPercentage'] as num?)?.toDouble() ?? (json['savings_percentage'] as num?)?.toDouble() ?? 20.0,
      cryptoPercentage: (json['cryptoPercentage'] as num?)?.toDouble() ?? (json['crypto_percentage'] as num?)?.toDouble() ?? 20.0,
      otherInvestPercentage: (json['otherInvestPercentage'] as num?)?.toDouble() ?? (json['other_invest_percentage'] as num?)?.toDouble() ?? 10.0,
      expensesPercentage: (json['expensesPercentage'] as num?)?.toDouble() ?? (json['expenses_percentage'] as num?)?.toDouble() ?? 50.0,
      emergencyFundTarget: (json['emergencyFundTarget'] as num?)?.toDouble() ?? (json['emergency_fund_target'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes']?.toString() ?? '',
    );
  }
}
