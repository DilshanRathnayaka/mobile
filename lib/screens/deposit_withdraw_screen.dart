import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/formatters.dart';
import '../data/models/cashflow_model.dart';
import '../providers/cashflow_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/portfolio_provider.dart';
import 'bank_budget_hub_screen.dart';
import 'salary_epf_screen.dart';

class DepositWithdrawScreen extends ConsumerStatefulWidget {
  const DepositWithdrawScreen({super.key});

  @override
  ConsumerState<DepositWithdrawScreen> createState() => _DepositWithdrawScreenState();
}

class _DepositWithdrawScreenState extends ConsumerState<DepositWithdrawScreen> {
  String _selectedFilter = 'ALL'; // 'ALL', 'DEPOSIT', 'WITHDRAWAL'

  @override
  Widget build(BuildContext context) {
    final cashflow = ref.watch(cashflowProvider);
    final currency = ref.watch(currencyProvider);

    final bgColor = AppColors.background(context);
    final surfaceColor = AppColors.surface(context);
    final surfaceLight = AppColors.surfaceLight(context);
    final borderColor = AppColors.border(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final textMuted = AppColors.textMuted(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isNetPositive = cashflow.netCapital >= 0;

    final filteredItems = cashflow.items.where((item) {
      if (_selectedFilter == 'ALL') return true;
      return item.type == _selectedFilter;
    }).toList();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text(
          'Deposit & Withdraw Hub',
          style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Bank & Monthly Budget Hub',
            icon: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF3861FB)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BankBudgetHubScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Salary & EPF Tracker',
            icon: const Icon(Icons.work_history_rounded, color: Color(0xFF9D7CFF)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SalaryEpfScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: surfaceColor,
        onRefresh: () async {
          await ref.read(cashflowProvider.notifier).refresh();
          await ref.read(portfolioSummaryProvider.notifier).refresh();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
          // 1. Net Capital & Cashflow Hero Card
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF16161C), const Color(0xFF0F0E13)]
                    : [const Color(0xFFFFFFFF), const Color(0xFFF9F9FC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isNetPositive ? AppColors.profit.withAlpha(80) : AppColors.loss.withAlpha(80),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'NET DEPOSITED CAPITAL',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isNetPositive ? AppColors.profitBg : AppColors.lossBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isNetPositive ? 'Capital Inflow' : 'Net Outflow',
                        style: TextStyle(
                          color: isNetPositive ? AppColors.profit : AppColors.loss,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    Formatters.currency(cashflow.netCapital, currency),
                    style: TextStyle(
                      color: isNetPositive ? textPrimary : AppColors.loss,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  'Total capital deposited into trading minus total withdrawals',
                  style: TextStyle(color: textSecondary, fontSize: 12),
                ),
                Divider(color: borderColor, height: 26),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.arrow_downward, color: AppColors.profit, size: 14),
                                const SizedBox(width: 4),
                                Text('Total Deposited', style: TextStyle(color: textMuted, fontSize: 11)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 3),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '+${Formatters.currency(cashflow.totalDeposited, currency)}',
                              style: const TextStyle(color: AppColors.profit, fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                const Icon(Icons.arrow_upward, color: AppColors.loss, size: 14),
                                const SizedBox(width: 4),
                                Text('Total Withdrawn', style: TextStyle(color: textMuted, fontSize: 11)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 3),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              '-${Formatters.currency(cashflow.totalWithdrawn, currency)}',
                              style: const TextStyle(color: AppColors.loss, fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. Dual Action Buttons (Deposit vs Withdraw)
          Row(
            children: [
              // Deposit Button
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.profit,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => _openCashflowDialog(context, type: 'DEPOSIT'),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.arrow_downward, size: 18),
                        SizedBox(width: 6),
                        Text('Deposit Funds', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Withdraw Button
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.loss,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => _openCashflowDialog(context, type: 'WITHDRAWAL'),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.arrow_upward, size: 18),
                        SizedBox(width: 6),
                        Text('Withdraw Funds', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 3. Segmented Filter Tabs
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'TRANSFER HISTORY',
                  style: TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _filterButton('ALL', 'All', surfaceColor, surfaceLight, borderColor, textPrimary, textSecondary),
                  const SizedBox(width: 4),
                  _filterButton('DEPOSIT', 'Deposits', surfaceColor, surfaceLight, borderColor, textPrimary, textSecondary),
                  const SizedBox(width: 4),
                  _filterButton('WITHDRAWAL', 'Withdrawals', surfaceColor, surfaceLight, borderColor, textPrimary, textSecondary),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 4. Activity Log List
          if (filteredItems.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.swap_vert, size: 42, color: textMuted),
                    const SizedBox(height: 10),
                    Text('No transfer records found', style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Tap "Deposit Funds" or "Withdraw Funds" above to record transfers.', style: TextStyle(color: textSecondary, fontSize: 12), textAlign: TextAlign.center),
                  ],
                ),
              ),
            )
          else
            ...filteredItems.map((item) {
              final isDep = item.type == 'DEPOSIT';
              final color = isDep ? AppColors.profit : AppColors.loss;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withAlpha(30),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isDep ? Icons.arrow_downward : Icons.arrow_upward,
                        color: color,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  item.category,
                                  style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: color.withAlpha(20),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isDep ? 'Deposit' : 'Withdrawal',
                                  style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            Formatters.date(item.date),
                            style: TextStyle(color: textMuted, fontSize: 11),
                          ),
                          if (item.notes.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              item.notes,
                              style: TextStyle(color: textSecondary, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${isDep ? '+' : '-'}${Formatters.currency(item.amount, currency)}',
                            style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: textMuted, size: 18),
                      color: surfaceColor,
                      onSelected: (val) {
                        if (val == 'edit') {
                          _openCashflowDialog(context, type: item.type, itemToEdit: item);
                        } else if (val == 'delete') {
                          _confirmDelete(context, item.id);
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                        const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppColors.loss))),
                      ],
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 20),
        ],
      ),
    ),
    );
  }

  Widget _filterButton(
    String key,
    String label,
    Color surfaceColor,
    Color surfaceLight,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    final isSelected = _selectedFilter == key;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = key),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : surfaceLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? AppColors.primary : borderColor),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : textSecondary,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  void _openCashflowDialog(BuildContext context, {required String type, CashflowItem? itemToEdit}) {
    final isDeposit = type == 'DEPOSIT';
    final amountCtrl = TextEditingController(text: itemToEdit != null ? itemToEdit.amount.toString() : '');
    final notesCtrl = TextEditingController(text: itemToEdit?.notes ?? '');

    String selectedCategory = itemToEdit?.category ??
        (isDeposit ? 'Salary Inflow' : 'Profit Realization');
    DateTime selectedDate = itemToEdit?.date ?? DateTime.now();

    final depositCategories = ['Salary Inflow', 'Bank Transfer', 'Crypto Deposit', 'Savings / Bonus', 'Custom Deposit'];
    final withdrawalCategories = ['Profit Realization', 'Bank Withdrawal', 'Emergency Expense', 'Crypto Cashout', 'Custom Withdrawal'];

    final categories = isDeposit ? depositCategories : withdrawalCategories;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          final textPrimary = AppColors.textPrimary(modalCtx);
          final textSecondary = AppColors.textSecondary(modalCtx);
          final borderColor = AppColors.border(modalCtx);
          final color = isDeposit ? AppColors.profit : AppColors.loss;

          return Padding(
            padding: EdgeInsets.only(
              top: 20,
              left: 20,
              right: 20,
              bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: color.withAlpha(30), shape: BoxShape.circle),
                          child: Icon(isDeposit ? Icons.arrow_downward : Icons.arrow_upward, color: color, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          itemToEdit != null
                              ? 'Edit ${isDeposit ? "Deposit" : "Withdrawal"}'
                              : (isDeposit ? 'Deposit Funds' : 'Withdraw Funds'),
                          style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 16),

                // Amount
                Text('Amount (USDT)', style: TextStyle(color: textSecondary, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  autofocus: true,
                  style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.attach_money, color: color),
                    hintText: 'e.g. 500.00',
                    filled: true,
                    fillColor: AppColors.surfaceLight(modalCtx),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                  ),
                ),
                const SizedBox(height: 16),

                // Category Selector
                Text('Transfer Category', style: TextStyle(color: textSecondary, fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: categories.map((cat) {
                    final isSel = selectedCategory == cat;
                    return InkWell(
                      onTap: () => setModalState(() => selectedCategory = cat),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSel ? color : AppColors.surfaceLight(modalCtx),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isSel ? color : borderColor),
                        ),
                        child: Text(
                          cat,
                          style: TextStyle(
                            color: isSel ? Colors.white : textSecondary,
                            fontSize: 12,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Date Picker Tile
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today, color: AppColors.primary, size: 20),
                  title: Text(Formatters.date(selectedDate), style: TextStyle(color: textPrimary, fontSize: 14)),
                  trailing: const Text('Change Date', style: TextStyle(color: AppColors.primary, fontSize: 12)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: modalCtx,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setModalState(() => selectedDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 6),

                // Notes Field
                TextField(
                  controller: notesCtrl,
                  style: TextStyle(color: textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Optional transfer notes or reference...',
                    filled: true,
                    fillColor: AppColors.surfaceLight(modalCtx),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                  ),
                ),
                const SizedBox(height: 20),

                // Submit Button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    final amt = double.tryParse(amountCtrl.text.trim()) ?? 0;
                    if (amt <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid amount'), backgroundColor: AppColors.loss),
                      );
                      return;
                    }

                    if (itemToEdit != null) {
                      ref.read(cashflowProvider.notifier).updateRecord(
                            id: itemToEdit.id,
                            type: type,
                            amount: amt,
                            category: selectedCategory,
                            date: selectedDate,
                            notes: notesCtrl.text.trim(),
                          );
                    } else {
                      ref.read(cashflowProvider.notifier).addRecord(
                            type: type,
                            amount: amt,
                            category: selectedCategory,
                            date: selectedDate,
                            notes: notesCtrl.text.trim(),
                          );
                    }

                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${isDeposit ? "Deposit" : "Withdrawal"} recorded successfully!'),
                        backgroundColor: color,
                      ),
                    );
                  },
                  child: Text(
                    itemToEdit != null ? 'Save Changes' : (isDeposit ? 'Confirm Deposit' : 'Confirm Withdrawal'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        title: Text('Delete Record', style: TextStyle(color: AppColors.textPrimary(context))),
        content: Text('Are you sure you want to delete this cashflow entry?', style: TextStyle(color: AppColors.textSecondary(context))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary(context))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.loss),
            onPressed: () {
              ref.read(cashflowProvider.notifier).deleteRecord(id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
