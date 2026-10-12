import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/formatters.dart';
import '../data/models/binance_ticker_model.dart';
import '../providers/binance_provider.dart';
import '../providers/currency_provider.dart';
import 'add_transaction_screen.dart';

class ProfitCalculatorScreen extends ConsumerStatefulWidget {
  final BinanceTickerModel? initialCoin;

  const ProfitCalculatorScreen({super.key, this.initialCoin});

  @override
  ConsumerState<ProfitCalculatorScreen> createState() => _ProfitCalculatorScreenState();
}

class _ProfitCalculatorScreenState extends ConsumerState<ProfitCalculatorScreen> {
  late BinanceTickerModel _selectedCoin;
  late TextEditingController _buyPriceCtrl;
  late TextEditingController _investmentCtrl;
  late TextEditingController _quantityCtrl;
  late TextEditingController _sellPriceCtrl;
  late TextEditingController _feePercentCtrl;

  bool _isQuantityMode = false; // false = by investment amount, true = by crypto amount

  @override
  void initState() {
    super.initState();
    _selectedCoin = widget.initialCoin ??
        const BinanceTickerModel(
          symbol: 'BTC',
          pair: 'BTCUSDT',
          name: 'Bitcoin',
          price: 68420.50,
          priceChangePercent: 2.45,
          highPrice: 69150.0,
          lowPrice: 66800.0,
          quoteVolume: 2450000000.0,
          volume: 35800.0,
        );

    final livePrice = _selectedCoin.price > 0 ? _selectedCoin.price : 68420.50;
    _buyPriceCtrl = TextEditingController(text: livePrice.toString());
    _investmentCtrl = TextEditingController(text: '1000');
    _quantityCtrl = TextEditingController(
      text: (1000 / livePrice).toStringAsFixed(6),
    );
    _sellPriceCtrl = TextEditingController(
      text: (livePrice * 1.5).toStringAsFixed(2),
    );
    _feePercentCtrl = TextEditingController(text: '0.1');
  }

  @override
  void dispose() {
    _buyPriceCtrl.dispose();
    _investmentCtrl.dispose();
    _quantityCtrl.dispose();
    _sellPriceCtrl.dispose();
    _feePercentCtrl.dispose();
    super.dispose();
  }

  void _onCoinChanged(BinanceTickerModel coin) {
    setState(() {
      _selectedCoin = coin;
      if (coin.price > 0) {
        _buyPriceCtrl.text = coin.price.toString();
        _sellPriceCtrl.text = (coin.price * 1.5).toStringAsFixed(2);
        _recalculateFromInvestment();
      }
    });
  }

  void _recalculateFromInvestment() {
    final inv = double.tryParse(_investmentCtrl.text) ?? 0;
    final buyP = double.tryParse(_buyPriceCtrl.text) ?? 0;
    if (buyP > 0) {
      final qty = inv / buyP;
      _quantityCtrl.text = qty.toStringAsFixed(6);
    }
    setState(() {});
  }

  void _recalculateFromQuantity() {
    final qty = double.tryParse(_quantityCtrl.text) ?? 0;
    final buyP = double.tryParse(_buyPriceCtrl.text) ?? 0;
    final inv = qty * buyP;
    _investmentCtrl.text = inv.toStringAsFixed(2);
    setState(() {});
  }

  void _applyTargetMultiple(double multiple) {
    final buyP = double.tryParse(_buyPriceCtrl.text) ?? 0;
    if (buyP > 0) {
      final target = buyP * multiple;
      _sellPriceCtrl.text = target >= 1 ? target.toStringAsFixed(2) : target.toStringAsFixed(6);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(currencyProvider);
    final tickersAsync = ref.watch(binanceTickersProvider);

    final bgColor = AppColors.background(context);
    final surfaceColor = AppColors.surface(context);
    final surfaceLight = AppColors.surfaceLight(context);
    final borderColor = AppColors.border(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final textMuted = AppColors.textMuted(context);

    // Compute Calculations
    final buyPrice = double.tryParse(_buyPriceCtrl.text) ?? 0;
    final sellPrice = double.tryParse(_sellPriceCtrl.text) ?? 0;
    final feePct = (double.tryParse(_feePercentCtrl.text) ?? 0) / 100.0;

    double investmentAmount = 0;
    double coinQuantity = 0;

    if (_isQuantityMode) {
      coinQuantity = double.tryParse(_quantityCtrl.text) ?? 0;
      investmentAmount = coinQuantity * buyPrice;
    } else {
      investmentAmount = double.tryParse(_investmentCtrl.text) ?? 0;
      coinQuantity = buyPrice > 0 ? investmentAmount / buyPrice : 0;
    }

    final grossExitVal = coinQuantity * sellPrice;
    final totalFees = (investmentAmount * feePct) + (grossExitVal * feePct);
    final netExitVal = grossExitVal - (grossExitVal * feePct);
    final netProfit = netExitVal - (investmentAmount + (investmentAmount * feePct));
    final roiPct = investmentAmount > 0 ? (netProfit / investmentAmount) * 100.0 : 0.0;
    final multiple = investmentAmount > 0 ? netExitVal / investmentAmount : 0.0;
    final breakEvenPrice = buyPrice > 0 ? buyPrice * (1 + (feePct * 2)) : 0.0;

    final isProfit = netProfit >= 0;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text(
          'Crypto Profit & ROI Calculator',
          style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Live Asset Selector Banner
            InkWell(
              onTap: () => _openCoinPicker(context, tickersAsync),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withAlpha(90)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.primaryGlow,
                      child: Text(
                        _selectedCoin.symbol.length > 3 ? _selectedCoin.symbol.substring(0, 3) : _selectedCoin.symbol,
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${_selectedCoin.symbol} / USDT',
                                style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _selectedCoin.priceChangePercent >= 0 ? AppColors.profitBg : AppColors.lossBg,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  Formatters.percentage(_selectedCoin.priceChangePercent),
                                  style: TextStyle(
                                    color: _selectedCoin.priceChangePercent >= 0 ? AppColors.profit : AppColors.loss,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Live Market Price: ${Formatters.currency(_selectedCoin.price, currency)}',
                            style: TextStyle(color: textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.unfold_more, color: textMuted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 2. Results Hero Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isProfit
                      ? [const Color(0xFF0D2818), const Color(0xFF05130B)]
                      : [const Color(0xFF2D1115), const Color(0xFF14080A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isProfit ? AppColors.profit.withAlpha(120) : AppColors.loss.withAlpha(120),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'PROJECTED NET PROFIT',
                    style: TextStyle(
                      color: isProfit ? AppColors.profit : AppColors.loss,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${isProfit ? '+' : ''}${Formatters.currency(netProfit, currency)}',
                      style: TextStyle(
                        color: isProfit ? AppColors.profit : AppColors.loss,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (isProfit ? AppColors.profit : AppColors.loss).withAlpha(40),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'ROI: ${roiPct >= 0 ? '+' : ''}${roiPct.toStringAsFixed(2)}%',
                          style: TextStyle(
                            color: isProfit ? AppColors.profit : AppColors.loss,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGlow,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${multiple.toStringAsFixed(2)}x Return',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Divider(color: Colors.white.withAlpha(20)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _kpiItem('Total Investment', Formatters.currency(investmentAmount, currency), textPrimary, textMuted),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _kpiItem('Exit Valuation', Formatters.currency(grossExitVal, currency), textPrimary, textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _kpiItem('Est. Fees', Formatters.currency(totalFees, currency), textPrimary, textMuted),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _kpiItem('Break-Even Price', Formatters.currency(breakEvenPrice, currency), textPrimary, textMuted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 3. Calculator Inputs
            Text('INVESTMENT PARAMETERS', style: TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 12),

            // Entry Price
            _inputField(
              label: 'Buy / Entry Price (USDT)',
              controller: _buyPriceCtrl,
              prefixIcon: Icons.login,
              textColor: textPrimary,
              surfaceColor: surfaceColor,
              borderColor: borderColor,
              suffix: TextButton(
                onPressed: () {
                  if (_selectedCoin.price > 0) {
                    _buyPriceCtrl.text = _selectedCoin.price.toString();
                    _recalculateFromInvestment();
                  }
                },
                child: const Text('Live Price', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              onChanged: (_) {
                if (_isQuantityMode) {
                  _recalculateFromQuantity();
                } else {
                  _recalculateFromInvestment();
                }
              },
            ),
            const SizedBox(height: 14),

            // Mode Selector (Investment vs Quantity)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _isQuantityMode ? 'Coin Quantity (${_selectedCoin.symbol})' : 'Investment Capital (USDT)',
                    style: TextStyle(color: textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => setState(() => _isQuantityMode = !_isQuantityMode),
                  icon: const Icon(Icons.swap_horiz, size: 16, color: AppColors.primary),
                  label: Text(
                    _isQuantityMode ? 'Switch to USDT' : 'Switch to Coins',
                    style: const TextStyle(color: AppColors.primary, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            if (!_isQuantityMode)
              _inputField(
                label: 'Total Capital to Invest (USDT)',
                controller: _investmentCtrl,
                prefixIcon: Icons.account_balance_wallet_outlined,
                textColor: textPrimary,
                surfaceColor: surfaceColor,
                borderColor: borderColor,
                onChanged: (_) => _recalculateFromInvestment(),
              )
            else
              _inputField(
                label: 'Total ${_selectedCoin.symbol} Coins to Buy',
                controller: _quantityCtrl,
                prefixIcon: Icons.pie_chart_outline,
                textColor: textPrimary,
                surfaceColor: surfaceColor,
                borderColor: borderColor,
                onChanged: (_) => _recalculateFromQuantity(),
              ),

            const SizedBox(height: 16),

            // Exit Price
            _inputField(
              label: 'Target Exit / Sell Price (USDT)',
              controller: _sellPriceCtrl,
              prefixIcon: Icons.logout,
              textColor: textPrimary,
              surfaceColor: surfaceColor,
              borderColor: borderColor,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),

            // Quick Target Multipliers
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _quickTargetChip('+25%', () => _applyTargetMultiple(1.25), surfaceLight, borderColor, textSecondary),
                  _quickTargetChip('+50%', () => _applyTargetMultiple(1.50), surfaceLight, borderColor, textSecondary),
                  _quickTargetChip('2x (100%)', () => _applyTargetMultiple(2.0), surfaceLight, borderColor, AppColors.primary),
                  _quickTargetChip('3x', () => _applyTargetMultiple(3.0), surfaceLight, borderColor, textSecondary),
                  _quickTargetChip('5x', () => _applyTargetMultiple(5.0), surfaceLight, borderColor, textSecondary),
                  _quickTargetChip('10x', () => _applyTargetMultiple(10.0), surfaceLight, borderColor, textSecondary),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Fee %
            _inputField(
              label: 'Trading Fee (%)',
              controller: _feePercentCtrl,
              prefixIcon: Icons.percent,
              textColor: textPrimary,
              surfaceColor: surfaceColor,
              borderColor: borderColor,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 28),

            // Action: Trade / DCA This Position
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddTransactionScreen(
                      initialType: 'BUY',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.add_shopping_cart, size: 20),
              label: Text('Log DCA Buy Order for ${_selectedCoin.symbol}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _inputField({
    required String label,
    required TextEditingController controller,
    required IconData prefixIcon,
    required Color textColor,
    required Color surfaceColor,
    required Color borderColor,
    Widget? suffix,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 15),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.textSecondary(context), fontSize: 13),
        prefixIcon: Icon(prefixIcon, color: AppColors.textMuted(context), size: 18),
        suffixIcon: suffix,
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
        focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
      ),
    );
  }

  Widget _kpiItem(String label, String value, Color textColor, Color labelColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: labelColor, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: TextStyle(color: textColor, fontSize: 13.5, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _quickTargetChip(String label, VoidCallback onTap, Color bg, Color border, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border),
          ),
          child: Text(label, style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  void _openCoinPicker(BuildContext context, AsyncValue<List<BinanceTickerModel>> tickersAsync) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _CoinPickerSheet(
        tickers: tickersAsync.valueOrNull ?? [],
        onSelected: (coin) {
          Navigator.pop(ctx);
          _onCoinChanged(coin);
        },
      ),
    );
  }
}

class _CoinPickerSheet extends StatefulWidget {
  final List<BinanceTickerModel> tickers;
  final ValueChanged<BinanceTickerModel> onSelected;

  const _CoinPickerSheet({required this.tickers, required this.onSelected});

  @override
  State<_CoinPickerSheet> createState() => _CoinPickerSheetState();
}

class _CoinPickerSheetState extends State<_CoinPickerSheet> {
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
              Text('Select Crypto Asset', style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            autofocus: false,
            style: TextStyle(color: textPrimary),
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search coin (e.g. BTC, SOL, PEPE, SUI)...',
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
                        style: TextStyle(color: coin.priceChangePercent >= 0 ? AppColors.profit : AppColors.loss, fontSize: 11, fontWeight: FontWeight.bold),
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
