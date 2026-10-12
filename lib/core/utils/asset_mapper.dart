/// Canonical asset repository mapping tickers, symbols, CoinGecko IDs, and Binance pairs.
class AssetMapper {
  static final Map<String, String> _symbolToCoingecko = {
    'BTC': 'bitcoin',
    'ETH': 'ethereum',
    'SOL': 'solana',
    'BNB': 'binancecoin',
    'XRP': 'ripple',
    'ADA': 'cardano',
    'DOGE': 'dogecoin',
    'AVAX': 'avalanche-2',
    'DOT': 'polkadot',
    'LINK': 'chainlink',
    'MATIC': 'matic-network',
    'PEPE': 'pepe',
    'SUI': 'sui',
    'NEAR': 'near',
    'TRX': 'tron',
    'SHIB': 'shiba-inu',
    'LTC': 'litecoin',
    'BCH': 'bitcoin-cash',
    'UNI': 'uniswap',
    'APT': 'aptos',
    'ATOM': 'cosmos',
    'FIL': 'filecoin',
    'ICP': 'internet-computer',
    'ARB': 'arbitrum',
    'OP': 'optimism',
    'RENDER': 'render-token',
    'INJ': 'injective-protocol',
    'TIA': 'celestia',
    'FET': 'fetch-ai',
    'KAS': 'kaspa',
    'SEI': 'sei-network',
    'RUNE': 'thorchain',
    'AAVE': 'aave',
    'STX': 'blockstack',
    'FTM': 'fantom',
    'GRT': 'the-graph',
    'ALGO': 'algorand',
  };

  static final Map<String, String> _coingeckoToSymbol = {
    for (final entry in _symbolToCoingecko.entries) entry.value: entry.key,
  };

  /// Returns canonical CoinGecko ID for an asset symbol or existing ID
  static String getCanonicalCoinId(String symbolOrId) {
    final clean = symbolOrId.trim();
    final upper = clean.toUpperCase();
    if (_symbolToCoingecko.containsKey(upper)) {
      return _symbolToCoingecko[upper]!;
    }
    final lower = clean.toLowerCase();
    if (_coingeckoToSymbol.containsKey(lower)) {
      return lower;
    }
    // Fallback: lowercase identifier
    return lower;
  }

  /// Returns standard Binance ticker (e.g. BTCUSDT)
  static String getBinancePair(String symbol) {
    final clean = symbol.trim().toUpperCase();
    if (clean.endsWith('USDT')) return clean;
    return '${clean}USDT';
  }

  /// Resolves standard display symbol from CoinGecko ID
  static String getSymbolFromId(String coinId) {
    final lower = coinId.trim().toLowerCase();
    if (_coingeckoToSymbol.containsKey(lower)) {
      return _coingeckoToSymbol[lower]!;
    }
    return coinId.toUpperCase();
  }
}
