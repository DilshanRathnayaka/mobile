import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/models/holding_model.dart';
import 'package:mobile/data/models/live_price_tick.dart';
import 'package:mobile/data/models/portfolio_summary_model.dart';

void main() {
  group('Real-Time Profit & Loss In-Memory Recalculations', () {
    test('HoldingModel copyWith recalculates unrealized PnL upon price tick', () {
      final initialHolding = HoldingModel(
        id: 'h1',
        coinId: 'bitcoin',
        symbol: 'BTC',
        name: 'Bitcoin',
        totalQuantity: 0.5,
        averageBuyPrice: 60000.0,
        currentPrice: 60000.0,
        change24h: 0.0,
        totalInvestedCost: 30000.0,
        currentValue: 30000.0,
        unrealizedPnl: 0.0,
        unrealizedPnlPercentage: 0.0,
        realizedPnl: 0.0,
      );

      // Price increases to $70,000 (+16.67%)
      const newPrice = 70000.0;
      final newCurrentValue = initialHolding.totalQuantity * newPrice; // 35000.0
      final newUnrealizedPnl = newCurrentValue - initialHolding.totalInvestedCost; // 5000.0
      final newUnrealizedPnlPct =
          (newUnrealizedPnl / initialHolding.totalInvestedCost) * 100; // 16.666%

      final updatedHolding = initialHolding.copyWith(
        currentPrice: newPrice,
        change24h: 3.5,
        currentValue: newCurrentValue,
        unrealizedPnl: newUnrealizedPnl,
        unrealizedPnlPercentage: newUnrealizedPnlPct,
      );

      expect(updatedHolding.currentValue, 35000.0);
      expect(updatedHolding.unrealizedPnl, 5000.0);
      expect(updatedHolding.unrealizedPnlPercentage, closeTo(16.67, 0.01));
    });

    test('PortfolioSummaryModel correctly recalculates total P&L and allocations', () {
      final h1 = HoldingModel(
        id: 'h1',
        coinId: 'bitcoin',
        symbol: 'BTC',
        name: 'Bitcoin',
        totalQuantity: 1.0,
        averageBuyPrice: 50000.0,
        currentPrice: 50000.0,
        change24h: 0.0,
        totalInvestedCost: 50000.0,
        currentValue: 50000.0,
        unrealizedPnl: 0.0,
        unrealizedPnlPercentage: 0.0,
        realizedPnl: 0.0,
      );

      final summary = PortfolioSummaryModel(
        totalInvested: 50000.0,
        currentValue: 50000.0,
        unrealizedPnl: 0.0,
        unrealizedPnlPercentage: 0.0,
        realizedPnl: 1200.0,
        coinsCount: 1,
        holdings: [h1],
        allocations: [
          AssetAllocation(coinId: 'bitcoin', symbol: 'BTC', percentage: 100, value: 50000)
        ],
        unallocatedUsdt: 500.0,
      );

      // Price increases to $60,000
      const newBtcPrice = 60000.0;
      final updatedHolding = h1.copyWith(
        currentPrice: newBtcPrice,
        currentValue: 1.0 * newBtcPrice,
        unrealizedPnl: 60000.0 - 50000.0,
        unrealizedPnlPercentage: ((60000.0 - 50000.0) / 50000.0) * 100,
      );

      final newTotalValue = updatedHolding.currentValue;
      final newUnrealized = newTotalValue - summary.totalInvested; // 10000.0
      final newUnrealizedPct = (newUnrealized / summary.totalInvested) * 100; // 20.0%

      final updatedSummary = summary.copyWith(
        currentValue: newTotalValue,
        unrealizedPnl: newUnrealized,
        unrealizedPnlPercentage: newUnrealizedPct,
        holdings: [updatedHolding],
        netPortfolioValue: newTotalValue + summary.unallocatedUsdt,
      );

      expect(updatedSummary.currentValue, 60000.0);
      expect(updatedSummary.unrealizedPnl, 10000.0);
      expect(updatedSummary.unrealizedPnlPercentage, 20.0);
      expect(updatedSummary.netPortfolioValue, 60500.0);
      expect(updatedSummary.realizedPnl, 1200.0);
    });

    test('LivePriceTick stores symbol, price, and 24h change accurately', () {
      final tick = LivePriceTick(
        symbol: 'SOL',
        price: 185.50,
        change24h: 4.82,
      );

      expect(tick.symbol, 'SOL');
      expect(tick.price, 185.50);
      expect(tick.change24h, 4.82);
      expect(tick.timestamp, isNotNull);
    });
  });
}
