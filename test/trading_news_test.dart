import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/models/trading_news_model.dart';
import 'package:mobile/data/services/trading_news_service.dart';

void main() {
  group('Trading News & Market Intelligence Tests', () {
    test('TradingNewsItem auto-classifies ETF and Bullish sentiment correctly', () {
      final json = {
        'id': '101',
        'title': 'US Bitcoin Spot ETF records massive institutional inflow led by BlackRock',
        'body': 'Inflows surged today as traders expect lower interest rates.',
        'source_info': {'name': 'Tree News (X)'},
        'url': 'https://farside.co.uk',
        'published_on': 1718000000,
        'categories': 'BTC,ETF',
      };

      final item = TradingNewsItem.fromJson(json);

      expect(item.category, 'ETF');
      expect(item.sentiment, 'BULLISH');
      expect(item.source, 'Tree News (X)');
    });

    test('TradingNewsItem auto-classifies SEC regulatory action as Bearish/Regulation', () {
      final json = {
        'id': '102',
        'title': 'SEC files lawsuit against decentralized exchange alleging violations',
        'body': 'Crypto markets dump on regulatory fears.',
        'source': 'Reuters',
        'url': '',
        'published_on': 1718000000,
        'categories': 'REGULATION',
      };

      final item = TradingNewsItem.fromJson(json);

      expect(item.category, 'REGULATION');
      expect(item.sentiment, 'BEARISH');
    });

    test('TradingNewsService caches data to prevent redundant network calls and zero app lag', () async {
      final service = TradingNewsService();
      final data1 = await service.getIntelligence();
      expect(data1.macroEvents.isNotEmpty, isTrue);
      expect(data1.etfFlows.isNotEmpty, isTrue);
      expect(data1.tokenUnlocks.isNotEmpty, isTrue);

      // Immediate second call should return identical cached instance in 0ms
      final data2 = await service.getIntelligence(forceRefresh: false);
      expect(identical(data1, data2), isTrue);
    });

    test('MacroEventItem correctly calculates countdown days', () {
      final now = DateTime.now();
      final event = MacroEventItem(
        title: 'FOMC Rate Decision',
        impact: 'HIGH',
        eventDate: now.add(const Duration(days: 5)),
        forecast: '4.75%',
        previous: '5.00%',
        description: 'Rate decision',
      );

      expect(event.daysRemaining, 5);
      expect(event.isUpcoming, isTrue);
    });
  });
}
