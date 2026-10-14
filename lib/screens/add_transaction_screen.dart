import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/asset_mapper.dart';
import '../core/utils/formatters.dart';
import '../data/models/binance_ticker_model.dart';
import '../data/models/transaction_model.dart';
import '../providers/binance_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/portfolio_provider.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  final String initialType;
  final TransactionModel? transactionToEdit;
  final BinanceTickerModel? preselectedCoin;
  final String? preselectedCoinId;
  final String? preselectedSymbol;
  final String? preselectedCoinName;
  final double? prefilledPrice;
  final double? prefilledAmount;

  const AddTransactionScreen({
    super.key,
    this.initialType = 'BUY',
    this.transactionToEdit,
    this.preselectedCoin,
    this.preselectedCoinId,
    this.preselectedSymbol,
    this.preselectedCoinName,
    this.prefilledPrice,
    this.prefilledAmount,
  });

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class LadderStepItem {
  final int step;
  final double price;
  final double amount;
  final double notionalUsdt;
  final double margin;
  final double priceDeviationPercent;

  LadderStepItem({
    required this.step,
    required this.price,
    required this.amount,
    required this.notionalUsdt,
    required this.margin,
    required this.priceDeviationPercent,
  });
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();

  // Market & Order Type
  bool _isFuturesMode = false;
  late String _selectedType; // 'BUY', 'SELL', 'LONG', 'SHORT'
  String _selectedCoinId = 'bitcoin';
  String _selectedSymbol = 'BTC';
  String _selectedCoinName = 'Bitcoin';
  String _inputMode = 'USDT'; // 'USDT' or 'COIN'

  // Futures & Leverage
  double _leverage = 5.0; // Default 5x leverage

  // DCA Laddering Builder
  bool _enableLaddering = false;
  int _ladderSteps = 3; // 2 to 8 orders
  double _ladderSpreadPercent = 2.0; // 2% spacing per order
  String _ladderDistribution = 'EQUAL'; // 'EQUAL', 'MARTINGALE', 'PYRAMIDAL'
  bool _saveAllLadderOrders = true;

  late TextEditingController _amountController; // Coin quantity
  late TextEditingController _usdtAmountController; // Total in USDT ($)
  late TextEditingController _priceController; // Unit price
  late TextEditingController _feePercentController; // Fee percentage (e.g. 0.05)
  late TextEditingController _feeController; // Fee in USD dollars
  late TextEditingController _notesController;

  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  bool get _isEditing => widget.transactionToEdit != null;

  @override
  void initState() {
    super.initState();
    final edit = widget.transactionToEdit;
    final preselected = widget.preselectedCoin;

    if (edit != null) {
      _isFuturesMode = edit.isFutures || edit.type == 'LONG' || edit.type == 'SHORT' || edit.leverage > 1.0;
      _selectedType = edit.type == 'SALARY_DEPOSIT' ? 'BUY' : edit.type;
      _leverage = edit.leverage > 1.0 ? edit.leverage : 5.0;
      _selectedCoinId = edit.coinId ?? 'bitcoin';
      _selectedSymbol = edit.symbol ?? 'BTC';
      _selectedCoinName = edit.name ?? 'Bitcoin';
      _amountController = TextEditingController(text: edit.amount.toString());
      _priceController = TextEditingController(text: edit.pricePerUnit.toString());
      final totalUsdt = edit.amount * edit.pricePerUnit;
      _usdtAmountController = TextEditingController(text: totalUsdt > 0 ? totalUsdt.toStringAsFixed(2) : '');
      final feeDollars = edit.fee;
      final feePct = totalUsdt > 0 ? (feeDollars / totalUsdt) * 100 : 0.05;
      _feePercentController = TextEditingController(text: feePct.toStringAsFixed(3));
      _feeController = TextEditingController(text: feeDollars.toStringAsFixed(2));
      _notesController = TextEditingController(text: edit.notes);
      _selectedDate = edit.transactionDate;
    } else if (widget.preselectedCoinId != null) {
      _selectedType = widget.initialType == 'SALARY_DEPOSIT' ? 'BUY' : widget.initialType;
      _isFuturesMode = _selectedType == 'LONG' || _selectedType == 'SHORT';
      _selectedCoinId = widget.preselectedCoinId!;
      _selectedSymbol = widget.preselectedSymbol ?? widget.preselectedCoinId!.toUpperCase();
      _selectedCoinName = widget.preselectedCoinName ?? _selectedSymbol;
      final p = (widget.prefilledPrice != null && widget.prefilledPrice! > 0)
          ? widget.prefilledPrice!
          : 68420.50;
      _priceController = TextEditingController(text: p.toString());

      if ((widget.initialType == 'SELL' || widget.initialType == 'SHORT')) {
        _inputMode = 'COIN';
        if (widget.prefilledAmount != null && widget.prefilledAmount! > 0) {
          final qty = widget.prefilledAmount!;
          _amountController = TextEditingController(text: qty.toString());
          final totalVal = qty * p;
          _usdtAmountController = TextEditingController(text: totalVal.toStringAsFixed(2));
        } else {
          _amountController = TextEditingController();
          _usdtAmountController = TextEditingController();
        }
      } else {
        _inputMode = 'USDT';
        _usdtAmountController = TextEditingController(text: '100');
        final qty = 100 / p;
        _amountController = TextEditingController(text: qty >= 1 ? qty.toStringAsFixed(4) : qty.toStringAsFixed(6));
      }
      _feePercentController = TextEditingController(text: _isFuturesMode ? '0.05' : '0.1');
      final currentTotal = (double.tryParse(_amountController.text) ?? 0.0) * p;
      _feeController = TextEditingController(text: (currentTotal * (_isFuturesMode ? 0.0005 : 0.001)).toStringAsFixed(2));
      _notesController = TextEditingController();
    } else if (preselected != null) {
      _selectedType = widget.initialType == 'SALARY_DEPOSIT' ? 'BUY' : widget.initialType;
      _isFuturesMode = _selectedType == 'LONG' || _selectedType == 'SHORT';
      _selectedCoinId = preselected.symbol.toLowerCase();
       _selectedSymbol = preselected.symbol;
      _selectedCoinName = preselected.name;
      _usdtAmountController = TextEditingController(text: '100');
      final p = preselected.price > 0 ? preselected.price : 68420.50;
      _priceController = TextEditingController(text: p.toString());
      final feePct = _isFuturesMode ? 0.05 : 0.1;
      final feeDollars = 100 * (feePct / 100.0);
      final netUsdt = 100 - feeDollars;
      final qty = p > 0 ? (netUsdt / p) : 0.0;
      _amountController = TextEditingController(text: qty >= 1 ? qty.toStringAsFixed(4) : qty.toStringAsFixed(6));
      _feePercentController = TextEditingController(text: _isFuturesMode ? '0.05' : '0.1');
      _feeController = TextEditingController(text: feeDollars.toStringAsFixed(2));
      _notesController = TextEditingController();
    } else {
      _selectedType = widget.initialType == 'SALARY_DEPOSIT' ? 'BUY' : widget.initialType;
      _isFuturesMode = _selectedType == 'LONG' || _selectedType == 'SHORT';
      _usdtAmountController = TextEditingController(text: '100');
      _priceController = TextEditingController(text: '68420.50');
      final feePct = _isFuturesMode ? 0.05 : 0.1;
      final feeDollars = 100 * (feePct / 100.0);
      final netUsdt = 100 - feeDollars;
      final qty = netUsdt / 68420.50;
      _amountController = TextEditingController(text: qty >= 1 ? qty.toStringAsFixed(4) : qty.toStringAsFixed(6));
      _feePercentController = TextEditingController(text: _isFuturesMode ? '0.05' : '0.1');
      _feeController = TextEditingController(text: feeDollars.toStringAsFixed(2));
      _notesController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _usdtAmountController.dispose();
    _priceController.dispose();
    _feePercentController.dispose();
    _feeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _totalCalculated {
    final amt = double.tryParse(_amountController.text) ?? 0.0;
    final price = double.tryParse(_priceController.text) ?? 0.0;
    return amt * price;
  }

  double get _grossInvestmentCapital {
    final usdt = double.tryParse(_usdtAmountController.text) ?? 0.0;
    if (usdt > 0) return usdt;
    final fee = _feeCalculated;
    return _totalCalculated + fee;
  }

  double get _netCryptoExecutionValue {
    final gross = _grossInvestmentCapital;
    final fee = _feeCalculated;
    return (gross - fee).clamp(0.0, double.infinity);
  }

  double get _marginCalculated {
    final notional = _netCryptoExecutionValue;
    if (_isFuturesMode && _leverage > 0) {
      return notional / _leverage;
    }
    return notional;
  }

  double get _liquidationPriceCalculated {
    final price = double.tryParse(_priceController.text) ?? 0.0;
    if (price <= 0 || !_isFuturesMode || _leverage <= 1.0) return 0.0;
    final mmr = 0.005; // 0.5% maintenance margin rate approximation
    final isLong = _selectedType == 'BUY' || _selectedType == 'LONG';
    if (isLong) {
      final liq = price * (1.0 - (1.0 / _leverage) + mmr);
      return liq > 0 ? liq : 0.0;
    } else {
      return price * (1.0 + (1.0 / _leverage) - mmr);
    }
  }

  double get _liquidationDistancePercent {
    final price = double.tryParse(_priceController.text) ?? 0.0;
    final liq = _liquidationPriceCalculated;
    if (price <= 0 || liq <= 0) return 0.0;
    return ((liq - price) / price) * 100.0;
  }

  double get _feeCalculated {
    return double.tryParse(_feeController.text) ?? 0.0;
  }

  void _onUsdtAmountChanged(String val) {
    final grossUsdt = double.tryParse(val) ?? 0.0;
    final price = double.tryParse(_priceController.text) ?? 0.0;
    final feePct = double.tryParse(_feePercentController.text) ?? 0.0;
    final feeDollars = grossUsdt * (feePct / 100.0);
    _feeController.text = feeDollars > 0
        ? (feeDollars >= 0.01 ? feeDollars.toStringAsFixed(2) : feeDollars.toStringAsFixed(4))
        : '0.00';
    if (price > 0 && grossUsdt > 0) {
      final netUsdt = (grossUsdt - feeDollars).clamp(0.0, double.infinity);
      final qty = netUsdt / price;
      _amountController.text = qty > 0 ? (qty >= 1 ? qty.toStringAsFixed(4) : qty.toStringAsFixed(6)) : '';
    } else if (grossUsdt <= 0) {
      _amountController.text = '';
    }
    setState(() {});
  }

  void _onCoinAmountChanged(String val) {
    final qty = double.tryParse(val) ?? 0.0;
    final price = double.tryParse(_priceController.text) ?? 0.0;
    final feePct = double.tryParse(_feePercentController.text) ?? 0.0;
    final isSell = _selectedType == 'SELL' || _selectedType == 'SHORT';

    if (isSell) {
      final grossUsdt = qty * price;
      final feeDollars = grossUsdt * (feePct / 100.0);
      _feeController.text = feeDollars > 0
          ? (feeDollars >= 0.01 ? feeDollars.toStringAsFixed(2) : feeDollars.toStringAsFixed(4))
          : '0.00';
      _usdtAmountController.text = grossUsdt > 0
          ? (grossUsdt >= 1 ? grossUsdt.toStringAsFixed(2) : grossUsdt.toStringAsFixed(4))
          : '';
    } else {
      final netUsdt = qty * price;
      final grossUsdt = (feePct < 100.0 && feePct >= 0)
          ? (netUsdt / (1.0 - (feePct / 100.0)))
          : netUsdt;
      final feeDollars = grossUsdt - netUsdt;
      _feeController.text = feeDollars > 0
          ? (feeDollars >= 0.01 ? feeDollars.toStringAsFixed(2) : feeDollars.toStringAsFixed(4))
          : '0.00';
      _usdtAmountController.text = grossUsdt > 0
          ? (grossUsdt >= 1 ? grossUsdt.toStringAsFixed(2) : grossUsdt.toStringAsFixed(4))
          : '';
    }
    setState(() {});
  }

  void _onPriceChanged(String val) {
    final price = double.tryParse(val) ?? 0.0;
    final feePct = double.tryParse(_feePercentController.text) ?? 0.0;
    final isSell = _selectedType == 'SELL' || _selectedType == 'SHORT';

    if (_inputMode == 'USDT') {
      final grossUsdt = double.tryParse(_usdtAmountController.text) ?? 0.0;
      final feeDollars = grossUsdt * (feePct / 100.0);
      _feeController.text = feeDollars > 0
          ? (feeDollars >= 0.01 ? feeDollars.toStringAsFixed(2) : feeDollars.toStringAsFixed(4))
          : '0.00';
      if (price > 0 && grossUsdt > 0) {
        final netUsdt = isSell ? grossUsdt : (grossUsdt - feeDollars).clamp(0.0, double.infinity);
        final qty = netUsdt / price;
        _amountController.text = qty > 0 ? (qty >= 1 ? qty.toStringAsFixed(4) : qty.toStringAsFixed(6)) : '';
      }
    } else {
      final qty = double.tryParse(_amountController.text) ?? 0.0;
      if (isSell) {
        final grossUsdt = qty * price;
        final feeDollars = grossUsdt * (feePct / 100.0);
        _feeController.text = feeDollars > 0
            ? (feeDollars >= 0.01 ? feeDollars.toStringAsFixed(2) : feeDollars.toStringAsFixed(4))
            : '0.00';
        _usdtAmountController.text = grossUsdt > 0
            ? (grossUsdt >= 1 ? grossUsdt.toStringAsFixed(2) : grossUsdt.toStringAsFixed(4))
            : '';
      } else {
        final netUsdt = qty * price;
        final grossUsdt = (feePct < 100.0 && feePct >= 0)
            ? (netUsdt / (1.0 - (feePct / 100.0)))
            : netUsdt;
        final feeDollars = grossUsdt - netUsdt;
        _feeController.text = feeDollars > 0
            ? (feeDollars >= 0.01 ? feeDollars.toStringAsFixed(2) : feeDollars.toStringAsFixed(4))
            : '0.00';
        _usdtAmountController.text = grossUsdt > 0
            ? (grossUsdt >= 1 ? grossUsdt.toStringAsFixed(2) : grossUsdt.toStringAsFixed(4))
            : '';
      }
    }
    setState(() {});
  }

  void _recalculateFee() {
    final pct = double.tryParse(_feePercentController.text) ?? 0.0;
    final isSell = _selectedType == 'SELL' || _selectedType == 'SHORT';

    if (_inputMode == 'USDT') {
      final grossUsdt = double.tryParse(_usdtAmountController.text) ?? 0.0;
      final feeDollars = grossUsdt * (pct / 100.0);
      _feeController.text = feeDollars > 0
          ? (feeDollars >= 0.01 ? feeDollars.toStringAsFixed(2) : feeDollars.toStringAsFixed(4))
          : '0.00';
      final price = double.tryParse(_priceController.text) ?? 0.0;
      if (price > 0 && grossUsdt > 0) {
        final netUsdt = isSell ? grossUsdt : (grossUsdt - feeDollars).clamp(0.0, double.infinity);
        final qty = netUsdt / price;
        _amountController.text = qty > 0 ? (qty >= 1 ? qty.toStringAsFixed(4) : qty.toStringAsFixed(6)) : '';
      }
    } else {
      final qty = double.tryParse(_amountController.text) ?? 0.0;
      final price = double.tryParse(_priceController.text) ?? 0.0;
      if (isSell) {
        final grossUsdt = qty * price;
        final feeDollars = grossUsdt * (pct / 100.0);
        _feeController.text = feeDollars > 0
            ? (feeDollars >= 0.01 ? feeDollars.toStringAsFixed(2) : feeDollars.toStringAsFixed(4))
            : '0.00';
        _usdtAmountController.text = grossUsdt > 0
            ? (grossUsdt >= 1 ? grossUsdt.toStringAsFixed(2) : grossUsdt.toStringAsFixed(4))
            : '';
      } else {
        final netUsdt = qty * price;
        final grossUsdt = (pct < 100.0 && pct >= 0)
            ? (netUsdt / (1.0 - (pct / 100.0)))
            : netUsdt;
        final feeDollars = grossUsdt - netUsdt;
        _feeController.text = feeDollars > 0
            ? (feeDollars >= 0.01 ? feeDollars.toStringAsFixed(2) : feeDollars.toStringAsFixed(4))
            : '0.00';
        _usdtAmountController.text = grossUsdt > 0
            ? (grossUsdt >= 1 ? grossUsdt.toStringAsFixed(2) : grossUsdt.toStringAsFixed(4))
            : '';
      }
    }
  }

  void _applyFeePercentage(double pct) {
    _feePercentController.text = pct.toString();
    _recalculateFee();
    setState(() {});
  }

  void _toggleMarketMode(bool futures) {
    setState(() {
      _isFuturesMode = futures;
      if (_isFuturesMode) {
        if (_selectedType == 'BUY') _selectedType = 'LONG';
        if (_selectedType == 'SELL') _selectedType = 'SHORT';
        if (_leverage <= 1.0) _leverage = 5.0;
        _feePercentController.text = '0.05';
      } else {
        if (_selectedType == 'LONG') _selectedType = 'BUY';
        if (_selectedType == 'SHORT') _selectedType = 'SELL';
        _leverage = 1.0;
        _feePercentController.text = '0.10';
      }
      _recalculateFee();
    });
  }

  List<LadderStepItem> _generateLadderSteps() {
    final basePrice = double.tryParse(_priceController.text) ?? 0.0;
    final baseGrossNotional = _grossInvestmentCapital;
    if (basePrice <= 0 || baseGrossNotional <= 0 || _ladderSteps < 2) return [];

    final isLong = _selectedType == 'BUY' || _selectedType == 'LONG';
    final count = _ladderSteps;
    final feePct = double.tryParse(_feePercentController.text) ?? 0.0;

    // Determine weight multipliers
    List<double> weights = [];
    if (_ladderDistribution == 'MARTINGALE') {
      // 1x, 1.4x, 1.96x, 2.74x ...
      double currentW = 1.0;
      for (int i = 0; i < count; i++) {
        weights.add(currentW);
        currentW *= 1.4;
      }
    } else if (_ladderDistribution == 'PYRAMIDAL') {
      // 1x, 1.8x, 2.8x, 4.0x ...
      for (int i = 0; i < count; i++) {
        weights.add(1.0 + (i * 0.8));
      }
    } else {
      // Equal
      weights = List.filled(count, 1.0);
    }

    final sumWeights = weights.reduce((a, b) => a + b);

    final List<LadderStepItem> steps = [];
    for (int i = 0; i < count; i++) {
      final deviationPct = isLong ? -(i * _ladderSpreadPercent) : (i * _ladderSpreadPercent);
      final stepPrice = basePrice * (1.0 + (deviationPct / 100.0));
      final stepShare = weights[i] / sumWeights;
      final stepGross = baseGrossNotional * stepShare;
      final stepFee = stepGross * (feePct / 100.0);
      final stepNet = (stepGross - stepFee).clamp(0.0, double.infinity);
      final stepAmount = stepPrice > 0 ? (stepNet / stepPrice) : 0.0;
      final stepMargin = _isFuturesMode && _leverage > 0 ? (stepGross / _leverage) : stepGross;

      steps.add(LadderStepItem(
        step: i + 1,
        price: stepPrice > 0 ? stepPrice : 0.01,
        amount: stepAmount,
        notionalUsdt: stepGross,
        margin: stepMargin,
        priceDeviationPercent: deviationPct,
      ));
    }
    return steps;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final parsedAmount = double.tryParse(_amountController.text) ?? 0.0;
    final parsedPrice = double.tryParse(_priceController.text) ?? 0.0;
    if (parsedAmount <= 0 || parsedPrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount and price greater than 0.'),
          backgroundColor: AppColors.loss,
        ),
      );
      return;
    }

    // Spot Sell validation against existing portfolio holdings
    if (_selectedType == 'SELL' && !_isFuturesMode) {
      final portfolio = ref.read(portfolioSummaryProvider).asData?.value;
      double currentHoldingQty = widget.prefilledAmount ?? 0.0;
      if (portfolio != null) {
        for (final h in portfolio.holdings) {
          if (h.coinId.toLowerCase() == _selectedCoinId.toLowerCase() ||
              h.symbol.toUpperCase() == _selectedSymbol.toUpperCase()) {
            currentHoldingQty = h.totalQuantity;
            break;
          }
        }
      }
      if (currentHoldingQty > 0 && parsedAmount > (currentHoldingQty + 0.00000001)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cannot sell ${Formatters.cryptoAmount(parsedAmount)} $_selectedSymbol. You only hold ${Formatters.cryptoAmount(currentHoldingQty)} $_selectedSymbol.',
            ),
            backgroundColor: AppColors.loss,
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    final currency = ref.read(currencyProvider);
    final canonicalId = _selectedCoinId.isNotEmpty
        ? AssetMapper.getCanonicalCoinId(_selectedCoinId)
        : AssetMapper.getCanonicalCoinId(_selectedSymbol);

    // If DCA Laddering is enabled and user checked "Save All Ladder Orders"
    final ladderSteps = _enableLaddering ? _generateLadderSteps() : <LadderStepItem>[];
    final bool isBatchLadder = _enableLaddering && _saveAllLadderOrders && ladderSteps.length > 1;

    try {
      if (isBatchLadder) {
        // Execute batch ladder saving
        int successCount = 0;
        final baseDate = _selectedDate;

        for (int i = 0; i < ladderSteps.length; i++) {
          final step = ladderSteps[i];
          final stepFee = step.notionalUsdt * ((double.tryParse(_feePercentController.text) ?? 0.05) / 100.0);
          final stepNetTotal = (step.notionalUsdt - stepFee).clamp(0.0, double.infinity);
          final stepLiq = _isFuturesMode && _leverage > 1.0
              ? (_selectedType == 'LONG' || _selectedType == 'BUY'
                  ? step.price * (1.0 - (1.0 / _leverage) + 0.005)
                  : step.price * (1.0 + (1.0 / _leverage) - 0.005))
              : null;

          final stepNotes = _notesController.text.trim().isEmpty
              ? 'DCA Ladder Order ${i + 1}/${ladderSteps.length} (${step.priceDeviationPercent >= 0 ? "+" : ""}${step.priceDeviationPercent.toStringAsFixed(1)}%)'
              : '${_notesController.text.trim()} [Ladder ${i + 1}/${ladderSteps.length}]';

          final txData = {
            'type': _selectedType,
            'coinId': canonicalId,
            'symbol': _selectedSymbol.toUpperCase(),
            'name': _selectedCoinName,
            'amount': step.amount,
            'pricePerUnit': step.price,
            'totalAmount': stepNetTotal,
            'fee': stepFee,
            'transactionDate': baseDate.add(Duration(seconds: i * 2)).toIso8601String(),
            'notes': stepNotes,
            'originalCurrency': currency.code,
            'originalAmount': step.amount,
            'fxToBase': 1.0 / (currency.rateToUsd > 0 ? currency.rateToUsd : 1.0),
            'leverage': _isFuturesMode ? _leverage : 1.0,
            'margin': _isFuturesMode ? (stepNetTotal / _leverage) : null,
            'liquidationPrice': stepLiq,
          };

          final ok = await ref.read(transactionsProvider.notifier).addTransaction(txData);
          if (ok) successCount++;
        }

        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully placed $successCount/${ladderSteps.length} DCA ladder orders!'),
              backgroundColor: AppColors.profit,
            ),
          );
          Navigator.pop(context);
        }
        return;
      }

      // Single Order Submission
      final parsedFee = double.tryParse(_feeController.text) ?? 0.0;
      final parsedAmt = double.parse(_amountController.text);
      final parsedPrice = double.parse(_priceController.text);
      final netTotal = (parsedAmt * parsedPrice);
      final isSellOrder = _selectedType == 'SELL' || _selectedType == 'SHORT';
      final finalNetNotional = isSellOrder
          ? netTotal
          : (_netCryptoExecutionValue > 0 ? _netCryptoExecutionValue : netTotal);
      final margin = _isFuturesMode ? (finalNetNotional / _leverage) : finalNetNotional;
      final liqPrice = _liquidationPriceCalculated;

      final txData = {
        'type': _selectedType,
        'coinId': canonicalId,
        'symbol': _selectedSymbol.toUpperCase(),
        'name': _selectedCoinName,
        'amount': parsedAmt,
        'pricePerUnit': parsedPrice,
        'totalAmount': finalNetNotional,
        'fee': parsedFee,
        'transactionDate': _selectedDate.toIso8601String(),
        'notes': _notesController.text.trim(),
        'originalCurrency': currency.code,
        'originalAmount': parsedAmt,
        'fxToBase': 1.0 / (currency.rateToUsd > 0 ? currency.rateToUsd : 1.0),
        'leverage': _isFuturesMode ? _leverage : 1.0,
        'margin': _isFuturesMode ? margin : null,
        'liquidationPrice': _isFuturesMode && liqPrice > 0 ? liqPrice : null,
      };

      bool success;
      if (_isEditing) {
        success = await ref
            .read(transactionsProvider.notifier)
            .updateTransaction(widget.transactionToEdit!.id, txData);
      } else {
        success = await ref.read(transactionsProvider.notifier).addTransaction(txData);
      }

      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isEditing ? 'Transaction updated successfully!' : 'Order saved to portfolio!'),
              backgroundColor: AppColors.profit,
            ),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save transaction'),
              backgroundColor: AppColors.loss,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.loss),
        );
      }
    }
  }

  Future<void> _delete() async {
    final surfaceColor = AppColors.surface(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surfaceColor,
        title: Text('Delete Transaction', style: TextStyle(color: textPrimary)),
        content: Text(
          'Are you sure you want to delete this transaction? Your portfolio holdings will automatically be recalculated.',
          style: TextStyle(color: textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.loss),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _isLoading = true);
      final success = await ref
          .read(transactionsProvider.notifier)
          .deleteTransaction(widget.transactionToEdit!.id);

      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Transaction deleted & DCA updated!'),
              backgroundColor: AppColors.profit,
            ),
          );
          Navigator.pop(context);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = AppColors.background(context);
    final surfaceColor = AppColors.surface(context);
    final surfaceLight = AppColors.surfaceLight(context);
    final borderColor = AppColors.border(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final textMuted = AppColors.textMuted(context);
    final tickersAsync = ref.watch(binanceTickersProvider);
    final currency = ref.watch(currencyProvider);
    final currentTicker = ref.read(binanceTickersProvider.notifier).getTickerBySymbol(_selectedSymbol);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final portfolioAsync = ref.watch(portfolioSummaryProvider);

    // Look up available holding balance for selected asset
    double availableQty = widget.prefilledAmount ?? 0.0;
    final holdings = portfolioAsync.asData?.value.holdings;
    if (holdings != null) {
      for (final h in holdings) {
        if (h.coinId.toLowerCase() == _selectedCoinId.toLowerCase() ||
            h.symbol.toUpperCase() == _selectedSymbol.toUpperCase()) {
          availableQty = h.totalQuantity;
          break;
        }
      }
    }

    final isLongDirection = _selectedType == 'BUY' || _selectedType == 'LONG';
    final isSellMode = _selectedType == 'SELL' || _selectedType == 'SHORT';
    final ladderSteps = _enableLaddering ? _generateLadderSteps() : <LadderStepItem>[];
    final totalLadderNotional = ladderSteps.fold<double>(0.0, (sum, s) => sum + s.notionalUsdt);
    final totalLadderQty = ladderSteps.fold<double>(0.0, (sum, s) => sum + s.amount);
    final blendedAvgPrice = totalLadderQty > 0 ? (totalLadderNotional / totalLadderQty) : 0.0;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text(
          _isEditing
              ? 'Edit ${_isFuturesMode ? "Futures Position" : "Crypto Order"}'
              : (_isFuturesMode ? 'Futures & Leverage DCA' : 'Spot DCA Accumulation'),
          style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(Icons.close, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline, color: AppColors.loss),
              onPressed: _isLoading ? null : _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          children: [
            // 1. MARKET MODE SELECTOR (SPOT TRADING vs FUTURES WITH LEVERAGE)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _modeSegment(
                      label: 'SPOT (1x Spot)',
                      icon: Icons.storefront_outlined,
                      isSelected: !_isFuturesMode,
                      activeColor: AppColors.primary,
                      onTap: () => _toggleMarketMode(false),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _modeSegment(
                      label: 'FUTURES (Leverage)',
                      icon: Icons.bolt_rounded,
                      isSelected: _isFuturesMode,
                      activeColor: const Color(0xFFF0B90B), // Binance Gold
                      onTap: () => _toggleMarketMode(true),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 2. DIRECTION SELECTOR: SPOT (BUY / SELL) or FUTURES (LONG / SHORT)
            Container(
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  if (!_isFuturesMode) ...[
                    _typeTab('BUY', 'DCA Buy (Spot)', AppColors.profit, textSecondary),
                    _typeTab('SELL', 'Sell / Take Profit', AppColors.loss, textSecondary),
                  ] else ...[
                    _typeTab('LONG', 'LONG / Buy ↗', const Color(0xFF00C087), textSecondary),
                    _typeTab('SHORT', 'SHORT / Sell ↘', const Color(0xFFFF4D4F), textSecondary),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 3. BINANCE ASSET SELECTOR
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Trading Pair (Binance Live)',
                    style: TextStyle(color: textSecondary, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _openCoinPickerSheet(context, tickersAsync.valueOrNull ?? []),
                  icon: const Icon(Icons.search, size: 14, color: AppColors.primary),
                  label: const Text('Browse 400+ Coins',
                      style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: () => _openCoinPickerSheet(context, tickersAsync.valueOrNull ?? []),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primary.withAlpha(90)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.primaryGlow,
                      child: Text(
                        _selectedSymbol.length > 3 ? _selectedSymbol.substring(0, 3) : _selectedSymbol,
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('$_selectedSymbol / USDT',
                                  style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                              if (_isFuturesMode) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0B90B).withAlpha(35),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFFF0B90B).withAlpha(120), width: 0.8),
                                  ),
                                  child: const Text('PERP',
                                      style: TextStyle(
                                          color: Color(0xFFF0B90B), fontSize: 9, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ],
                          ),
                          Text(_selectedCoinName, style: TextStyle(color: textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                    if (currentTicker != null && currentTicker.price > 0) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(Formatters.currency(currentTicker.price, currency),
                              style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                          Text(
                            Formatters.percentage(currentTicker.priceChangePercent),
                            style: TextStyle(
                              color: currentTicker.priceChangePercent >= 0 ? AppColors.profit : AppColors.loss,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                    ],
                    Icon(Icons.unfold_more, color: textMuted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // 4. FUTURES LEVERAGE SELECTOR (IF IN FUTURES MODE)
            if (_isFuturesMode) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFF0B90B).withAlpha(90)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.speed_rounded, color: Color(0xFFF0B90B), size: 18),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text('Leverage Multiplier',
                                    style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0B90B).withAlpha(40),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFF0B90B)),
                          ),
                          child: Text(
                            '${_leverage.toInt()}x Leverage',
                            style: const TextStyle(
                                color: Color(0xFFF0B90B), fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Quick Leverage Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [2, 3, 5, 10, 20, 50, 75, 100].map((lev) {
                          final isSel = _leverage.toInt() == lev;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: InkWell(
                              onTap: () => setState(() => _leverage = lev.toDouble()),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSel ? const Color(0xFFF0B90B) : surfaceLight,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: isSel ? const Color(0xFFF0B90B) : borderColor),
                                ),
                                child: Text(
                                  '${lev}x',
                                  style: TextStyle(
                                    color: isSel ? Colors.black : textSecondary,
                                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Precision Slider
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: const Color(0xFFF0B90B),
                        inactiveTrackColor: borderColor,
                        thumbColor: const Color(0xFFF0B90B),
                        overlayColor: const Color(0xFFF0B90B).withAlpha(40),
                        trackHeight: 3,
                      ),
                      child: Slider(
                        value: _leverage,
                        min: 1.0,
                        max: 100.0,
                        divisions: 99,
                        onChanged: (val) => setState(() => _leverage = val.roundToDouble()),
                      ),
                    ),
                    // Risk Indicator Card
                    _leverageRiskBadge(_leverage),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],

            // 5. POSITION SELLING HUB (IN SPOT SELL MODE)
            if (!_isFuturesMode && _selectedType == 'SELL' && availableQty > 0) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.loss.withAlpha(isDark ? 28 : 16),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.loss.withAlpha(isDark ? 90 : 50),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.loss.withAlpha(40),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.account_balance_wallet, size: 16, color: AppColors.loss),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Available Position to Sell', style: TextStyle(color: textSecondary, fontSize: 11)),
                                Text(
                                  '${Formatters.cryptoAmount(availableQty)} $_selectedSymbol',
                                  style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (currentTicker != null && currentTicker.price > 0 && availableQty > 0)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('Total Position Value', style: TextStyle(color: textMuted, fontSize: 11)),
                              Text(
                                Formatters.currency(availableQty * currentTicker.price, currency),
                                style: const TextStyle(color: AppColors.profit, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Quick Sell Portions (Partial or Full):',
                      style: TextStyle(color: textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _sellPortionButton('25%', 0.25, availableQty),
                        const SizedBox(width: 6),
                        _sellPortionButton('50%', 0.50, availableQty),
                        const SizedBox(width: 6),
                        _sellPortionButton('75%', 0.75, availableQty),
                        const SizedBox(width: 6),
                        _sellPortionButton('100% (All)', 1.00, availableQty, isFull: true),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 6. QUICK DCA CAPITAL ACCUMULATION CHIPS
            if (isLongDirection) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _isFuturesMode ? r'Quick Margin Inflow ($):' : r'Quick DCA Capital Accumulation ($):',
                          style: TextStyle(color: textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Tap preset to apply',
                        style: TextStyle(color: textMuted, fontSize: 10),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [25, 50, 100, 200, 250, 500, 1000].map((amt) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _inputMode = 'USDT';
                                final notional = _isFuturesMode ? (amt * _leverage) : amt.toDouble();
                                _usdtAmountController.text = notional.toStringAsFixed(0);
                                _onUsdtAmountChanged(notional.toString());
                              });
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primaryGlow,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.primary.withAlpha(80)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 12),
                                  const SizedBox(width: 4),
                                  Text(
                                    '\$$amt',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ],

            // 7. INPUT MODE TABS (USDT Notional vs Coin Units)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Order Input Mode',
                    style: TextStyle(color: textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      _modeTab('USDT', r'By USDT ($)', surfaceLight),
                      _modeTab('COIN', 'By $_selectedSymbol', surfaceLight),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // PRIMARY INPUT FIELD
            if (_inputMode == 'USDT') ...[
              Text(
                _isFuturesMode ? 'Gross Investment / Notional (USDT)' : 'Total Investment Capital in USDT',
                style: TextStyle(color: textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _usdtAmountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.attach_money, color: AppColors.primary),
                  filled: true,
                  fillColor: surfaceColor,
                  hintText: 'e.g. 500.00',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                  suffixText: 'USDT',
                  suffixStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                ),
                validator: (v) => (v == null || double.tryParse(v) == null) ? 'Enter valid USDT amount' : null,
                onChanged: _onUsdtAmountChanged,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Net Order Size: ${_amountController.text.isNotEmpty ? _amountController.text : "0"} $_selectedSymbol (Fee Deducted)',
                      style: TextStyle(color: textMuted, fontSize: 11.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_isFuturesMode) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Margin: ${Formatters.currency(_marginCalculated, currency)}',
                        style: const TextStyle(color: Color(0xFFF0B90B), fontSize: 11.5, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ],
              ),
            ] else ...[
              Text('Coin Units ($_selectedSymbol)', style: TextStyle(color: textSecondary, fontSize: 13)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.currency_bitcoin, color: AppColors.primary),
                  filled: true,
                  fillColor: surfaceColor,
                  hintText: 'e.g. 0.05',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                  suffixText: _selectedSymbol,
                  suffixStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                ),
                validator: (v) => (v == null || double.tryParse(v) == null) ? 'Enter valid coin units' : null,
                onChanged: _onCoinAmountChanged,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Notional Total: ${_usdtAmountController.text.isNotEmpty ? _usdtAmountController.text : "0"} USDT',
                      style: TextStyle(color: textMuted, fontSize: 11.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_isFuturesMode) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Margin: ${Formatters.currency(_marginCalculated, currency)}',
                        style: const TextStyle(color: Color(0xFFF0B90B), fontSize: 11.5, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 18),

            // 8. ASSET UNIT PRICE
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    isSellMode ? 'Exit / Sell Price (USDT)' : 'Entry / Unit Price (USDT)',
                    style: TextStyle(
                      color: isSellMode ? AppColors.loss : textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (currentTicker != null && currentTicker.price > 0)
                  Flexible(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      onPressed: () {
                        _priceController.text = currentTicker.price.toString();
                        _onPriceChanged(currentTicker.price.toString());
                      },
                      icon: Icon(Icons.bolt, color: isSellMode ? AppColors.loss : AppColors.primary, size: 14),
                      label: Text(
                        'Market: ${currentTicker.price}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSellMode ? AppColors.loss : AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: textPrimary, fontSize: 16),
              decoration: InputDecoration(
                filled: true,
                fillColor: surfaceColor,
                hintText: isSellMode ? 'Enter sell execution price (e.g. 68000.00)' : 'e.g. 68000.00',
                hintStyle: TextStyle(color: textMuted),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
              ),
              validator: (v) => (v == null || double.tryParse(v) == null) ? 'Enter valid price' : null,
              onChanged: _onPriceChanged,
            ),
            const SizedBox(height: 18),

            // 9. LIQUIDATION & MARGIN CARD (FOR FUTURES)
            if (_isFuturesMode) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.loss.withAlpha(isDark ? 22 : 14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.loss.withAlpha(80)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: AppColors.loss, size: 18),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text('Est. Liquidation Price:',
                                    style: TextStyle(color: textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          Formatters.currency(_liquidationPriceCalculated, currency),
                          style: const TextStyle(color: AppColors.loss, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Distance to Liquidation:',
                            style: TextStyle(color: textMuted, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_liquidationDistancePercent >= 0 ? "+" : ""}${_liquidationDistancePercent.toStringAsFixed(2)}%',
                          style: TextStyle(
                            color: _liquidationDistancePercent.abs() < 10 ? AppColors.loss : AppColors.profit,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],

            // 10. DCA LADDERING BUILDER (FOR BOTH SPOT & FUTURES)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _enableLaddering ? AppColors.primary : borderColor,
                  width: _enableLaddering ? 1.5 : 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.stacked_line_chart_rounded,
                              color: _enableLaddering ? AppColors.primary : textMuted,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'DCA Laddering Orders',
                                    style: TextStyle(
                                      color: textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    _isFuturesMode
                                        ? 'Scale-in leverage entries with better avg entry'
                                        : 'Stagger spot buys into the dip systematically',
                                    style: TextStyle(color: textMuted, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Switch.adaptive(
                        value: _enableLaddering,
                        activeThumbColor: AppColors.primary,
                        activeTrackColor: AppColors.primary.withAlpha(120),
                        onChanged: (val) => setState(() => _enableLaddering = val),
                      ),
                    ],
                  ),
                  if (_enableLaddering) ...[
                    const SizedBox(height: 16),
                    Divider(color: borderColor, height: 1),
                    const SizedBox(height: 14),

                    // Number of Orders / Steps
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Number of Orders (Steps)',
                            style: TextStyle(color: textSecondary, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('$_ladderSteps Orders',
                            style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [2, 3, 4, 5, 6, 8].map((s) {
                        final isSel = _ladderSteps == s;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: InkWell(
                              onTap: () => setState(() => _ladderSteps = s),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSel ? AppColors.primary : surfaceLight,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: isSel ? AppColors.primary : borderColor),
                                ),
                                child: Text(
                                  '$s',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isSel ? Colors.white : textSecondary,
                                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Price Interval / Spread %
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            isLongDirection ? 'Price Drop Interval per Step' : 'Price Rise Interval per Step',
                            style: TextStyle(color: textSecondary, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('${_ladderSpreadPercent.toStringAsFixed(1)}% Spacing',
                            style: const TextStyle(
                                color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [1.0, 1.5, 2.0, 3.0, 5.0].map((spread) {
                        final isSel = (_ladderSpreadPercent - spread).abs() < 0.01;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: InkWell(
                              onTap: () => setState(() => _ladderSpreadPercent = spread),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSel ? AppColors.primary : surfaceLight,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: isSel ? AppColors.primary : borderColor),
                                ),
                                child: Text(
                                  '$spread%',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isSel ? Colors.white : textSecondary,
                                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Capital Weight Distribution
                    Text('Capital Distribution Strategy', style: TextStyle(color: textSecondary, fontSize: 12)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _distributionChip('EQUAL', 'Equal Weight (1:1)'),
                        const SizedBox(width: 6),
                        _distributionChip('MARTINGALE', 'Martingale (1.4x)'),
                        const SizedBox(width: 6),
                        _distributionChip('PYRAMIDAL', 'Pyramidal (Scaled)'),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // LIVE LADDER PREVIEW TABLE
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text('LADDER PLAN PREVIEW',
                                    style: TextStyle(
                                        color: textPrimary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${ladderSteps.length} Orders Planned',
                                style: const TextStyle(
                                    color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ...ladderSteps.map((step) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  Container(
                                    width: 20,
                                    height: 20,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryGlow,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '#${step.step}',
                                      style: const TextStyle(
                                          color: AppColors.primary, fontSize: 9.5, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '${Formatters.currency(step.price, currency)} (${step.priceDeviationPercent >= 0 ? "+" : ""}${step.priceDeviationPercent.toStringAsFixed(1)}%)',
                                      style: TextStyle(
                                          color: textPrimary, fontSize: 11.5, fontWeight: FontWeight.w600),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      '${Formatters.cryptoAmount(step.amount)} $_selectedSymbol',
                                      style: TextStyle(color: textSecondary, fontSize: 10.5),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.end,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    Formatters.currency(
                                        _isFuturesMode ? step.margin : step.notionalUsdt, currency),
                                    style: TextStyle(
                                      color: _isFuturesMode ? const Color(0xFFF0B90B) : textPrimary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          Divider(color: borderColor, height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text('Blended Avg Entry Price:',
                                    style: TextStyle(color: textSecondary, fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                Formatters.currency(blendedAvgPrice, currency),
                                style: const TextStyle(
                                    color: AppColors.profit, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          if (_isFuturesMode) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text('Effective Ladder Liq Price:',
                                      style: TextStyle(color: textSecondary, fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  Formatters.currency(
                                    isLongDirection
                                        ? blendedAvgPrice * (1.0 - (1.0 / _leverage) + 0.005)
                                        : blendedAvgPrice * (1.0 + (1.0 / _leverage) - 0.005),
                                    currency,
                                  ),
                                  style: const TextStyle(
                                      color: AppColors.loss, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Checkbox to save batch
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      activeColor: AppColors.primary,
                      title: Text(
                        'Save all $_ladderSteps ladder orders into transaction history',
                        style: TextStyle(color: textPrimary, fontSize: 12),
                      ),
                      value: _saveAllLadderOrders,
                      onChanged: (v) => setState(() => _saveAllLadderOrders = v ?? true),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 11. TRADING FEE SECTION
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Trading Fee (%)',
                    style: TextStyle(color: textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Fee Cost: ${_feeCalculated.toStringAsFixed(2)} USDT',
                  style: const TextStyle(color: AppColors.loss, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _feePercentController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      suffixText: '%',
                      prefixIcon: const Icon(Icons.percent, size: 16, color: AppColors.primary),
                      filled: true,
                      fillColor: surfaceColor,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                    ),
                    onChanged: (_) {
                      _recalculateFee();
                      setState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _feeChip('0.0%', 0.0, surfaceLight, borderColor, textSecondary),
                        _feeChip('0.02%', 0.02, surfaceLight, borderColor, textSecondary),
                        _feeChip('0.05%', 0.05, surfaceLight, borderColor, const Color(0xFFF0B90B)),
                        _feeChip('0.10%', 0.10, surfaceLight, borderColor, AppColors.primary),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 12. ORDER SUMMARY CARD
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surfaceLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isFuturesMode ? 'Gross Position Notional:' : 'Gross Investment Capital:',
                        style: TextStyle(color: textSecondary, fontSize: 13),
                      ),
                      Text(
                        Formatters.currency(_grossInvestmentCapital, currency),
                        style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  if (_isFuturesMode) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text('Initial Collateral (${_leverage.toInt()}x Leverage):',
                              style: TextStyle(color: textSecondary, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          Formatters.currency(_grossInvestmentCapital / _leverage, currency),
                          style: const TextStyle(
                              color: Color(0xFFF0B90B), fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text('Trading Fee (${_feePercentController.text}%):',
                              style: TextStyle(color: textSecondary, fontSize: 12)),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.loss.withAlpha(25),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('Deducted',
                                style: TextStyle(color: AppColors.loss, fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      Text(
                        '-${Formatters.currency(_feeCalculated, currency)}',
                        style: const TextStyle(color: AppColors.loss, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedType == 'BUY' || _selectedType == 'LONG'
                            ? 'Net Crypto Value ($_selectedSymbol Bought):'
                            : 'Net Crypto Position Value:',
                        style: TextStyle(color: textSecondary, fontSize: 12),
                      ),
                      Text(
                        Formatters.currency(_netCryptoExecutionValue, currency),
                        style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  Divider(color: borderColor, height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _isFuturesMode
                              ? 'Net Margin Outflow:'
                              : (_selectedType == 'BUY' ? 'Total Capital Outflow:' : 'Net Proceeds Received:'),
                          style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        Formatters.currency(
                          _isFuturesMode
                              ? _marginCalculated
                              : _netCryptoExecutionValue,
                          currency,
                        ),
                        style: TextStyle(
                          color: _isFuturesMode
                              ? const Color(0xFFF0B90B)
                              : (_selectedType == 'BUY' ? AppColors.primary : AppColors.profit),
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 13. DATE SELECTOR
            Text('Transaction Date', style: TextStyle(color: textSecondary, fontSize: 13)),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                );
                if (picked != null) {
                  setState(() => _selectedDate = picked);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      Formatters.date(_selectedDate),
                      style: TextStyle(color: textPrimary, fontSize: 15),
                    ),
                    const Icon(Icons.calendar_today, color: AppColors.primary, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // 14. STRATEGY NOTES & MEMO
            Text('Strategy Notes', style: TextStyle(color: textSecondary, fontSize: 13)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              style: TextStyle(color: textPrimary),
              decoration: InputDecoration(
                filled: true,
                fillColor: surfaceColor,
                hintText: _isFuturesMode
                    ? 'e.g. 10x BTC Long breakout, laddered stop & scale-in'
                    : 'e.g. Weekly dip accumulation, DCA ladder plan',
                hintStyle: TextStyle(color: textMuted),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
              ),
            ),
            const SizedBox(height: 28),

            // 15. SUBMIT BUTTON
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isFuturesMode
                    ? (isLongDirection ? const Color(0xFF00C087) : const Color(0xFFFF4D4F))
                    : AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isLoading ? null : _submit,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(
                      _isEditing
                          ? 'Update Transaction'
                          : (_enableLaddering && _saveAllLadderOrders
                              ? 'Place $_ladderSteps Ladder Orders'
                              : (_isFuturesMode
                                  ? 'Place $_selectedType Order (${_leverage.toInt()}x)'
                                  : 'Save DCA $_selectedType')),
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _modeSegment({
    required String label,
    required IconData icon,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withAlpha(35) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isSelected ? Border.all(color: activeColor, width: 1.5) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? activeColor : AppColors.textMuted(context)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? activeColor : AppColors.textSecondary(context),
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeTab(String type, String label, Color color, Color defaultTextColor) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedType = type;
            if (type == 'SELL' || type == 'SHORT') {
              _inputMode = 'COIN';
            }
            _recalculateFee();
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color.withAlpha(40) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected ? Border.all(color: color) : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? color : defaultTextColor,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _leverageRiskBadge(double lev) {
    Color riskColor;
    String riskLabel;
    if (lev <= 5) {
      riskColor = AppColors.profit;
      riskLabel = 'Low Risk • Conservative DCA margin';
    } else if (lev <= 15) {
      riskColor = const Color(0xFFF0B90B);
      riskLabel = 'Moderate Risk • Standard futures leverage';
    } else if (lev <= 30) {
      riskColor = Colors.orange;
      riskLabel = 'High Risk • Tight liquidation window';
    } else {
      riskColor = AppColors.loss;
      riskLabel = 'Extreme Risk • High volatility liquidation';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: riskColor.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.shield_outlined, size: 14, color: riskColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              riskLabel,
              style: TextStyle(color: riskColor, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _distributionChip(String key, String label) {
    final isSel = _ladderDistribution == key;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _ladderDistribution = key),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isSel ? AppColors.primaryGlow : AppColors.surfaceLight(context),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSel ? AppColors.primary : AppColors.border(context),
              width: isSel ? 1.5 : 1.0,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isSel ? AppColors.primary : AppColors.textSecondary(context),
              fontSize: 10,
              fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _modeTab(String mode, String label, Color surfaceLight) {
    final isSelected = _inputMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() {
          _inputMode = mode;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary(context),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _feeChip(String label, double pct, Color bg, Color border, Color textColor) {
    final currentFeePct = double.tryParse(_feePercentController.text) ?? -1.0;
    final isSelected = (currentFeePct - pct).abs() < 0.001;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () => _applyFeePercentage(pct),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryGlow : bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppColors.primary : border,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? AppColors.primary : textColor,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  void _openCoinPickerSheet(BuildContext context, List<BinanceTickerModel> tickers) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _SearchableCoinSheet(
        tickers: tickers,
        onSelected: (coin) {
          Navigator.pop(ctx);
          setState(() {
            _selectedSymbol = coin.symbol.toUpperCase();
            _selectedCoinName = coin.name;
            _selectedCoinId = AssetMapper.getCanonicalCoinId(coin.symbol);
            if (coin.price > 0) {
              _priceController.text = coin.price.toString();
              _onPriceChanged(coin.price.toString());
            }
          });
        },
      ),
    );
  }

  Widget _sellPortionButton(String label, double fraction, double totalAvailable, {bool isFull = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: InkWell(
        onTap: () {
          final targetQty = totalAvailable > 0 ? (totalAvailable * fraction) : 0.0;
          final unitPrice = double.tryParse(_priceController.text) ?? 0.0;
          setState(() {
            _inputMode = 'COIN';
            if (isFull) {
              _amountController.text = totalAvailable.toString();
            } else {
              _amountController.text = targetQty.toString();
            }
            if (unitPrice > 0) {
              final totalUsdt = (isFull ? totalAvailable : targetQty) * unitPrice;
              _usdtAmountController.text = totalUsdt.toStringAsFixed(2);
            }
            _recalculateFee();
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isFull
                ? AppColors.loss.withAlpha(isDark ? 55 : 35)
                : (isDark ? const Color(0xFF1B1C22) : Colors.white),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.loss.withAlpha(isFull ? (isDark ? 160 : 120) : (isDark ? 90 : 50)),
              width: isFull ? 1.4 : 1.0,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isFull ? AppColors.loss : AppColors.textPrimary(context),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchableCoinSheet extends StatefulWidget {
  final List<BinanceTickerModel> tickers;
  final ValueChanged<BinanceTickerModel> onSelected;

  const _SearchableCoinSheet({required this.tickers, required this.onSelected});

  @override
  State<_SearchableCoinSheet> createState() => _SearchableCoinSheetState();
}

class _SearchableCoinSheetState extends State<_SearchableCoinSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final borderColor = AppColors.border(context);

    final filtered = widget.tickers.where((t) {
      final q = _query.toLowerCase();
      return t.symbol.toLowerCase().contains(q) || t.name.toLowerCase().contains(q);
    }).toList();

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: EdgeInsets.only(
          top: 16,
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Select from 400+ Binance Coins',
                    style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              style: TextStyle(color: textPrimary),
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search symbol or name (e.g. BTC, SOL, PEPE, SUI)...',
                prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                filled: true,
                fillColor: AppColors.surfaceLight(context),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (context, index) => Divider(color: borderColor, height: 1),
                itemBuilder: (context, index) {
                  final coin = filtered[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primaryGlow,
                      child: Text(
                        coin.symbol.length > 3 ? coin.symbol.substring(0, 3) : coin.symbol,
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                    title: Text(coin.symbol, style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold)),
                    subtitle: Text(coin.name, style: TextStyle(color: textSecondary, fontSize: 11)),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(Formatters.currency(coin.price),
                            style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                        Text(
                          Formatters.percentage(coin.priceChangePercent),
                          style: TextStyle(
                            color: coin.priceChangePercent >= 0 ? AppColors.profit : AppColors.loss,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    onTap: () => widget.onSelected(coin),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
