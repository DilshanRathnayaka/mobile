class CashflowItem {
  final String id;
  final String type; // 'DEPOSIT' or 'WITHDRAWAL'
  final double amount; // USDT amount
  final String category; // 'Salary Inflow', 'P2P Trade', 'Bank Deposit', etc.
  final DateTime date;
  final String notes;
  final bool isP2P;
  final double? p2pRate; // Local fiat per 1 USDT (e.g. 310.50 LKR)
  final String? localCurrency; // e.g. 'LKR', 'INR', 'AED', 'USD'
  final double? localAmount; // Total local currency (e.g. 155,250.00 LKR)

  const CashflowItem({
    required this.id,
    required this.type,
    required this.amount,
    required this.category,
    required this.date,
    required this.notes,
    this.isP2P = false,
    this.p2pRate,
    this.localCurrency,
    this.localAmount,
  });

  bool get isDeposit => type == 'DEPOSIT';
  double get effectiveRate => (p2pRate != null && p2pRate! > 0) ? p2pRate! : 1.0;
  double get effectiveLocalAmount => localAmount ?? (amount * effectiveRate);
  String get effectiveLocalCurrency =>
      (localCurrency != null && localCurrency!.isNotEmpty) ? localCurrency! : 'LKR';

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'amount': amount,
        'category': category,
        'date': date.toIso8601String(),
        'notes': notes,
        'isP2P': isP2P,
        'p2pRate': p2pRate,
        'localCurrency': localCurrency,
        'localAmount': localAmount,
      };

  factory CashflowItem.fromJson(Map<String, dynamic> json) {
    final rawRate = (json['p2pRate'] ?? json['p2p_rate'] ?? json['price_per_unit'] ?? json['fx_to_base'] as num?)?.toDouble();
    final rawLocalAmt = (json['localAmount'] ?? json['local_amount'] ?? json['original_amount'] as num?)?.toDouble();
    final rawCurrency = json['localCurrency'] as String? ?? json['local_currency'] as String? ?? json['original_currency'] as String?;
    final notes = json['notes'] as String? ?? '';
    final category = json['category'] as String? ?? json['name'] as String? ?? 'Deposit';

    final hasP2pTag = notes.toUpperCase().contains('[P2P]') ||
        category.toUpperCase().contains('P2P') ||
        (rawRate != null && rawRate > 1.0) ||
        (json['isP2P'] == true);

    return CashflowItem(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'DEPOSIT',
      amount: (json['amount'] as num?)?.toDouble() ?? (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      category: category,
      date: DateTime.tryParse(json['date'] as String? ?? json['transaction_date'] as String? ?? '') ?? DateTime.now(),
      notes: notes,
      isP2P: hasP2pTag,
      p2pRate: rawRate != null && rawRate > 1.0 ? rawRate : null,
      localCurrency: rawCurrency,
      localAmount: rawLocalAmt,
    );
  }

  CashflowItem copyWith({
    String? id,
    String? type,
    double? amount,
    String? category,
    DateTime? date,
    String? notes,
    bool? isP2P,
    double? p2pRate,
    String? localCurrency,
    double? localAmount,
  }) {
    return CashflowItem(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      isP2P: isP2P ?? this.isP2P,
      p2pRate: p2pRate ?? this.p2pRate,
      localCurrency: localCurrency ?? this.localCurrency,
      localAmount: localAmount ?? this.localAmount,
    );
  }
}

class CashflowSummary {
  final double totalDeposited;
  final double totalWithdrawn;
  final double netCapital;
  final List<CashflowItem> items;

  // 🤝 P2P Merchant Specific Metrics (Null-safe backing fields)
  final double? _totalP2pDepositedUsdt;
  final double? _totalP2pDepositedLocal;
  final double? _avgP2pBuyRate;
  final double? _totalP2pWithdrawnUsdt;
  final double? _totalP2pWithdrawnLocal;
  final double? _avgP2pSellRate;
  final double? _p2pNetProfitLocal;
  final int? _p2pTradeCount;

  double get totalP2pDepositedUsdt => _totalP2pDepositedUsdt ?? 0.0;
  double get totalP2pDepositedLocal => _totalP2pDepositedLocal ?? 0.0;
  double get avgP2pBuyRate => _avgP2pBuyRate ?? 0.0;
  double get totalP2pWithdrawnUsdt => _totalP2pWithdrawnUsdt ?? 0.0;
  double get totalP2pWithdrawnLocal => _totalP2pWithdrawnLocal ?? 0.0;
  double get avgP2pSellRate => _avgP2pSellRate ?? 0.0;
  double get p2pNetProfitLocal => _p2pNetProfitLocal ?? 0.0;
  int get p2pTradeCount => _p2pTradeCount ?? 0;

  const CashflowSummary({
    required this.totalDeposited,
    required this.totalWithdrawn,
    required this.netCapital,
    required this.items,
    double? totalP2pDepositedUsdt,
    double? totalP2pDepositedLocal,
    double? avgP2pBuyRate,
    double? totalP2pWithdrawnUsdt,
    double? totalP2pWithdrawnLocal,
    double? avgP2pSellRate,
    double? p2pNetProfitLocal,
    int? p2pTradeCount,
  })  : _totalP2pDepositedUsdt = totalP2pDepositedUsdt ?? 0.0,
        _totalP2pDepositedLocal = totalP2pDepositedLocal ?? 0.0,
        _avgP2pBuyRate = avgP2pBuyRate ?? 0.0,
        _totalP2pWithdrawnUsdt = totalP2pWithdrawnUsdt ?? 0.0,
        _totalP2pWithdrawnLocal = totalP2pWithdrawnLocal ?? 0.0,
        _avgP2pSellRate = avgP2pSellRate ?? 0.0,
        _p2pNetProfitLocal = p2pNetProfitLocal ?? 0.0,
        _p2pTradeCount = p2pTradeCount ?? 0;

  factory CashflowSummary.empty() => const CashflowSummary(
        totalDeposited: 0,
        totalWithdrawn: 0,
        netCapital: 0,
        items: [],
        totalP2pDepositedUsdt: 0,
        totalP2pDepositedLocal: 0,
        avgP2pBuyRate: 0,
        totalP2pWithdrawnUsdt: 0,
        totalP2pWithdrawnLocal: 0,
        avgP2pSellRate: 0,
        p2pNetProfitLocal: 0,
        p2pTradeCount: 0,
      );
}
