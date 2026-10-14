class LivePriceTick {
  final String symbol;
  final double price;
  final double change24h;
  final DateTime timestamp;

  LivePriceTick({
    required this.symbol,
    required this.price,
    required this.change24h,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() => 'LivePriceTick($symbol: \$$price, ${change24h.toStringAsFixed(2)}%)';
}
