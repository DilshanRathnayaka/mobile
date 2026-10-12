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
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['_id'] ?? json['id'] ?? '',
      type: json['type'] ?? 'BUY',
      coinId: json['coinId'] ?? json['coin_id'],
      symbol: json['symbol'],
      name: json['name'],
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      pricePerUnit: (json['pricePerUnit'] ?? json['price_per_unit'] as num?)?.toDouble() ?? 1.0,
      totalAmount: (json['totalAmount'] ?? json['total_amount'] as num?)?.toDouble() ?? 0.0,
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
    };
  }
}
