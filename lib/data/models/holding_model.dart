class HoldingModel {
  final String id;
  final String coinId;
  final String symbol;
  final String name;
  final double totalQuantity;
  final double averageBuyPrice;
  final double currentPrice;
  final double change24h;
  final double totalInvestedCost;
  final double currentValue;
  final double unrealizedPnl;
  final double unrealizedPnlPercentage;
  final double realizedPnl;

  HoldingModel({
    required this.id,
    required this.coinId,
    required this.symbol,
    required this.name,
    required this.totalQuantity,
    required this.averageBuyPrice,
    required this.currentPrice,
    required this.change24h,
    required this.totalInvestedCost,
    required this.currentValue,
    required this.unrealizedPnl,
    required this.unrealizedPnlPercentage,
    required this.realizedPnl,
  });

  factory HoldingModel.fromJson(Map<String, dynamic> json) {
    return HoldingModel(
      id: json['id'] ?? '',
      coinId: json['coinId'] ?? '',
      symbol: json['symbol'] ?? '',
      name: json['name'] ?? '',
      totalQuantity: (json['totalQuantity'] as num?)?.toDouble() ?? 0.0,
      averageBuyPrice: (json['averageBuyPrice'] as num?)?.toDouble() ?? 0.0,
      currentPrice: (json['currentPrice'] as num?)?.toDouble() ?? 0.0,
      change24h: (json['change24h'] as num?)?.toDouble() ?? 0.0,
      totalInvestedCost: (json['totalInvestedCost'] as num?)?.toDouble() ?? 0.0,
      currentValue: (json['currentValue'] as num?)?.toDouble() ?? 0.0,
      unrealizedPnl: (json['unrealizedPnl'] as num?)?.toDouble() ?? 0.0,
      unrealizedPnlPercentage: (json['unrealizedPnlPercentage'] as num?)?.toDouble() ?? 0.0,
      realizedPnl: (json['realizedPnl'] as num?)?.toDouble() ?? 0.0,
    );
  }

  HoldingModel copyWith({
    String? id,
    String? coinId,
    String? symbol,
    String? name,
    double? totalQuantity,
    double? averageBuyPrice,
    double? currentPrice,
    double? change24h,
    double? totalInvestedCost,
    double? currentValue,
    double? unrealizedPnl,
    double? unrealizedPnlPercentage,
    double? realizedPnl,
  }) {
    return HoldingModel(
      id: id ?? this.id,
      coinId: coinId ?? this.coinId,
      symbol: symbol ?? this.symbol,
      name: name ?? this.name,
      totalQuantity: totalQuantity ?? this.totalQuantity,
      averageBuyPrice: averageBuyPrice ?? this.averageBuyPrice,
      currentPrice: currentPrice ?? this.currentPrice,
      change24h: change24h ?? this.change24h,
      totalInvestedCost: totalInvestedCost ?? this.totalInvestedCost,
      currentValue: currentValue ?? this.currentValue,
      unrealizedPnl: unrealizedPnl ?? this.unrealizedPnl,
      unrealizedPnlPercentage: unrealizedPnlPercentage ?? this.unrealizedPnlPercentage,
      realizedPnl: realizedPnl ?? this.realizedPnl,
    );
  }
}

class AssetAllocation {
  final String coinId;
  final String symbol;
  final double percentage;
  final double value;

  AssetAllocation({
    required this.coinId,
    required this.symbol,
    required this.percentage,
    required this.value,
  });

  factory AssetAllocation.fromJson(Map<String, dynamic> json) {
    return AssetAllocation(
      coinId: json['coinId'] ?? '',
      symbol: json['symbol'] ?? '',
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
