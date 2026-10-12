import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/utils/export_service.dart';
import 'package:mobile/data/models/transaction_model.dart';
import 'package:mobile/providers/currency_provider.dart';

void main() {
  group('ExportService Tests', () {
    final sampleTx = TransactionModel(
      id: 'tx-12345',
      type: 'BUY',
      coinId: 'bitcoin',
      symbol: 'BTC',
      name: 'Bitcoin',
      amount: 0.05,
      pricePerUnit: 65000.0,
      totalAmount: 3250.0,
      fee: 3.25,
      transactionDate: DateTime.parse('2026-10-10T12:00:00Z'),
      notes: 'Initial test buy',
      originalCurrency: 'USD',
      originalAmount: 0.05,
      fxToBase: 1.0,
    );

    final dangerousTx = TransactionModel(
      id: 'tx-malicious',
      type: 'SELL',
      coinId: 'solana',
      symbol: 'SOL',
      name: '=cmd|’ /C calc’!A0', // Excel injection attempt
      amount: 10.0,
      pricePerUnit: 150.0,
      totalAmount: 1500.0,
      fee: 1.5,
      transactionDate: DateTime.parse('2026-10-10T13:00:00Z'),
      notes: '+SUM(A1:A10), with "quotes" and, commas',
      originalCurrency: 'LKR',
      originalAmount: 10.0,
      fxToBase: 0.0033,
    );

    test('generateCsvStatement creates valid CSV header and records', () {
      final currency = SupportedCurrencies.usd;
      final csv = ExportService.generateCsvStatement([sampleTx], currency);

      expect(csv, contains('Transaction ID,Date,Type,Symbol,Asset Name,Units,Price (USD),Gross Total (USD),Fee (USD),Original Currency,Original Amount,FX Rate to USD,Notes'));
      expect(csv, contains('tx-12345'));
      expect(csv, contains('BTC'));
      expect(csv, contains('Bitcoin'));
      expect(csv, contains('0.05'));
      expect(csv, contains('65000'));
    });

    test('generateCsvStatement sanitizes formula injection attempts', () {
      final currency = SupportedCurrencies.usd;
      final csv = ExportService.generateCsvStatement([dangerousTx], currency);

      // Names starting with '=' must have prepended single quote "'"
      expect(csv, contains("'=cmd|’ /C calc’!A0"));
      // Notes starting with '+' must have prepended single quote "'"
      expect(csv, contains("'+SUM(A1:A10)"));
      // Quotes inside cells must be doubled according to RFC-4180
      expect(csv, contains('""quotes""'));
    });

    test('generateJsonBackup creates valid parseable JSON with schema version 2', () {
      final jsonStr = ExportService.generateJsonBackup(
        transactions: [sampleTx, dangerousTx],
        currencyCode: 'USD',
      );
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;

      expect(decoded['version'], equals('1.0.0'));
      expect(decoded['schema_version'], equals(2));
      expect(decoded['transactions_count'], equals(2));
      expect(decoded['transactions'], isA<List>());
      expect((decoded['transactions'] as List).length, equals(2));
    });
  });
}
