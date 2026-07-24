import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';

import '../models/expense_setup.dart';
import '../services/api.dart';
import '../theme/app_colors.dart';
import '../theme/theme_provider.dart';
import '../utils.dart';
import '../widgets/toast.dart';

class ImportReviewScreen extends StatefulWidget {
  static const route = '/import-review';
  const ImportReviewScreen({super.key});

  @override
  State<ImportReviewScreen> createState() => _ImportReviewScreenState();
}

class _ImportReviewScreenState extends State<ImportReviewScreen> {
  bool _loading = false;
  ImportBatch? _batch;
  final Set<String> _selected = {};
  String? _fileName;

  Future<void> _pickAndPrepare() async {
    try {
      const typeGroup = XTypeGroup(
        label: 'CSV',
        extensions: ['csv'],
        uniformTypeIdentifiers: ['public.comma-separated-values-text'],
        mimeTypes: ['text/csv'],
      );
      final file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final rows = _parseCsv(utf8.decode(bytes));
      setState(() => _loading = true);
      final batch = await Api.createImport(
        source: 'CSVImport',
        filename: file.name,
        items: rows,
      );
      if (!mounted) return;
      setState(() {
        _batch = batch;
        _fileName = file.name;
        _selected
          ..clear()
          ..addAll(
            batch.items
                .where((item) => item.status == 'pending')
                .map((item) => item.id),
          );
      });
    } on FormatException {
      if (mounted) {
        showToast(
          context,
          'The CSV must have: title, amount, category, type, date, merchant.',
        );
      }
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    } catch (_) {
      // e.g. MissingPluginException when the native file_picker plugin isn't
      // compiled in yet — surface it instead of a dead button.
      if (mounted) {
        showToast(context,
            'Could not open the file picker. Fully restart the app and try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _parseCsv(String text) {
    final rows = CsvToListConverter(shouldParseNumbers: false).convert(text);
    if (rows.length < 2) throw const FormatException();
    final headers = rows.first
        .map((value) => value.toString().trim().toLowerCase())
        .toList();
    int indexOf(String name) => headers.indexOf(name);
    final titleIndex = indexOf('title');
    final amountIndex = indexOf('amount');
    final categoryIndex = indexOf('category');
    final typeIndex = indexOf('type');
    final dateIndex = indexOf('date');
    final merchantIndex = indexOf('merchant');
    if ([
      titleIndex,
      amountIndex,
      categoryIndex,
      typeIndex,
      dateIndex,
    ].any((index) => index < 0)) {
      throw const FormatException();
    }
    String field(List<dynamic> row, int index) =>
        index >= 0 && index < row.length ? row[index].toString().trim() : '';
    final parsed = <Map<String, dynamic>>[];
    for (final row in rows.skip(1)) {
      if (row.every((value) => value.toString().trim().isEmpty)) continue;
      parsed.add({
        'title': field(row, titleIndex),
        'amount': field(row, amountIndex),
        'category': field(row, categoryIndex),
        'transaction_type': field(row, typeIndex),
        'date': field(row, dateIndex),
        if (merchantIndex >= 0 && field(row, merchantIndex).isNotEmpty)
          'merchant': field(row, merchantIndex),
      });
    }
    if (parsed.isEmpty) throw const FormatException();
    return parsed;
  }

  Future<void> _confirm() async {
    final batch = _batch;
    if (batch == null) return;
    setState(() => _loading = true);
    try {
      await Api.confirmImport(
        batch.id,
        batch.items
            .where((item) => item.status == 'pending')
            .map(
              (item) => {
                'item_id': item.id,
                'accept': _selected.contains(item.id),
              },
            )
            .toList(),
      );
      if (mounted) {
        showToast(context, 'Import confirmed.', variant: 'success');
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeProvider>().colors;
    final batch = _batch;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(batch == null ? 'Import expenses' : 'Review import'),
      ),
      body: batch == null ? _entry(colors) : _review(colors, batch),
    );
  }

  Widget _entry(AppColors colors) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Import a CSV statement',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: colors.text,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose a CSV file from your device. Nothing becomes an expense until you review and confirm it.',
          style: TextStyle(color: colors.secondaryText),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Center(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: colors.accent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Ionicons.document_text_outline,
                      color: colors.onAccent,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _fileName ?? 'No CSV selected',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Required columns: title, amount, category, type, date, merchant.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.secondaryText, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _loading ? null : _pickAndPrepare,
            icon: const Icon(Ionicons.folder_open_outline),
            label: Text(_loading ? 'Preparing…' : 'Choose CSV file'),
          ),
        ),
      ],
    ),
  );

  Widget _review(AppColors colors, ImportBatch batch) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Select the rows to add. Duplicates are automatically excluded.',
          style: TextStyle(color: colors.secondaryText),
        ),
      ),
      Expanded(
        child: ListView.builder(
          itemCount: batch.items.length,
          itemBuilder: (_, index) {
            final item = batch.items[index];
            final selectable = item.status == 'pending';
            return CheckboxListTile(
              value: selectable && _selected.contains(item.id),
              onChanged: selectable
                  ? (value) => setState(() {
                      if (value == true) {
                        _selected.add(item.id);
                      } else {
                        _selected.remove(item.id);
                      }
                    })
                  : null,
              title: Text(item.title),
              subtitle: Text(
                '${item.category} · ${formatShortDate(item.date)} · ${item.status}',
              ),
              secondary: Text(
                formatRupee(item.amount),
                style: TextStyle(
                  color: colors.text,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          },
        ),
      ),
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _loading || _selected.isEmpty ? null : _confirm,
              child: Text(
                _loading ? 'Confirming…' : 'Add ${_selected.length} expenses',
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
