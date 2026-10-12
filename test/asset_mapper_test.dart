import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/utils/asset_mapper.dart';

void main() {
  group('AssetMapper Tests', () {
    test('Correctly maps symbols to canonical CoinGecko IDs', () {
      expect(AssetMapper.getCanonicalCoinId('BTC'), equals('bitcoin'));
      expect(AssetMapper.getCanonicalCoinId('btc'), equals('bitcoin'));
      expect(AssetMapper.getCanonicalCoinId('ETH'), equals('ethereum'));
      expect(AssetMapper.getCanonicalCoinId('eth'), equals('ethereum'));
      expect(AssetMapper.getCanonicalCoinId('SOL'), equals('solana'));
      expect(AssetMapper.getCanonicalCoinId('BNB'), equals('binancecoin'));
      expect(AssetMapper.getCanonicalCoinId('XRP'), equals('ripple'));
      expect(AssetMapper.getCanonicalCoinId('DOGE'), equals('dogecoin'));
      expect(AssetMapper.getCanonicalCoinId('ADA'), equals('cardano'));
      expect(AssetMapper.getCanonicalCoinId('AVAX'), equals('avalanche-2'));
      expect(AssetMapper.getCanonicalCoinId('LINK'), equals('chainlink'));
      expect(AssetMapper.getCanonicalCoinId('SUI'), equals('sui'));
      expect(AssetMapper.getCanonicalCoinId('PEPE'), equals('pepe'));
      expect(AssetMapper.getCanonicalCoinId('SHIB'), equals('shiba-inu'));
    });

    test('Preserves existing canonical IDs', () {
      expect(AssetMapper.getCanonicalCoinId('bitcoin'), equals('bitcoin'));
      expect(AssetMapper.getCanonicalCoinId('ethereum'), equals('ethereum'));
      expect(AssetMapper.getCanonicalCoinId('solana'), equals('solana'));
    });

    test('Handles unknown tokens gracefully by lowercasing identifier', () {
      expect(AssetMapper.getCanonicalCoinId('UNKNOWN_TOKEN'), equals('unknown_token'));
      expect(AssetMapper.getCanonicalCoinId('XYZ123'), equals('xyz123'));
    });

    test('Correctly builds Binance trading pairs', () {
      expect(AssetMapper.getBinancePair('BTC'), equals('BTCUSDT'));
      expect(AssetMapper.getBinancePair('ETH'), equals('ETHUSDT'));
      expect(AssetMapper.getBinancePair('SOL'), equals('SOLUSDT'));
      expect(AssetMapper.getBinancePair('DOGE'), equals('DOGEUSDT'));
      expect(AssetMapper.getBinancePair('BTCUSDT'), equals('BTCUSDT'));
    });

    test('Resolves ticker symbol from canonical ID', () {
      expect(AssetMapper.getSymbolFromId('bitcoin'), equals('BTC'));
      expect(AssetMapper.getSymbolFromId('ethereum'), equals('ETH'));
      expect(AssetMapper.getSymbolFromId('solana'), equals('SOL'));
      expect(AssetMapper.getSymbolFromId('unknown_coin'), equals('UNKNOWN_COIN'));
    });
  });
}
