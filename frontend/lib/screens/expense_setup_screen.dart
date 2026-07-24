import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';

import '../models/expense_setup.dart';
import '../services/api.dart';
import '../theme/app_colors.dart';
import '../theme/theme_provider.dart';
import '../utils.dart';
import '../widgets/toast.dart';

class ExpenseSetupScreen extends StatefulWidget {
  static const route = '/expense-setup';
  const ExpenseSetupScreen({super.key});

  @override
  State<ExpenseSetupScreen> createState() => _ExpenseSetupScreenState();
}

class _ExpenseSetupScreenState extends State<ExpenseSetupScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _loading = true;
  List<Commitment> _commitments = [];
  List<MerchantRule> _rules = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait([
        Api.getCommitments(),
        Api.getMerchantRules(),
      ]);
      if (!mounted) return;
      setState(() {
        _commitments = values[0] as List<Commitment>;
        _rules = values[1] as List<MerchantRule>;
      });
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editCommitment([Commitment? existing]) async {
    final title = TextEditingController(text: existing?.title);
    final merchant = TextEditingController(text: existing?.merchant);
    final amount = TextEditingController(
      text: existing?.expectedAmount.toStringAsFixed(2) ?? '',
    );
    final notes = TextEditingController(text: existing?.notes);
    var due =
        existing?.nextDueDate ?? DateTime.now().add(const Duration(days: 1));
    var frequency = existing?.frequency ?? 'monthly';
    var essential = existing?.isEssential ?? true;
    final saved = await showDialog<Commitment>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add commitment' : 'Edit commitment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                TextField(
                  controller: merchant,
                  decoration: const InputDecoration(
                    labelText: 'Merchant (optional)',
                  ),
                ),
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Expected amount',
                  ),
                ),
                DropdownButtonFormField<String>(
                  initialValue: frequency,
                  decoration: const InputDecoration(labelText: 'Frequency'),
                  items: const ['weekly', 'monthly', 'quarterly', 'yearly']
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => frequency = value!),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Due ${formatShortDate(due)}'),
                  trailing: const Icon(Ionicons.calendar_outline),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: dialogContext,
                      initialDate: due,
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 1),
                      ),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setDialogState(() => due = picked);
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Essential expense'),
                  value: essential,
                  onChanged: (value) => setDialogState(() => essential = value),
                ),
                TextField(
                  controller: notes,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final parsed = double.tryParse(amount.text);
                if (title.text.trim().isEmpty ||
                    parsed == null ||
                    parsed <= 0) {
                  return;
                }
                try {
                  final result = await Api.saveCommitment({
                    'title': title.text.trim(),
                    'merchant': merchant.text.trim(),
                    'expected_amount': parsed,
                    'frequency': frequency,
                    'next_due_date': due.toIso8601String().substring(0, 10),
                    'is_essential': essential,
                    'is_active': existing?.isActive ?? true,
                    'notes': notes.text.trim(),
                  }, id: existing?.id);
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext, result);
                  }
                } on ApiException catch (e) {
                  if (dialogContext.mounted) {
                    showToast(dialogContext, e.message);
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    merchant.dispose();
    amount.dispose();
    notes.dispose();
    if (saved == null || !mounted) return;
    setState(() {
      final index = _commitments.indexWhere((item) => item.id == saved.id);
      if (index < 0) {
        _commitments.add(saved);
      } else {
        _commitments[index] = saved;
      }
      _commitments.sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));
    });
  }

  Future<void> _addRule() async {
    final pattern = TextEditingController();
    final display = TextEditingController();
    var category = 'Others';
    var essential = false;
    final saved = await showDialog<MerchantRule>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: const Text('Merchant rule'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: pattern,
                decoration: const InputDecoration(
                  labelText: 'Merchant text to match',
                ),
              ),
              TextField(
                controller: display,
                decoration: const InputDecoration(
                  labelText: 'Display name (optional)',
                ),
              ),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(
                  labelText: 'Expense category',
                ),
                items:
                    const [
                          'Food',
                          'Travel',
                          'Bills',
                          'Shopping',
                          'Rent',
                          'Others',
                        ]
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                onChanged: (value) => setDialogState(() => category = value!),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Essential expense'),
                value: essential,
                onChanged: (value) => setDialogState(() => essential = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (pattern.text.trim().isEmpty) return;
                try {
                  final rule = await Api.saveMerchantRule({
                    'merchant_pattern': pattern.text.trim(),
                    'display_merchant': display.text.trim(),
                    'category': category,
                    'is_essential': essential,
                  });
                  if (dialogContext.mounted) Navigator.pop(dialogContext, rule);
                } on ApiException catch (e) {
                  if (dialogContext.mounted) {
                    showToast(dialogContext, e.message);
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    pattern.dispose();
    display.dispose();
    if (saved != null && mounted) setState(() => _rules.insert(0, saved));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeProvider>().colors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Expense setup'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Commitments'),
            Tab(text: 'Merchant rules'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        onPressed: () => _tabs.index == 0 ? _editCommitment() : _addRule(),
        child: const Icon(Ionicons.add),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: colors.primary))
          : TabBarView(
              controller: _tabs,
              children: [_commitmentList(colors), _ruleList(colors)],
            ),
    );
  }

  Widget _commitmentList(AppColors colors) => RefreshIndicator(
    onRefresh: _load,
    child: _commitments.isEmpty
        ? ListView(
            children: [
              const SizedBox(height: 160),
              Center(
                child: Text(
                  'Add rent, EMIs, bills, or subscriptions.',
                  style: TextStyle(color: colors.secondaryText),
                ),
              ),
            ],
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _commitments.length,
            itemBuilder: (_, index) {
              final item = _commitments[index];
              return Card(
                child: ListTile(
                  onTap: () => _editCommitment(item),
                  title: Text(item.title),
                  subtitle: Text(
                    '${item.frequency} · due ${formatShortDate(item.nextDueDate)}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formatRupee(item.expectedAmount),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Ionicons.trash_outline),
                        onPressed: () async {
                          await Api.deleteCommitment(item.id);
                          if (mounted) {
                            setState(() => _commitments.removeAt(index));
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
  );

  Widget _ruleList(AppColors colors) => RefreshIndicator(
    onRefresh: _load,
    child: _rules.isEmpty
        ? ListView(
            children: [
              const SizedBox(height: 160),
              Center(
                child: Text(
                  'Create rules to categorise merchant names automatically.',
                  style: TextStyle(color: colors.secondaryText),
                ),
              ),
            ],
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _rules.length,
            itemBuilder: (_, index) {
              final item = _rules[index];
              return Card(
                child: ListTile(
                  title: Text(item.displayMerchant ?? item.pattern),
                  subtitle: Text(
                    '${item.pattern} · ${item.category ?? 'No category'}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Ionicons.trash_outline),
                    onPressed: () async {
                      await Api.deleteMerchantRule(item.id);
                      if (mounted) setState(() => _rules.removeAt(index));
                    },
                  ),
                ),
              );
            },
          ),
  );
}
