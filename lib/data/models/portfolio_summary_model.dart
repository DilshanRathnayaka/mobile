import 'holding_model.dart';

class PortfolioSummaryModel {
  final double totalInvested;
  final double currentValue;
  final double unrealizedPnl;
  final double unrealizedPnlPercentage;
  final double realizedPnl;
  final int coinsCount;
  final List<HoldingModel> holdings;
  final List<AssetAllocation> allocations;
  final double unallocatedUsdt;
  final double netPortfolioValue;

  PortfolioSummaryModel({
    required this.totalInvested,
    required this.currentValue,
    required this.unrealizedPnl,
    required this.unrealizedPnlPercentage,
    required this.realizedPnl,
    required this.coinsCount,
    required this.holdings,
    required this.allocations,
    this.unallocatedUsdt = 0.0,
    double? netPortfolioValue,
  }) : netPortfolioValue = netPortfolioValue ?? (currentValue + (unallocatedUsdt));

  factory PortfolioSummaryModel.fromJson(Map<String, dynamic> json) {
    final curVal = (json['currentValue'] as num?)?.toDouble() ?? 0.0;
    final unalloc = (json['unallocatedUsdt'] as num?)?.toDouble() ?? 0.0;
    final netVal = (json['netPortfolioValue'] as num?)?.toDouble() ?? (curVal + unalloc);

    final rawHoldings = (json['holdings'] as List<dynamic>? ?? [])
        .map((h) => HoldingModel.fromJson(h))
        .where((h) => h.totalQuantity > 0.00000001)
        .toList();

    return PortfolioSummaryModel(
      totalInvested: (json['totalInvested'] as num?)?.toDouble() ?? 0.0,
      currentValue: curVal,
      unrealizedPnl: (json['unrealizedPnl'] as num?)?.toDouble() ?? 0.0,
      unrealizedPnlPercentage: (json['unrealizedPnlPercentage'] as num?)?.toDouble() ?? 0.0,
      realizedPnl: (json['realizedPnl'] as num?)?.toDouble() ?? 0.0,
      coinsCount: rawHoldings.length,
      holdings: rawHoldings,
      allocations: (json['allocations'] as List<dynamic>? ?? [])
          .map((a) => AssetAllocation.fromJson(a))
          .toList(),
      unallocatedUsdt: unalloc,
      netPortfolioValue: netVal,
    );
  }

  factory PortfolioSummaryModel.empty() {
    return PortfolioSummaryModel(
      totalInvested: 0,
      currentValue: 0,
      unrealizedPnl: 0,
      unrealizedPnlPercentage: 0,
      realizedPnl: 0,
      coinsCount: 0,
      holdings: [],
      allocations: [],
      unallocatedUsdt: 0,
      netPortfolioValue: 0,
    );
  }

  PortfolioSummaryModel copyWith({
    double? totalInvested,
    double? currentValue,
    double? unrealizedPnl,
    double? unrealizedPnlPercentage,
    double? realizedPnl,
    int? coinsCount,
    List<HoldingModel>? holdings,
    List<AssetAllocation>? allocations,
    double? unallocatedUsdt,
    double? netPortfolioValue,
  }) {
    return PortfolioSummaryModel(
      totalInvested: totalInvested ?? this.totalInvested,
      currentValue: currentValue ?? this.currentValue,
      unrealizedPnl: unrealizedPnl ?? this.unrealizedPnl,
      unrealizedPnlPercentage: unrealizedPnlPercentage ?? this.unrealizedPnlPercentage,
      realizedPnl: realizedPnl ?? this.realizedPnl,
      coinsCount: coinsCount ?? this.coinsCount,
      holdings: holdings ?? this.holdings,
      allocations: allocations ?? this.allocations,
      unallocatedUsdt: unallocatedUsdt ?? this.unallocatedUsdt,
      netPortfolioValue: netPortfolioValue ?? this.netPortfolioValue,
    );
  }
}
