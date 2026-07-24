import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';

import '../models/transaction.dart';
import '../services/api.dart';
import '../theme/app_colors.dart';
import '../theme/theme_provider.dart';
import '../utils.dart';
import '../widgets/toast.dart';
import 'add_transaction_screen.dart';

class AllTransactionsArgs {
  final List<Txn> transactions;
  const AllTransactionsArgs({required this.transactions});
}

// Mirrors src/screens/AllTransactionsScreen.jsx.
class AllTransactionsScreen extends StatefulWidget {
  static const route = '/all-transactions';
  const AllTransactionsScreen({super.key});

  @override
  State<AllTransactionsScreen> createState() => _AllTransactionsScreenState();
}

class _AllTransactionsScreenState extends State<AllTransactionsScreen> {
  String _filter = 'all'; // all | income | expense
  String _sort = 'newest'; // newest | oldest | amountHigh | amountLow
  final Set<String> _expanded = {};
  // Local copy so deletions reflect immediately; Home refetches on return.
  List<Txn>? _all;

  List<Txn> _process(List<Txn> all) {
    var list = [...all];
    if (_filter == 'income') {
      list = list.where((t) => t.type == 'Income').toList();
    } else if (_filter == 'expense') {
      list = list.where((t) => t.type == 'Expense').toList();
    }

    switch (_sort) {
      case 'newest':
        list.sort((a, b) => b.date.compareTo(a.date));
        break;
      case 'oldest':
        list.sort((a, b) => a.date.compareTo(b.date));
        break;
      case 'amountHigh':
        list.sort((a, b) => b.amount.compareTo(a.amount));
        break;
      case 'amountLow':
        list.sort((a, b) => a.amount.compareTo(b.amount));
        break;
    }
    return list;
  }

  // Group by formatted date, preserving processed order.
  List<MapEntry<String, List<Txn>>> _group(List<Txn> processed) {
    final map = <String, List<Txn>>{};
    for (final txn in processed) {
      final key = formatLongDate(txn.date);
      map.putIfAbsent(key, () => []).add(txn);
    }
    return map.entries.toList();
  }

  Future<void> _openSort(AppColors colors) async {
    final selected = await _optionSheet(
      colors: colors,
      title: 'Sort by',
      selected: _sort,
      options: const [
        _Opt('newest', 'Newest First', Ionicons.sparkles),
        _Opt('oldest', 'Oldest First', Ionicons.time),
        _Opt('amountHigh', 'Amount: High to Low', Ionicons.arrow_down),
        _Opt('amountLow', 'Amount: Low to High', Ionicons.arrow_up),
      ],
    );
    if (selected != null) setState(() => _sort = selected);
  }

  Future<void> _openFilter(AppColors colors) async {
    final selected = await _optionSheet(
      colors: colors,
      title: 'Show',
      selected: _filter,
      options: [
        const _Opt('all', 'All Transactions', Ionicons.infinite),
        _Opt('income', 'Income Only', Ionicons.arrow_up, colors.income),
        _Opt('expense', 'Expenses Only', Ionicons.arrow_down, colors.expense),
      ],
    );
    if (selected != null) setState(() => _filter = selected);
  }

  Future<String?> _optionSheet({
    required AppColors colors,
    required String title,
    required String selected,
    required List<_Opt> options,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colors.text,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              for (final opt in options)
                InkWell(
                  onTap: () => Navigator.pop(context, opt.key),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 8,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          opt.icon,
                          size: 20,
                          color: opt.color ?? colors.text,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            opt.label,
                            style: TextStyle(color: colors.text, fontSize: 16),
                          ),
                        ),
                        if (selected == opt.key)
                          Icon(
                            Ionicons.checkmark,
                            size: 20,
                            color: colors.primary,
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeProvider>().colors;
    _all ??= [
      ...(ModalRoute.of(context)!.settings.arguments as AllTransactionsArgs)
          .transactions,
    ];
    final processed = _process(_all!);
    final groups = _group(processed);

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Transactions'),
        actions: [
          IconButton(
            icon: Icon(Ionicons.swap_vertical, color: colors.text),
            onPressed: () => _openSort(colors),
          ),
          IconButton(
            icon: Icon(Ionicons.filter, color: colors.text),
            onPressed: () => _openFilter(colors),
          ),
          const SizedBox(width: 8),
        ],
      ),
      backgroundColor: colors.background,
      body: processed.isEmpty
          ? Center(
              child: Text(
                'No transactions match the current filter.',
                style: TextStyle(color: colors.secondaryText),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(8),
              children: [
                for (final group in groups)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 0, 8),
                          child: Text(
                            group.key,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: colors.secondaryText,
                            ),
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: colors.card,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: colors.border),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              for (var i = 0; i < group.value.length; i++) ...[
                                if (i > 0)
                                  Divider(
                                    height: 1,
                                    thickness: 1,
                                    indent: 72,
                                    endIndent: 16,
                                    color: colors.border,
                                  ),
                                _row(group.value[i], colors),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  // Long-press → confirm → DELETE /transactions/{id}.
  Future<void> _confirmDelete(Txn txn, AppColors colors) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Delete transaction?',
          style: TextStyle(color: colors.text, fontWeight: FontWeight.w800),
        ),
        content: Text(
          '"${txn.title}" will be permanently removed.',
          style: TextStyle(color: colors.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: colors.secondaryText),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'Delete',
              style: TextStyle(
                color: colors.expense,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await Api.deleteTransaction(txn.id);
      if (!mounted) return;
      setState(() => _all?.removeWhere((t) => t.id == txn.id));
      if (mounted) {
        showToast(context, 'Transaction deleted.', variant: 'success');
      }
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    } catch (_) {
      if (mounted) showToast(context, 'Could not delete the transaction.');
    }
  }

  Future<void> _editTransaction(Txn txn) async {
    final saved = await Navigator.pushNamed(
      context,
      AddTransactionScreen.route,
      arguments: AddTransactionArgs(transaction: txn),
    );
    if (saved is! Txn || !mounted) return;
    setState(() {
      final index = _all?.indexWhere((item) => item.id == saved.id) ?? -1;
      if (index >= 0) _all![index] = saved;
    });
  }

  // Tap the ⋮ on a row → Edit / Delete actions.
  Future<void> _showRowActions(Txn txn, AppColors colors) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(txn.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: colors.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text('${txn.type} · ${txn.category} · ${formatRupee(txn.amount)}',
                  style:
                      TextStyle(color: colors.secondaryText, fontSize: 13)),
              const SizedBox(height: 16),
              _actionRow(colors, Ionicons.create_outline, 'Edit', colors.text,
                  () {
                Navigator.pop(sheetContext);
                _editTransaction(txn);
              }),
              const SizedBox(height: 10),
              _actionRow(colors, Ionicons.trash_outline, 'Delete',
                  colors.expense, () {
                Navigator.pop(sheetContext);
                _confirmDelete(txn, colors);
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionRow(AppColors colors, IconData icon, String label, Color tint,
      VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.elevated,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration:
                  BoxDecoration(color: colors.card, shape: BoxShape.circle),
              child: Icon(icon, size: 20, color: tint),
            ),
            const SizedBox(width: 14),
            Text(label,
                style: TextStyle(
                    color: tint,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _row(Txn txn, AppColors colors) {
    final isExpense = txn.type == 'Expense';
    final hasDescription =
        txn.description != null && txn.description!.isNotEmpty;
    final isOpen = _expanded.contains(txn.id);

    return Column(
      children: [
        InkWell(
          onTap: hasDescription
              ? () => setState(() {
                  if (isOpen) {
                    _expanded.remove(txn.id);
                  } else {
                    _expanded.add(txn.id);
                  }
                })
              : null,
          onLongPress: () => _confirmDelete(txn, colors),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  margin: const EdgeInsets.only(right: 14),
                  decoration: BoxDecoration(
                    color: colors.elevated,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    iconForCategory(txn.category),
                    size: 20,
                    color: colors.text,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        txn.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: colors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        txn.category,
                        style: TextStyle(
                          color: colors.secondaryText,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Ionicons.ellipsis_vertical,
                    size: 18,
                    color: colors.secondaryText,
                  ),
                  tooltip: 'Options',
                  onPressed: () => _showRowActions(txn, colors),
                ),
                if (isExpense)
                  Text(
                    '-${formatRupee(txn.amount)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: colors.text,
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: colors.accent,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      '+${formatRupee(txn.amount)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: colors.onAccent,
                      ),
                    ),
                  ),
                if (hasDescription)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(
                      isOpen ? Ionicons.chevron_up : Ionicons.chevron_down,
                      size: 18,
                      color: colors.secondaryText,
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (hasDescription && isOpen)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                txn.description!,
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: colors.secondaryText,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Opt {
  final String key;
  final String label;
  final IconData icon;
  final Color? color;
  const _Opt(this.key, this.label, this.icon, [this.color]);
}
