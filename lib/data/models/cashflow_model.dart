class CashflowItem {
  final String id;
  final String type; // 'DEPOSIT' or 'WITHDRAWAL'
  final double amount;
  final String category; // 'Salary Inflow', 'Bank Deposit', 'Profit Cashout', etc.
  final DateTime date;
  final String notes;

  const CashflowItem({
    required this.id,
    required this.type,
    required this.amount,
    required this.category,
    required this.date,
    required this.notes,
  });

  bool get isDeposit => type == 'DEPOSIT';

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'amount': amount,
        'category': category,
        'date': date.toIso8601String(),
        'notes': notes,
      };

  factory CashflowItem.fromJson(Map<String, dynamic> json) => CashflowItem(
        id: json['id'] as String? ?? '',
        type: json['type'] as String? ?? 'DEPOSIT',
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        category: json['category'] as String? ?? 'Deposit',
        date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
        notes: json['notes'] as String? ?? '',
      );

  CashflowItem copyWith({
    String? id,
    String? type,
    double? amount,
    String? category,
    DateTime? date,
    String? notes,
  }) {
    return CashflowItem(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      date: date ?? this.date,
      notes: notes ?? this.notes,
    );
  }
}

class CashflowSummary {
  final double totalDeposited;
  final double totalWithdrawn;
  final double netCapital;
  final List<CashflowItem> items;

  const CashflowSummary({
    required this.totalDeposited,
    required this.totalWithdrawn,
    required this.netCapital,
    required this.items,
  });

  factory CashflowSummary.empty() => const CashflowSummary(
        totalDeposited: 0,
        totalWithdrawn: 0,
        netCapital: 0,
        items: [],
      );
}
