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

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();

  late String _selectedType;
  String _selectedCoinId = 'bitcoin';
  String _selectedSymbol = 'BTC';
  String _selectedCoinName = 'Bitcoin';
  String _inputMode = 'USDT'; // 'USDT' or 'COIN'

  late TextEditingController _amountController; // Coin quantity
  late TextEditingController _usdtAmountController; // Total in USDT ($)
  late TextEditingController _priceController; // Unit price
  late TextEditingController _feePercentController; // Fee percentage (e.g. 0.1)
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
      _selectedType = edit.type;
      _selectedCoinId = edit.coinId ?? 'bitcoin';
      _selectedSymbol = edit.symbol ?? 'BTC';
      _selectedCoinName = edit.name ?? 'Bitcoin';
      _amountController = TextEditingController(text: edit.amount.toString());
      _priceController = TextEditingController(text: edit.pricePerUnit.toString());
      final totalUsdt = edit.amount * edit.pricePerUnit;
      _usdtAmountController = TextEditingController(text: totalUsdt > 0 ? totalUsdt.toStringAsFixed(2) : '');
      final feeDollars = edit.fee;
      final feePct = totalUsdt > 0 ? (feeDollars / totalUsdt) * 100 : 0.1;
      _feePercentController = TextEditingController(text: feePct.toStringAsFixed(3));
      _feeController = TextEditingController(text: feeDollars.toStringAsFixed(2));
      _notesController = TextEditingController(text: edit.notes);
      _selectedDate = edit.transactionDate;
    } else if (widget.preselectedCoinId != null) {
      _selectedType = widget.initialType;
      _selectedCoinId = widget.preselectedCoinId!;
      _selectedSymbol = widget.preselectedSymbol ?? widget.preselectedCoinId!.toUpperCase();
      _selectedCoinName = widget.preselectedCoinName ?? _selectedSymbol;
      final p = (widget.prefilledPrice != null && widget.prefilledPrice! > 0)
          ? widget.prefilledPrice!
          : 68420.50;
      _priceController = TextEditingController(text: p.toString());

      if (widget.initialType == 'SELL' && widget.prefilledAmount != null && widget.prefilledAmount! > 0) {
        _inputMode = 'COIN';
        final qty = widget.prefilledAmount!;
        _amountController = TextEditingController(text: Formatters.cryptoAmount(qty).replaceAll(',', ''));
        final totalVal = qty * p;
        _usdtAmountController = TextEditingController(text: totalVal.toStringAsFixed(2));
      } else {
        _inputMode = 'USDT';
        _usdtAmountController = TextEditingController(text: '100');
        final qty = 100 / p;
        _amountController = TextEditingController(text: qty >= 1 ? qty.toStringAsFixed(4) : qty.toStringAsFixed(6));
      }
      _feePercentController = TextEditingController(text: '0.1');
      final currentTotal = (double.tryParse(_amountController.text) ?? 0.0) * p;
      _feeController = TextEditingController(text: (currentTotal * 0.001).toStringAsFixed(2));
      _notesController = TextEditingController();
    } else if (preselected != null) {
      _selectedType = widget.initialType;
      _selectedCoinId = preselected.symbol.toLowerCase();
      _selectedSymbol = preselected.symbol;
      _selectedCoinName = preselected.name;
      _usdtAmountController = TextEditingController(text: '100');
      final p = preselected.price > 0 ? preselected.price : 68420.50;
      _priceController = TextEditingController(text: p.toString());
      final qty = 100 / p;
      _amountController = TextEditingController(text: qty >= 1 ? qty.toStringAsFixed(4) : qty.toStringAsFixed(6));
      _feePercentController = TextEditingController(text: '0.1');
      _feeController = TextEditingController(text: (100 * 0.001).toStringAsFixed(2));
      _notesController = TextEditingController();
    } else {
      _selectedType = widget.initialType;
      _usdtAmountController = TextEditingController(text: '100');
      _priceController = TextEditingController(text: '68420.50');
      final qty = 100 / 68420.50;
      _amountController = TextEditingController(text: qty >= 1 ? qty.toStringAsFixed(4) : qty.toStringAsFixed(6));
      _feePercentController = TextEditingController(text: '0.1');
      _feeController = TextEditingController(text: (100 * 0.001).toStringAsFixed(2));
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

  double get _feeCalculated {
    return double.tryParse(_feeController.text) ?? 0.0;
  }

  void _onUsdtAmountChanged(String val) {
    final usdt = double.tryParse(val) ?? 0.0;
    final price = double.tryParse(_priceController.text) ?? 0.0;
    if (price > 0) {
      final qty = usdt / price;
      _amountController.text = qty > 0 ? (qty >= 1 ? qty.toStringAsFixed(4) : qty.toStringAsFixed(6)) : '';
    }
    _recalculateFee();
    setState(() {});
  }

  void _onCoinAmountChanged(String val) {
    final qty = double.tryParse(val) ?? 0.0;
    final price = double.tryParse(_priceController.text) ?? 0.0;
    final usdt = qty * price;
    _usdtAmountController.text = usdt > 0 ? (usdt >= 1 ? usdt.toStringAsFixed(2) : usdt.toStringAsFixed(4)) : '';
    _recalculateFee();
    setState(() {});
  }

  void _onPriceChanged(String val) {
    final price = double.tryParse(val) ?? 0.0;
    if (_inputMode == 'USDT') {
      final usdt = double.tryParse(_usdtAmountController.text) ?? 0.0;
      if (price > 0) {
        final qty = usdt / price;
        _amountController.text = qty > 0 ? (qty >= 1 ? qty.toStringAsFixed(4) : qty.toStringAsFixed(6)) : '';
      }
    } else {
      final qty = double.tryParse(_amountController.text) ?? 0.0;
      final usdt = qty * price;
      _usdtAmountController.text = usdt > 0 ? (usdt >= 1 ? usdt.toStringAsFixed(2) : usdt.toStringAsFixed(4)) : '';
    }
    _recalculateFee();
    setState(() {});
  }

  void _recalculateFee() {
    final orderVal = _totalCalculated;
    final pct = double.tryParse(_feePercentController.text) ?? 0.0;
    final feeDollars = orderVal * (pct / 100.0);
    _feeController.text = feeDollars > 0 ? (feeDollars >= 0.01 ? feeDollars.toStringAsFixed(2) : feeDollars.toStringAsFixed(4)) : '0.00';
  }

  void _applyFeePercentage(double pct) {
    _feePercentController.text = pct.toString();
    _recalculateFee();
    setState(() {});
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final parsedAmount = double.tryParse(_amountController.text) ?? 0.0;
    if (parsedAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an amount greater than 0.'),
          backgroundColor: AppColors.loss,
        ),
      );
      return;
    }

    if (_selectedType == 'SELL') {
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
    final canonicalId = _selectedType == 'SALARY_DEPOSIT'
        ? null
        : (_selectedCoinId.isNotEmpty
            ? AssetMapper.getCanonicalCoinId(_selectedCoinId)
            : AssetMapper.getCanonicalCoinId(_selectedSymbol));

    final txData = {
      'type': _selectedType,
      'coinId': canonicalId,
      'symbol': _selectedType == 'SALARY_DEPOSIT' ? null : _selectedSymbol.toUpperCase(),
      'name': _selectedType == 'SALARY_DEPOSIT' ? null : _selectedCoinName,
      'amount': double.parse(_amountController.text),
      'pricePerUnit': _selectedType == 'SALARY_DEPOSIT' ? 1.0 : double.parse(_priceController.text),
      'fee': double.tryParse(_feeController.text) ?? 0.0,
      'transactionDate': _selectedDate.toIso8601String(),
      'notes': _notesController.text.trim(),
      'originalCurrency': currency.code,
      'originalAmount': double.parse(_amountController.text),
      'fxToBase': 1.0 / (currency.rateToUsd > 0 ? currency.rateToUsd : 1.0),
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
            content: Text(_isEditing ? 'Transaction updated successfully!' : 'Transaction saved!'),
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
          'Are you sure you want to delete this transaction? Your DCA holdings will automatically be recalculated.',
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

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text(
          _isEditing
              ? 'Edit Transaction'
              : (_selectedType == 'SALARY_DEPOSIT' ? 'Log Salary Inflow' : 'Add Crypto Transaction'),
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
          padding: const EdgeInsets.all(20),
          children: [
            // 1. Transaction Type Selector (BUY | SELL | SALARY_DEPOSIT)
            Container(
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  _typeTab('BUY', 'Buy / DCA', AppColors.profit, textSecondary),
                  _typeTab('SELL', 'Sell', AppColors.loss, textSecondary),
                  _typeTab('SALARY_DEPOSIT', 'Salary Inflow', AppColors.primary, textSecondary),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 2. Binance Asset Selector (if BUY or SELL)
            if (_selectedType != 'SALARY_DEPOSIT') ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Select Asset (Binance Live)', style: TextStyle(color: textSecondary, fontSize: 13)),
                  TextButton.icon(
                    onPressed: () => _openCoinPickerSheet(context, tickersAsync.valueOrNull ?? []),
                    icon: const Icon(Icons.search, size: 14, color: AppColors.primary),
                    label: const Text('Browse 400+ Coins', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
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
                            Text('$_selectedSymbol / USDT', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                            Text(_selectedCoinName, style: TextStyle(color: textSecondary, fontSize: 12)),
                          ],
                        ),
                      ),
                      if (currentTicker != null && currentTicker.price > 0) ...[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(Formatters.currency(currentTicker.price, currency), style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
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
              const SizedBox(height: 20),
            ],

            // 3. Amount & Quantity Inputs (Dual Mode: USDT or Coin)
            if (_selectedType == 'SALARY_DEPOSIT') ...[
              Text('Deposit Amount (USDT)', style: TextStyle(color: textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _usdtAmountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: textPrimary, fontSize: 16),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: surfaceColor,
                  prefixIcon: const Icon(Icons.account_balance_wallet, color: AppColors.primary),
                  hintText: 'e.g. 500.00',
                  hintStyle: TextStyle(color: textMuted),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                ),
                validator: (v) => (v == null || double.tryParse(v) == null) ? 'Enter valid number' : null,
                onChanged: (val) {
                  _amountController.text = val;
                  setState(() {});
                },
              ),
              const SizedBox(height: 20),
            ] else ...[
              // 2.1 Position Selling Hub: Available Balance & Quick Partial/Full Sell Buttons
              if (_selectedType == 'SELL' && availableQty > 0) ...[
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
                      const SizedBox(height: 12),
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
                          _sellPortionButton('100% (Full)', 1.00, availableQty, isFull: true),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 2.2 Quick DCA Capital Accumulation Chips (in BUY mode)
              if (_selectedType == 'BUY') ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Quick DCA Capital:', style: TextStyle(color: textSecondary, fontSize: 12)),
                    Row(
                      children: [25, 50, 100, 250].map((amt) {
                        return Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _inputMode = 'USDT';
                                _usdtAmountController.text = amt.toString();
                                _onUsdtAmountChanged(amt.toString());
                              });
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primaryGlow,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.primary.withAlpha(60)),
                              ),
                              child: Text(
                                '+$amt',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Mode Selector Tabs (By USDT vs By Coin)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Order Input Mode', style: TextStyle(color: textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
                  Container(
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        _modeTab('USDT', 'By USDT', surfaceLight),
                        _modeTab('COIN', 'By $_selectedSymbol Units', surfaceLight),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Primary Input Field
              if (_inputMode == 'USDT') ...[
                Text('Total Investment in USDT', style: TextStyle(color: textSecondary, fontSize: 13)),
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
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                    suffixText: 'USDT',
                    suffixStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                  validator: (v) => (v == null || double.tryParse(v) == null) ? 'Enter valid USDT amount' : null,
                  onChanged: _onUsdtAmountChanged,
                ),
                const SizedBox(height: 10),
                Text('Calculated Coin Quantity: ${_amountController.text.isNotEmpty ? _amountController.text : "0"} $_selectedSymbol', style: TextStyle(color: textMuted, fontSize: 12)),
              ] else ...[
                Text('Coin Units to ${_selectedType == "BUY" ? "Buy" : "Sell"} ($_selectedSymbol)', style: TextStyle(color: textSecondary, fontSize: 13)),
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
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                    suffixText: _selectedSymbol,
                    suffixStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                  validator: (v) => (v == null || double.tryParse(v) == null) ? 'Enter valid coin units' : null,
                  onChanged: _onCoinAmountChanged,
                ),
                const SizedBox(height: 10),
                Text('Calculated USDT Total: ${_usdtAmountController.text.isNotEmpty ? _usdtAmountController.text : "0"} USDT', style: TextStyle(color: textMuted, fontSize: 12)),
              ],
              const SizedBox(height: 18),

              // 4. Asset Unit Price
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Asset Unit Price (USDT)', style: TextStyle(color: textSecondary, fontSize: 13)),
                  if (currentTicker != null && currentTicker.price > 0)
                    TextButton(
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      onPressed: () {
                        _priceController.text = currentTicker.price.toString();
                        _onPriceChanged(currentTicker.price.toString());
                      },
                      child: Text('Fill Live Price (${currentTicker.price} USDT)', style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
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
                  hintText: 'e.g. 68000.00',
                  hintStyle: TextStyle(color: textMuted),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                ),
                validator: (v) => (v == null || double.tryParse(v) == null) ? 'Enter valid price' : null,
                onChanged: _onPriceChanged,
              ),
              const SizedBox(height: 18),

              // 5. Trading Fee Section (Percentage & Amount)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Trading Fee (%)', style: TextStyle(color: textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
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
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
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
                          _feeChip('0.075%', 0.075, surfaceLight, borderColor, textSecondary),
                          _feeChip('0.10%', 0.10, surfaceLight, borderColor, AppColors.primary),
                          _feeChip('0.20%', 0.20, surfaceLight, borderColor, textSecondary),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Order Summary Card
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
                        Text('Gross Order Value:', style: TextStyle(color: textSecondary, fontSize: 13)),
                        Text(
                          Formatters.currency(_totalCalculated, currency),
                          style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Trading Fee (${_feePercentController.text}%):', style: TextStyle(color: textSecondary, fontSize: 12)),
                        Text(
                          '-${Formatters.currency(_feeCalculated, currency)}',
                          style: const TextStyle(color: AppColors.loss, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Divider(color: borderColor, height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedType == 'BUY' ? 'Total Capital Outflow:' : 'Net Proceeds Received:',
                          style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          Formatters.currency(
                            _selectedType == 'BUY' ? (_totalCalculated + _feeCalculated) : (_totalCalculated - _feeCalculated),
                            currency,
                          ),
                          style: TextStyle(
                            color: _selectedType == 'BUY' ? AppColors.primary : AppColors.profit,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Date Selector
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
            const SizedBox(height: 20),

            // 5. Notes & Memo
            Text('Strategy Notes', style: TextStyle(color: textSecondary, fontSize: 13)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              style: TextStyle(color: textPrimary),
              decoration: InputDecoration(
                filled: true,
                fillColor: surfaceColor,
                hintText: 'e.g. October Salary DCA, weekly dip accumulation',
                hintStyle: TextStyle(color: textMuted),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
              ),
            ),
            const SizedBox(height: 32),

            // Submit Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isLoading ? null : _submit,
              child: _isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(
                      _isEditing
                          ? 'Update Transaction'
                          : 'Save ${_selectedType == 'BUY' ? 'DCA Buy' : _selectedType}',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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
        onTap: () => setState(() => _selectedType = type),
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
              _amountController.text = targetQty.toString();
            } else {
              _amountController.text = Formatters.cryptoAmount(targetQty).replaceAll(',', '');
            }
            if (unitPrice > 0) {
              final totalUsdt = targetQty * unitPrice;
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

    return Padding(
      padding: EdgeInsets.only(
        top: 20,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Select from 400+ Binance Coins', style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 12),
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
          const SizedBox(height: 12),
          SizedBox(
            height: 380,
            child: ListView.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, index) => Divider(color: borderColor, height: 1),
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
                      Text(Formatters.currency(coin.price), style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
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
    );
  }
}
