import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/utils/asset_mapper.dart';
import '../models/binance_ticker_model.dart';
import '../models/live_price_tick.dart';

/// Real-time live market price streaming service.
/// Streams 24h prices and changes directly from Binance WebSocket (!miniTicker@arr),
/// with automatic reconnection and fallback HTTP polling.
class LivePriceService {
  static const String _wsUrl = 'wss://stream.binance.com:9443/ws/!miniTicker@arr';
  static const String _httpTickerUrl = 'https://api.binance.com/api/v3/ticker/24hr';

  WebSocket? _webSocket;
  StreamSubscription? _wsSubscription;
  Timer? _reconnectTimer;
  Timer? _fallbackPollingTimer;
  DateTime? _lastTickReceived;

  bool _isDisposed = false;
  bool _isConnected = false;

  final Map<String, LivePriceTick> _priceMap = {};
  final StreamController<Map<String, LivePriceTick>> _priceController =
      StreamController<Map<String, LivePriceTick>>.broadcast();
  final StreamController<bool> _statusController =
      StreamController<bool>.broadcast();

  // Rate-limiting / throttling controller so listeners update smoothly (~once per second)
  Timer? _throttleTimer;
  bool _pendingEmit = false;

  LivePriceService() {
    _start();
  }

  /// Broadcast stream of real-time prices keyed by Symbol, Binance Pair, and Canonical Coin ID
  Stream<Map<String, LivePriceTick>> get priceStream => _priceController.stream;

  /// Connection status stream (true = live WebSocket active, false = reconnecting / fallback)
  Stream<bool> get statusStream => _statusController.stream;

  /// Whether real-time live streaming is currently connected
  bool get isConnected => _isConnected;

  /// In-memory latest snapshot of all live prices
  Map<String, LivePriceTick> get latestPrices => Map.unmodifiable(_priceMap);

  /// Get live price for a symbol or canonical ID
  LivePriceTick? getPrice(String symbolOrId) {
    final clean = symbolOrId.trim();
    final upper = clean.toUpperCase();
    final canon = AssetMapper.getCanonicalCoinId(clean);

    return _priceMap[upper] ??
        _priceMap['${upper}USDT'] ??
        _priceMap[canon] ??
        _priceMap[clean.toLowerCase()];
  }

  void _start() {
    if (_isDisposed) return;
    _connectWebSocket();

    // Safety watchdog: If no WebSocket ticks arrive for > 6 seconds, poll via HTTP
    _fallbackPollingTimer?.cancel();
    _fallbackPollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      final now = DateTime.now();
      if (_lastTickReceived == null ||
          now.difference(_lastTickReceived!).inSeconds >= 5) {
        _pollHttpPrices();
      }
    });
  }

  Future<void> _connectWebSocket() async {
    if (_isDisposed) return;

    try {
      _wsSubscription?.cancel();
      await _webSocket?.close();
    } catch (_) {}

    try {
      debugPrint('[LivePriceService] Connecting to Binance WebSocket...');
      final ws = await WebSocket.connect(_wsUrl)
          .timeout(const Duration(seconds: 6));

      _webSocket = ws;
      _isConnected = true;
      _statusController.add(true);
      debugPrint('[LivePriceService] Binance WebSocket connected successfully.');

      _wsSubscription = ws.listen(
        (data) {
          _lastTickReceived = DateTime.now();
          if (!_isConnected) {
            _isConnected = true;
            _statusController.add(true);
          }
          _handleWsMessage(data);
        },
        onError: (err) {
          debugPrint('[LivePriceService] WebSocket error: $err');
          _scheduleReconnect();
        },
        onDone: () {
          debugPrint('[LivePriceService] WebSocket closed.');
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('[LivePriceService] Connection failed: $e');
      _scheduleReconnect();
    }
  }

  void _handleWsMessage(dynamic data) {
    try {
      final List list = jsonDecode(data.toString());
      final now = DateTime.now();

      for (final item in list) {
        final pair = (item['s'] as String? ?? '').toUpperCase();
        if (!pair.endsWith('USDT')) continue;

        final baseSymbol = pair.substring(0, pair.length - 4);
        final price = double.tryParse(item['c']?.toString() ?? '') ?? 0.0;
        final openPrice = double.tryParse(item['o']?.toString() ?? '') ?? 0.0;
        if (price <= 0) continue;

        final change24h =
            openPrice > 0 ? ((price - openPrice) / openPrice) * 100 : 0.0;

        final tick = LivePriceTick(
          symbol: baseSymbol,
          price: price,
          change24h: change24h,
          timestamp: now,
        );

        _priceMap[baseSymbol] = tick;
        _priceMap[pair] = tick;
        final canon = AssetMapper.getCanonicalCoinId(baseSymbol);
        _priceMap[canon] = tick;
      }

      _scheduleThrottledEmit();
    } catch (e) {
      debugPrint('[LivePriceService] Parse error: $e');
    }
  }

  void _scheduleThrottledEmit() {
    _pendingEmit = true;
    if (_throttleTimer != null && _throttleTimer!.isActive) return;

    _throttleTimer = Timer(const Duration(milliseconds: 800), () {
      if (_pendingEmit && !_priceController.isClosed) {
        _priceController.add(_priceMap);
        _pendingEmit = false;
      }
    });
  }

  Future<void> _pollHttpPrices() async {
    if (_isDisposed) return;
    try {
      final res = await http.get(
        Uri.parse(_httpTickerUrl),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final List raw = jsonDecode(res.body);
        final now = DateTime.now();

        for (final item in raw) {
          final sym = (item['symbol'] as String? ?? '').toUpperCase();
          if (sym.endsWith('USDT')) {
            final baseSymbol = sym.substring(0, sym.length - 4);
            final price = double.tryParse(item['lastPrice']?.toString() ?? '') ?? 0.0;
            final change24h = double.tryParse(item['priceChangePercent']?.toString() ?? '') ?? 0.0;
            if (price <= 0) continue;

            final tick = LivePriceTick(
              symbol: baseSymbol,
              price: price,
              change24h: change24h,
              timestamp: now,
            );

            _priceMap[baseSymbol] = tick;
            _priceMap[sym] = tick;
            final canon = AssetMapper.getCanonicalCoinId(baseSymbol);
            _priceMap[canon] = tick;
          }
        }

        _lastTickReceived = now;
        _scheduleThrottledEmit();
      }
    } catch (_) {}
  }

  void _scheduleReconnect() {
    _isConnected = false;
    _statusController.add(false);

    if (_isDisposed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      _connectWebSocket();
    });
  }

  /// Convert live ticks to a list of BinanceTickerModel for Markets Screen
  List<BinanceTickerModel> toBinanceTickerModels() {
    final list = <BinanceTickerModel>[];
    final seen = <String>{};

    for (final entry in _priceMap.entries) {
      final key = entry.key;
      if (!key.endsWith('USDT')) continue;
      if (seen.contains(key)) continue;
      seen.add(key);

      final tick = entry.value;
      list.add(BinanceTickerModel(
        symbol: tick.symbol,
        pair: key,
        name: tick.symbol,
        price: tick.price,
        priceChangePercent: tick.change24h,
        highPrice: 0.0,
        lowPrice: 0.0,
        quoteVolume: 0.0,
        volume: 0.0,
      ));
    }

    return list;
  }

  void dispose() {
    _isDisposed = true;
    _reconnectTimer?.cancel();
    _fallbackPollingTimer?.cancel();
    _throttleTimer?.cancel();
    _wsSubscription?.cancel();
    try {
      _webSocket?.close();
    } catch (_) {}
    _priceController.close();
    _statusController.close();
  }
}
