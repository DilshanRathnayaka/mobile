class BinanceTickerModel {
  final String symbol; // e.g. BTC
  final String pair; // e.g. BTCUSDT
  final String name; // e.g. Bitcoin
  final double price; // e.g. 68450.20
  final double priceChangePercent; // e.g. 3.42
  final double highPrice;
  final double lowPrice;
  final double quoteVolume; // 24h volume in USDT
  final double volume;
  final DateTime? observationTime;
  final bool isStale;

  const BinanceTickerModel({
    required this.symbol,
    required this.pair,
    required this.name,
    required this.price,
    required this.priceChangePercent,
    required this.highPrice,
    required this.lowPrice,
    required this.quoteVolume,
    required this.volume,
    this.observationTime,
    this.isStale = false,
  });

  BinanceTickerModel copyWith({
    String? symbol,
    String? pair,
    String? name,
    double? price,
    double? priceChangePercent,
    double? highPrice,
    double? lowPrice,
    double? quoteVolume,
    double? volume,
    DateTime? observationTime,
    bool? isStale,
  }) {
    return BinanceTickerModel(
      symbol: symbol ?? this.symbol,
      pair: pair ?? this.pair,
      name: name ?? this.name,
      price: price ?? this.price,
      priceChangePercent: priceChangePercent ?? this.priceChangePercent,
      highPrice: highPrice ?? this.highPrice,
      lowPrice: lowPrice ?? this.lowPrice,
      quoteVolume: quoteVolume ?? this.quoteVolume,
      volume: volume ?? this.volume,
      observationTime: observationTime ?? this.observationTime,
      isStale: isStale ?? this.isStale,
    );
  }

  factory BinanceTickerModel.fromJson(Map<String, dynamic> json, {DateTime? observationTime}) {
    final pair = json['symbol'] as String? ?? '';
    final baseSymbol = pair.endsWith('USDT')
        ? pair.substring(0, pair.length - 4)
        : pair;

    return BinanceTickerModel(
      symbol: baseSymbol,
      pair: pair,
      name: _resolveCoinName(baseSymbol),
      price: double.tryParse(json['lastPrice']?.toString() ?? '0') ?? 0.0,
      priceChangePercent: double.tryParse(json['priceChangePercent']?.toString() ?? '0') ?? 0.0,
      highPrice: double.tryParse(json['highPrice']?.toString() ?? '0') ?? 0.0,
      lowPrice: double.tryParse(json['lowPrice']?.toString() ?? '0') ?? 0.0,
      quoteVolume: double.tryParse(json['quoteVolume']?.toString() ?? '0') ?? 0.0,
      volume: double.tryParse(json['volume']?.toString() ?? '0') ?? 0.0,
      observationTime: observationTime,
      isStale: false,
    );
  }

  static String _resolveCoinName(String sym) {
    const map = {
      'BTC': 'Bitcoin',
      'ETH': 'Ethereum',
      'SOL': 'Solana',
      'BNB': 'BNB',
      'XRP': 'XRP',
      'DOGE': 'Dogecoin',
      'ADA': 'Cardano',
      'AVAX': 'Avalanche',
      'SHIB': 'Shiba Inu',
      'SUI': 'Sui',
      'PEPE': 'Pepe',
      'LINK': 'Chainlink',
      'NEAR': 'NEAR Protocol',
      'DOT': 'Polkadot',
      'LTC': 'Litecoin',
      'UNI': 'Uniswap',
      'APT': 'Aptos',
      'FET': 'Artificial Superintelligence Alliance',
      'TAO': 'Bittensor',
      'RENDER': 'Render',
      'ICP': 'Internet Computer',
      'TRX': 'TRON',
      'BCH': 'Bitcoin Cash',
      'XLM': 'Stellar',
      'ATOM': 'Cosmos',
      'ARB': 'Arbitrum',
      'OP': 'Optimism',
      'INJ': 'Injective',
      'TIA': 'Celestia',
      'SEI': 'Sei Network',
      'MATIC': 'Polygon (POL)',
      'POL': 'Polygon',
      'FIL': 'Filecoin',
      'KAS': 'Kaspa',
      'FTM': 'Fantom',
      'STX': 'Stacks',
      'RUNE': 'THORChain',
      'AAVE': 'Aave',
      'FLOKI': 'Floki',
      'BONK': 'Bonk',
      'WIF': 'dogwifhat',
      'TON': 'Toncoin',
      'NOT': 'Notcoin',
      'WLD': 'Worldcoin',
      'JUP': 'Jupiter',
      'PYTH': 'Pyth Network',
      'GALA': 'Gala',
      'SAND': 'The Sandbox',
      'MANA': 'Decentraland',
      'AXS': 'Axie Infinity',
      'ALGO': 'Algorand',
      'HBAR': 'Hedera',
      'VET': 'VeChain',
      'ENA': 'Ethena',
      'PENDLE': 'Pendle',
      'ONDO': 'Ondo Finance',
      'ARKM': 'Arkham',
      'MKR': 'Maker',
      'LDO': 'Lido DAO',
      'QNT': 'Quant',
      'CRV': 'Curve DAO',
      'DYDX': 'dYdX',
      'EGLD': 'MultiversX',
      'FLOW': 'Flow',
      'EOS': 'EOS',
      'KAVA': 'Kava',
      'MINA': 'Mina',
      'NEO': 'Neo',
      'IOTA': 'IOTA',
      'XTZ': 'Tezos',
      'CHZ': 'Chiliz',
      'GMX': 'GMX',
      'SNX': 'Synthetix',
      'CAKE': 'PancakeSwap',
      'BLUR': 'Blur',
      'ORDI': 'ORDI',
      'SATS': '1000SATS',
      'BOME': 'BOOK OF MEME',
      'MEME': 'Memecoin',
      'MEW': 'cat in a dogs world',
      'POPCAT': 'Popcat',
      'TURBO': 'Turbo',
      'NEIRO': 'Neiro',
      'HMSTR': 'Hamster Kombat',
      'DOGS': 'Dogs',
      'CATI': 'Catizen',
    };

    return map[sym] ?? sym;
  }
}
