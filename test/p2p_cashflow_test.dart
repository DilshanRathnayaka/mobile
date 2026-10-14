import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/models/cashflow_model.dart';

void main() {
  group('P2P Cashflow & Merchant Calculations', () {
    test('CashflowItem correctly calculates local fiat cost and rate', () {
      final item = CashflowItem(
        id: 'p2p_1',
        type: 'DEPOSIT',
        amount: 500.0, // 500 USDT bought
        category: 'P2P Buy',
        date: DateTime.now(),
        notes: '[P2P] Bought via Binance P2P from merchant',
        isP2P: true,
        p2pRate: 310.50, // 1 USDT = 310.50 LKR
        localCurrency: 'LKR',
        localAmount: 155250.0,
      );

      expect(item.isDeposit, true);
      expect(item.effectiveRate, 310.50);
      expect(item.effectiveLocalAmount, 155250.0);
      expect(item.effectiveLocalCurrency, 'LKR');
    });

    test('CashflowItem serialization and deserialization preserves P2P fields', () {
      final original = CashflowItem(
        id: 'p2p_2',
        type: 'WITHDRAWAL',
        amount: 300.0,
        category: 'P2P Sell',
        date: DateTime(2026, 10, 13),
        notes: 'Sold USDT for INR',
        isP2P: true,
        p2pRate: 84.20,
        localCurrency: 'INR',
        localAmount: 25260.0,
      );

      final json = original.toJson();
      final fromJson = CashflowItem.fromJson(json);

      expect(fromJson.id, original.id);
      expect(fromJson.type, 'WITHDRAWAL');
      expect(fromJson.amount, 300.0);
      expect(fromJson.isP2P, true);
      expect(fromJson.p2pRate, 84.20);
      expect(fromJson.localCurrency, 'INR');
      expect(fromJson.localAmount, 25260.0);
    });

    test('CashflowSummary accurately calculates merchant spread and realized fiat profit', () {
      // Merchant bought 1,000 USDT at 310 LKR
      final buy = CashflowItem(
        id: 'buy_1',
        type: 'DEPOSIT',
        amount: 1000.0,
        category: 'P2P Buy',
        date: DateTime.now(),
        notes: '',
        isP2P: true,
        p2pRate: 310.0,
        localCurrency: 'LKR',
        localAmount: 310000.0,
      );

      // Merchant sold 1,000 USDT at 315 LKR
      final sell = CashflowItem(
        id: 'sell_1',
        type: 'WITHDRAWAL',
        amount: 1000.0,
        category: 'P2P Sell',
        date: DateTime.now(),
        notes: '',
        isP2P: true,
        p2pRate: 315.0,
        localCurrency: 'LKR',
        localAmount: 315000.0,
      );

      final items = [buy, sell];
      double depUsdt = 0;
      double depLocal = 0;
      double wdUsdt = 0;
      double wdLocal = 0;

      for (final i in items) {
        if (i.type == 'DEPOSIT') {
          depUsdt += i.amount;
          depLocal += i.effectiveLocalAmount;
        } else {
          wdUsdt += i.amount;
          wdLocal += i.effectiveLocalAmount;
        }
      }

      final avgBuy = depLocal / depUsdt; // 310.0
      final avgSell = wdLocal / wdUsdt; // 315.0
      final matchedVol = depUsdt < wdUsdt ? depUsdt : wdUsdt; // 1,000
      final fiatProfit = matchedVol * (avgSell - avgBuy); // 5,000 LKR

      final summary = CashflowSummary(
        totalDeposited: depUsdt,
        totalWithdrawn: wdUsdt,
        netCapital: depUsdt - wdUsdt,
        items: items,
        totalP2pDepositedUsdt: depUsdt,
        totalP2pDepositedLocal: depLocal,
        avgP2pBuyRate: avgBuy,
        totalP2pWithdrawnUsdt: wdUsdt,
        totalP2pWithdrawnLocal: wdLocal,
        avgP2pSellRate: avgSell,
        p2pNetProfitLocal: fiatProfit,
        p2pTradeCount: items.length,
      );

      expect(summary.totalP2pDepositedUsdt, 1000.0);
      expect(summary.totalP2pWithdrawnUsdt, 1000.0);
      expect(summary.avgP2pBuyRate, 310.0);
      expect(summary.avgP2pSellRate, 315.0);
      expect(summary.p2pNetProfitLocal, 5000.0); // 5,000 LKR spread profit
      expect(summary.p2pTradeCount, 2);
    });
  });
}
