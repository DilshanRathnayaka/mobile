class TransactionModel {
  final String id;
  final String type; // BUY, SELL, SALARY_DEPOSIT
  final String? coinId;
  final String? symbol;
  final String? name;
  final double amount;
  final double pricePerUnit;
  final double totalAmount;
  final double fee;
  final DateTime transactionDate;
  final String notes;
  final String originalCurrency;
  final double? originalAmount;
  final double fxToBase;
  final double leverage;
  final double? margin;
  final double? liquidationPrice;

  TransactionModel({
    required this.id,
    required this.type,
    this.coinId,
    this.symbol,
    this.name,
    required this.amount,
    required this.pricePerUnit,
    required this.totalAmount,
    required this.fee,
    required this.transactionDate,
    required this.notes,
    this.originalCurrency = 'USD',
    this.originalAmount,
    this.fxToBase = 1.0,
    this.leverage = 1.0,
    this.margin,
    this.liquidationPrice,
  });

  bool get isFutures => leverage > 1.0 || type == 'LONG' || type == 'SHORT';
  bool get isLong => type == 'BUY' || type == 'LONG';
  bool get isShort => type == 'SELL' || type == 'SHORT';

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    final lev = (json['leverage'] as num?)?.toDouble() ?? 1.0;
    final total = (json['totalAmount'] ?? json['total_amount'] as num?)?.toDouble() ?? 0.0;
    final mg = (json['margin'] as num?)?.toDouble() ?? (lev > 1.0 && total > 0 ? total / lev : null);

    return TransactionModel(
      id: json['_id'] ?? json['id'] ?? '',
      type: json['type'] ?? 'BUY',
      coinId: json['coinId'] ?? json['coin_id'],
      symbol: json['symbol'],
      name: json['name'],
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      pricePerUnit: (json['pricePerUnit'] ?? json['price_per_unit'] as num?)?.toDouble() ?? 1.0,
      totalAmount: total,
      fee: (json['fee'] as num?)?.toDouble() ?? 0.0,
      transactionDate: json['transactionDate'] != null
          ? DateTime.parse(json['transactionDate'])
          : (json['transaction_date'] != null
              ? DateTime.parse(json['transaction_date'])
              : DateTime.now()),
      notes: json['notes'] ?? '',
      originalCurrency: json['originalCurrency'] ?? json['original_currency'] ?? 'USD',
      originalAmount: (json['originalAmount'] ?? json['original_amount'] as num?)?.toDouble(),
      fxToBase: (json['fxToBase'] ?? json['fx_to_base'] as num?)?.toDouble() ?? 1.0,
      leverage: lev,
      margin: mg,
      liquidationPrice: (json['liquidationPrice'] ?? json['liquidation_price'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'coinId': coinId,
      'symbol': symbol,
      'name': name,
      'amount': amount,
      'pricePerUnit': pricePerUnit,
      'totalAmount': totalAmount,
      'fee': fee,
      'transactionDate': transactionDate.toIso8601String(),
      'notes': notes,
      'originalCurrency': originalCurrency,
      'originalAmount': originalAmount,
      'fxToBase': fxToBase,
      'leverage': leverage,
      'margin': margin,
      'liquidationPrice': liquidationPrice,
    };
  }
}
