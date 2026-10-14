import 'package:flutter/foundation.dart';

class TradingNewsItem {
  final String id;
  final String title;
  final String body;
  final String source;
  final String url;
  final DateTime publishedAt;
  final String category; // 'ALL', 'FAST_WIRE', 'MACRO', 'ETF', 'REGULATION', 'UNLOCK'
  final String sentiment; // 'BULLISH', 'BEARISH', 'NEUTRAL'
  final bool isBreaking;

  TradingNewsItem({
    required this.id,
    required this.title,
    required this.body,
    required this.source,
    required this.url,
    required this.publishedAt,
    this.category = 'ALL',
    this.sentiment = 'NEUTRAL',
    this.isBreaking = false,
  });

  factory TradingNewsItem.fromJson(Map<String, dynamic> json) {
    final title = (json['title'] ?? '').toString().trim();
    final body = (json['body'] ?? '').toString().trim();
    final categories = (json['categories'] ?? '').toString().toUpperCase();

    String sourceName = 'Crypto Wire';
    final sourceInfo = json['source_info'];
    if (sourceInfo is Map && sourceInfo['name'] != null && sourceInfo['name'].toString().trim().isNotEmpty) {
      sourceName = sourceInfo['name'].toString().trim();
    } else if (json['source'] != null && json['source'].toString().trim().isNotEmpty) {
      sourceName = json['source'].toString().trim();
    }

    int pubSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final pubOn = json['published_on'];
    if (pubOn is num) {
      pubSec = pubOn.toInt();
    } else if (pubOn is String) {
      pubSec = int.tryParse(pubOn) ?? pubSec;
    }
    final pubDate = DateTime.fromMillisecondsSinceEpoch(pubSec * 1000);

    // Auto-classify category and sentiment for crypto trading relevance
    String cat = 'FAST_WIRE';
    final lowerTitle = title.toLowerCase();
    final lowerBody = body.toLowerCase();
    final combined = '$lowerTitle $lowerBody $categories';

    if (combined.contains('etf') || combined.contains('blackrock') || combined.contains('fidelity') || combined.contains('inflow') || combined.contains('outflow')) {
      cat = 'ETF';
    } else if (combined.contains('fed') || combined.contains('cpi') || combined.contains('inflation') || combined.contains('rate cut') || combined.contains('rate hike') || combined.contains('fomc') || combined.contains('powell')) {
      cat = 'MACRO';
    } else if (combined.contains('sec') || combined.contains('gensler') || combined.contains('lawsuit') || combined.contains('regulation') || combined.contains('ban') || combined.contains('court')) {
      cat = 'REGULATION';
    } else if (combined.contains('unlock') || combined.contains('vesting') || combined.contains('cliff')) {
      cat = 'UNLOCK';
    }

    // Determine Sentiment
    String sent = 'NEUTRAL';
    if (combined.contains('surge') || combined.contains('soar') || combined.contains('rally') || combined.contains('inflow') || combined.contains('approved') || combined.contains('rate cut') || combined.contains('ath') || combined.contains('bull') || combined.contains('breakout')) {
      sent = 'BULLISH';
    } else if (combined.contains('crash') || combined.contains('dump') || combined.contains('plunge') || combined.contains('hack') || combined.contains('exploit') || combined.contains('lawsuit') || combined.contains('outflow') || combined.contains('liquidat') || combined.contains('bear') || combined.contains('ban')) {
      sent = 'BEARISH';
    }

    final isBrk = lowerTitle.contains('breaking') || lowerTitle.contains('just in') || lowerTitle.contains('alert');

    return TradingNewsItem(
      id: (json['id'] ?? UniqueKey().toString()).toString(),
      title: title.isNotEmpty ? title : 'Market Update',
      body: body,
      source: sourceName,
      url: (json['url'] ?? '').toString(),
      publishedAt: pubDate,
      category: cat,
      sentiment: sent,
      isBreaking: isBrk,
    );
  }
}

class MacroEventItem {
  final String title;
  final String impact; // 'HIGH', 'MEDIUM', 'LOW'
  final DateTime eventDate;
  final String forecast;
  final String previous;
  final String description;
  final String folderColor; // 'RED', 'ORANGE', 'YELLOW' (Forex Factory format)
  final String currency; // 'USD'
  final String timeString; // '18:00 (8:30 AM EST)'
  final String country; // '🇺🇸 US'

  const MacroEventItem({
    required this.title,
    required this.impact,
    required this.eventDate,
    required this.forecast,
    required this.previous,
    required this.description,
    this.folderColor = 'RED',
    this.currency = 'USD',
    this.timeString = '18:00 (8:30 AM EST)',
    this.country = '🇺🇸 US',
  });

  int get daysRemaining {
    final diff = eventDate.difference(DateTime.now());
    final days = (diff.inHours / 24).round();
    return days < 0 ? 0 : days;
  }

  int get hoursRemaining {
    final diff = eventDate.difference(DateTime.now());
    return diff.inHours;
  }

  String get countdownLabel {
    final diff = eventDate.difference(DateTime.now());
    if (diff.isNegative) {
      if (diff.inHours.abs() < 12) return 'JUST RELEASED';
      return 'PAST';
    }
    if (diff.inHours < 24) {
      return diff.inHours <= 1 ? 'IN ${diff.inMinutes}M' : 'TOMORROW (IN ${diff.inHours}H)';
    }
    return '${daysRemaining}d left';
  }

  bool get isUpcoming => eventDate.isAfter(DateTime.now().subtract(const Duration(hours: 12)));
}

class EtfFlowSnapshot {
  final String asset; // 'BTC' or 'ETH'
  final double netFlowMillions; // e.g. +245.8 or -84.2
  final String statusText;
  final String topContributor;
  final DateTime lastUpdated;

  const EtfFlowSnapshot({
    required this.asset,
    required this.netFlowMillions,
    required this.statusText,
    required this.topContributor,
    required this.lastUpdated,
  });

  bool get isPositive => netFlowMillions >= 0;
}

class MarketNetFlowSummary {
  final double btcEtfDailyMillions; // +384.2
  final double btcEtf7DayMillions; // +1480.0
  final double ethEtfDailyMillions; // +48.6
  final double ethEtf7DayMillions; // +162.0
  final double btcExchangeNetFlowCoins; // -14850 BTC (Outflow from CEX = Bullish accumulation)
  final double ethExchangeNetFlowCoins; // -42200 ETH (Outflow = Staking lockup)
  final double stablecoinNetInflowMillions; // +580.0M (Positive = Fresh fiat dry powder on exchanges)
  final List<EtfFlowSnapshot> etfBreakdowns;

  const MarketNetFlowSummary({
    required this.btcEtfDailyMillions,
    required this.btcEtf7DayMillions,
    required this.ethEtfDailyMillions,
    required this.ethEtf7DayMillions,
    required this.btcExchangeNetFlowCoins,
    required this.ethExchangeNetFlowCoins,
    required this.stablecoinNetInflowMillions,
    required this.etfBreakdowns,
  });
}

class AssetScenarioPrediction {
  final String asset; // 'BTC', 'ETH', 'SOL'
  final String bias; // 'STRONG BULLISH', 'BULLISH', 'BEARISH PULLBACK', 'HIGH BETA DROP', 'CHOPPY'
  final String expectedMove; // '+5.5% to +8.5%'
  final String priceTarget; // '$71,800 - $74,500'
  final String keyDriver;
  final String tacticalPlay;

  const AssetScenarioPrediction({
    required this.asset,
    required this.bias,
    required this.expectedMove,
    required this.priceTarget,
    required this.keyDriver,
    required this.tacticalPlay,
  });

  bool get isBullish => bias.contains('BULLISH');
  bool get isBearish => bias.contains('BEARISH') || bias.contains('DROP');
}

class ScenarioSimulationItem {
  final String id;
  final String title;
  final String probability;
  final String catalystEvent;
  final String macroConsequence;
  final Map<String, AssetScenarioPrediction> assetPredictions;

  const ScenarioSimulationItem({
    required this.id,
    required this.title,
    required this.probability,
    required this.catalystEvent,
    required this.macroConsequence,
    required this.assetPredictions,
  });
}

class TokenUnlockAlert {
  final String symbol;
  final String name;
  final DateTime unlockDate;
  final double amountUsdMillions;
  final double percentOfCirculating;
  final String risk; // 'HIGH', 'MEDIUM'

  const TokenUnlockAlert({
    required this.symbol,
    required this.name,
    required this.unlockDate,
    required this.amountUsdMillions,
    required this.percentOfCirculating,
    required this.risk,
  });

  int get daysUntil {
    final diff = unlockDate.difference(DateTime.now());
    final days = (diff.inHours / 24).round();
    return days < 0 ? 0 : days;
  }
}
