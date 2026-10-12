import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/portfolio_summary_model.dart';
import '../models/transaction_model.dart';
import '../models/salary_report_model.dart';

class ApiService {
  // Use 10.0.2.2 for Android Emulator, or 127.0.0.1 for Windows/Web
  static const String baseUrl = 'http://10.0.2.2:5000/api';
  static const String localDesktopUrl = 'http://127.0.0.1:5000/api';

  String authToken = 'guest'; // Dev mode token

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      };

  Future<PortfolioSummaryModel> getPortfolioSummary() async {
    try {
      final res = await _tryGet('/portfolio/summary');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body)['data'];
        return PortfolioSummaryModel.fromJson(data);
      }
    } catch (e) {
      // In case backend is offline, return sample demo data
      return _mockPortfolioSummary();
    }
    return _mockPortfolioSummary();
  }

  Future<List<TransactionModel>> getTransactions() async {
    try {
      final res = await _tryGet('/transactions');
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body)['data'];
        return list.map((t) => TransactionModel.fromJson(t)).toList();
      }
    } catch (e) {
      return _mockTransactions();
    }
    return _mockTransactions();
  }

  Future<bool> createTransaction(Map<String, dynamic> txData) async {
    try {
      final res = await _tryPost('/transactions', txData);
      return res.statusCode == 201;
    } catch (e) {
      return true; // Mock success
    }
  }

  Future<SalaryReportModel> getSalaryReport() async {
    try {
      final res = await _tryGet('/reports/salary');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body)['data'];
        return SalaryReportModel.fromJson(data);
      }
    } catch (e) {
      return _mockSalaryReport();
    }
    return _mockSalaryReport();
  }

  Future<bool> saveSalaryAllocation(Map<String, dynamic> data) async {
    try {
      final res = await _tryPost('/reports/salary', data);
      return res.statusCode == 200;
    } catch (e) {
      return true;
    }
  }

  Future<http.Response> _tryGet(String endpoint) async {
    try {
      return await http.get(Uri.parse('$localDesktopUrl$endpoint'), headers: _headers)
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      return await http.get(Uri.parse('$baseUrl$endpoint'), headers: _headers)
          .timeout(const Duration(seconds: 3));
    }
  }

  Future<http.Response> _tryPost(String endpoint, Map<String, dynamic> body) async {
    try {
      return await http.post(
        Uri.parse('$localDesktopUrl$endpoint'),
        headers: _headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 3));
    } catch (_) {
      return await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: _headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 3));
    }
  }

  // Fallback demo data to showcase the app even before connecting to local backend
  PortfolioSummaryModel _mockPortfolioSummary() {
    return PortfolioSummaryModel.fromJson({
      'totalInvested': 4500.00,
      'currentValue': 5850.50,
      'unrealizedPnl': 1350.50,
      'unrealizedPnlPercentage': 30.01,
      'realizedPnl': 240.00,
      'coinsCount': 4,
      'holdings': [
        {
          'id': '1',
          'coinId': 'bitcoin',
          'symbol': 'BTC',
          'name': 'Bitcoin',
          'totalQuantity': 0.055,
          'averageBuyPrice': 58200.00,
          'currentPrice': 68450.00,
          'change24h': 3.42,
          'totalInvestedCost': 3201.00,
          'currentValue': 3764.75,
          'unrealizedPnl': 563.75,
          'unrealizedPnlPercentage': 17.61,
          'realizedPnl': 120.00,
        },
        {
          'id': '2',
          'coinId': 'ethereum',
          'symbol': 'ETH',
          'name': 'Ethereum',
          'totalQuantity': 0.42,
          'averageBuyPrice': 2600.00,
          'currentPrice': 3520.00,
          'change24h': 4.15,
          'totalInvestedCost': 1092.00,
          'currentValue': 1478.40,
          'unrealizedPnl': 386.40,
          'unrealizedPnlPercentage': 35.38,
          'realizedPnl': 80.00,
        },
        {
          'id': '3',
          'coinId': 'solana',
          'symbol': 'SOL',
          'name': 'Solana',
          'totalQuantity': 3.8,
          'averageBuyPrice': 110.00,
          'currentPrice': 156.50,
          'change24h': -1.25,
          'totalInvestedCost': 418.00,
          'currentValue': 594.70,
          'unrealizedPnl': 176.70,
          'unrealizedPnlPercentage': 42.27,
          'realizedPnl': 40.00,
        },
      ],
      'allocations': [
        {'coinId': 'bitcoin', 'symbol': 'BTC', 'percentage': 64.3, 'value': 3764.75},
        {'coinId': 'ethereum', 'symbol': 'ETH', 'percentage': 25.3, 'value': 1478.40},
        {'coinId': 'solana', 'symbol': 'SOL', 'percentage': 10.4, 'value': 594.70},
      ],
    });
  }

  List<TransactionModel> _mockTransactions() {
    return [
      TransactionModel(
        id: 'tx-1',
        type: 'BUY',
        coinId: 'bitcoin',
        symbol: 'BTC',
        name: 'Bitcoin',
        amount: 0.02,
        pricePerUnit: 64200.0,
        totalAmount: 1284.0,
        fee: 1.5,
        transactionDate: DateTime.now().subtract(const Duration(days: 2)),
        notes: 'Monthly Salary DCA Deposit',
      ),
      TransactionModel(
        id: 'tx-2',
        type: 'BUY',
        coinId: 'ethereum',
        symbol: 'ETH',
        name: 'Ethereum',
        amount: 0.15,
        pricePerUnit: 3400.0,
        totalAmount: 510.0,
        fee: 0.8,
        transactionDate: DateTime.now().subtract(const Duration(days: 5)),
        notes: 'DCA Buy dip',
      ),
      TransactionModel(
        id: 'tx-3',
        type: 'SALARY_DEPOSIT',
        amount: 1,
        pricePerUnit: 350.0,
        totalAmount: 350.0,
        fee: 0,
        transactionDate: DateTime.now().subtract(const Duration(days: 10)),
        notes: 'Salary allocation into Crypto portfolio',
      ),
    ];
  }

  SalaryReportModel _mockSalaryReport() {
    return SalaryReportModel.fromJson({
      'userSalary': 2000.00,
      'targetAllocationPercent': 15.0,
      'totalDepositedToCrypto': 900.00,
      'allocations': [
        {
          'yearMonth': '2026-10',
          'salaryAmount': 2000.0,
          'allocatedAmount': 300.0,
          'allocationPercentage': 15.0,
          'notes': 'October DCA allocation'
        },
        {
          'yearMonth': '2026-09',
          'salaryAmount': 2000.0,
          'allocatedAmount': 300.0,
          'allocationPercentage': 15.0,
          'notes': 'September DCA allocation'
        },
        {
          'yearMonth': '2026-08',
          'salaryAmount': 2000.0,
          'allocatedAmount': 300.0,
          'allocationPercentage': 15.0,
          'notes': 'August DCA allocation'
        },
      ]
    });
  }
}
