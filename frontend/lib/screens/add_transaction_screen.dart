import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';

import '../models/transaction.dart';
import '../services/api.dart';
import '../theme/app_colors.dart';
import '../theme/theme_provider.dart';
import '../utils.dart';
import '../widgets/auth_fields.dart';
import '../widgets/toast.dart';

const _expenseCategories = [
  'Food',
  'Travel',
  'Bills',
  'Shopping',
  'Rent',
  'Others',
];
const _incomeCategories = ['Salary', 'Bonus', 'Gift', 'Investment', 'Others'];

class AddTransactionArgs {
  final Txn? transaction;
  const AddTransactionArgs({this.transaction});
}

// Add or edit an income / expense transaction.
class AddTransactionScreen extends StatefulWidget {
  static const route = '/add-transaction';
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  String _type = 'Expense';
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _description = TextEditingController();
  DateTime _date = DateTime.now();
  String _category = 'Food';
  bool _loading = false;
  bool _resolved = false;
  Txn? _original;

  bool get _editing => _original != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_resolved) return;
    _resolved = true;
    final args =
        ModalRoute.of(context)?.settings.arguments as AddTransactionArgs?;
    _original = args?.transaction;
    final transaction = _original;
    if (transaction != null) {
      _type = transaction.type;
      _title.text = transaction.title;
      _amount.text = transaction.amount.toStringAsFixed(2);
      _description.text = transaction.description ?? '';
      _date = transaction.date;
      _category = transaction.category;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  List<String> get _categories =>
      _type == 'Expense' ? _expenseCategories : _incomeCategories;

  void _onTypeChange(String next) {
    setState(() {
      _type = next;
      _category = next == 'Expense'
          ? _expenseCategories[0]
          : _incomeCategories[0];
    });
  }

  String? _validate() {
    if (_title.text.isEmpty) return 'Please enter a title';
    final amt = double.tryParse(_amount.text);
    if (_amount.text.isEmpty || amt == null || amt <= 0) {
      return 'Enter a valid amount';
    }
    if (_category.isEmpty) return 'Please select a category';
    return null;
  }

  Future<void> _submit() async {
    final error = _validate();
    if (error != null) {
      showToast(context, error);
      return;
    }
    setState(() => _loading = true);
    try {
      final payload = <String, dynamic>{
        'title': _title.text,
        'description': _description.text,
        'amount': _amount.text,
        'category': _category,
        'transaction_type': _type,
        'date': _date.toUtc().toIso8601String(),
        if (_original != null) 'merchant': _original!.merchant,
        if (_original != null) 'payment_method': _original!.paymentMethod,
        if (_original != null) 'is_essential': _original!.isEssential,
      };
      final saved = _original == null
          ? await Api.addTransaction(payload)
          : await Api.updateTransaction(_original!.id, payload);
      if (mounted) Navigator.pop(context, saved);
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    } catch (_) {
      if (mounted) showToast(context, 'Could not connect to the server.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickCategory(AppColors colors) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Category',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colors.text,
                ),
              ),
              const SizedBox(height: 12),
              for (final cat in _categories)
                InkWell(
                  onTap: () => Navigator.pop(context, cat),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          cat,
                          style: TextStyle(color: colors.text, fontSize: 16),
                        ),
                        if (cat == _category)
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
    if (selected != null) setState(() => _category = selected);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeProvider>().colors;

    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit Transaction' : 'Add New Transaction'),
      ),
      backgroundColor: colors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Segmented Expense / Income toggle — black active pill.
            Container(
              margin: const EdgeInsets.only(bottom: 28),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: colors.elevated,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(
                children: [
                  for (final opt in ['Expense', 'Income'])
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _onTypeChange(opt),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _type == opt
                                ? colors.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                opt == 'Expense'
                                    ? Ionicons.arrow_down
                                    : Ionicons.arrow_up,
                                size: 16,
                                color: _type == opt
                                    ? colors.onPrimary
                                    : colors.secondaryText,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                opt,
                                style: TextStyle(
                                  color: _type == opt
                                      ? colors.onPrimary
                                      : colors.secondaryText,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            _label('Title', colors),
            _boxedField(
              colors: colors,
              child: TextField(
                controller: _title,
                style: TextStyle(color: colors.text, fontSize: 16),
                decoration: _innerDecoration('e.g., Coffee, Salary', colors),
              ),
            ),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Amount', colors),
                      _boxedField(
                        colors: colors,
                        child: TextField(
                          controller: _amount,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: TextStyle(color: colors.text, fontSize: 16),
                          decoration: _innerDecoration('₹ 0.00', colors),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Date', colors),
                      _boxedField(
                        colors: colors,
                        onTap: _pickDate,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              formatShortDate(_date),
                              style: TextStyle(color: colors.text),
                            ),
                            Icon(
                              Ionicons.calendar,
                              size: 18,
                              color: colors.secondaryText,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            _label('Description (Optional)', colors),
            _boxedField(
              colors: colors,
              child: TextField(
                controller: _description,
                maxLines: 3,
                textAlignVertical: TextAlignVertical.top,
                style: TextStyle(color: colors.text, fontSize: 16),
                decoration: _innerDecoration(
                  'Add any extra notes here...',
                  colors,
                ),
              ),
            ),

            _label('Category', colors),
            _boxedField(
              colors: colors,
              onTap: () => _pickCategory(colors),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_category, style: TextStyle(color: colors.text)),
                  Icon(
                    Ionicons.chevron_down,
                    size: 18,
                    color: colors.secondaryText,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            PrimaryButton(
              label: _editing ? 'Save Changes' : 'Add Transaction',
              loading: _loading,
              colors: colors,
              onTap: _submit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text, AppColors colors) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 6),
    child: Text(
      text,
      style: TextStyle(fontSize: 13, color: colors.secondaryText),
    ),
  );

  // A bordered box; either wraps a raw field or an on-tap "picker" row.
  Widget _boxedField({
    required AppColors colors,
    required Widget child,
    VoidCallback? onTap,
  }) {
    final box = Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: onTap == null
          ? const EdgeInsets.symmetric(horizontal: 16)
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      decoration: BoxDecoration(
        color: colors.elevated,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
    if (onTap == null) return box;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: box,
    );
  }

  InputDecoration _innerDecoration(String hint, AppColors colors) =>
      InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: colors.secondaryText),
        border: InputBorder.none,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      );
}
