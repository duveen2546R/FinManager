import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';

import '../models/expense_setup.dart';
import '../services/api.dart';
import '../theme/app_colors.dart';
import '../theme/theme_provider.dart';
import '../utils.dart';
import '../widgets/toast.dart';
import '../widgets/responsive.dart';

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
    } on FormatException catch (e) {
      if (mounted) {
        final reason = e.message.isNotEmpty ? ' — ${e.message}' : '';
        showToast(
          context,
          'Couldn\'t read that CSV$reason. It needs at least an amount '
          '(or debit/credit) column.',
        );
      }
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    } catch (_) {
      // e.g. MissingPluginException when the native file_picker plugin isn't
      // compiled in yet — surface it instead of a dead button.
      if (mounted) {
        showToast(
          context,
          'Could not open the file picker. Fully restart the app and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Allowed backend categories (used to clamp whatever the CSV provides).
  static const _expenseCats = {
    'Food',
    'Travel',
    'Bills',
    'Shopping',
    'Rent',
    'Others',
  };
  static const _incomeCats = {
    'Salary',
    'Bonus',
    'Gift',
    'Investment',
    'Others',
  };

  // Format-tolerant CSV parser. Accepts most bank/exported statements:
  //  - header names are fuzzily matched (Description/Narration/Particulars ->
  //    title, Withdrawal/Deposit -> amount+type, Value Date -> date, …);
  //  - amounts are cleaned of currency symbols, commas and signs;
  //  - dates in many formats are normalised to ISO (YYYY-MM-DD);
  //  - type is inferred from a type column, debit/credit columns, or the sign;
  //  - category is mapped/clamped into the allowed set (else Others).
  // Anything missing is defaulted so the row still imports for review.
  List<Map<String, dynamic>> _parseCsv(String text) {
    final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final firstLine = normalized
        .split('\n')
        .firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
    // Detect the delimiter (comma, semicolon or tab).
    final delimiter = {
      ',': ','.allMatches(firstLine).length,
      ';': ';'.allMatches(firstLine).length,
      '\t': '\t'.allMatches(firstLine).length,
    }.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

    final rows = CsvToListConverter(
      shouldParseNumbers: false,
      fieldDelimiter: delimiter,
      eol: '\n',
    ).convert(normalized);
    if (rows.length < 2) {
      throw const FormatException('the file has a header but no data rows');
    }

    final headers = rows.first.map((v) => _normHeader(v.toString())).toList();
    final amountCol = _col(headers, [
      'amount',
      'amt',
      'value',
      'transactionamount',
      'price',
      'total',
      'money',
    ]);
    final debitCol = _col(headers, [
      'debit',
      'withdrawal',
      'withdrawalamt',
      'withdrawalamount',
      'dr',
      'debitamount',
      'moneyout',
      'paidout',
      'outflow',
      'spent',
    ]);
    final creditCol = _col(headers, [
      'credit',
      'deposit',
      'depositamt',
      'depositamount',
      'cr',
      'creditamount',
      'moneyin',
      'paidin',
      'inflow',
      'received',
    ]);
    if (amountCol < 0 && debitCol < 0 && creditCol < 0) {
      throw const FormatException(
        'no amount column was found (need an amount, or debit/credit, column)',
      );
    }
    final dateCol = _col(headers, [
      'date',
      'transactiondate',
      'txndate',
      'valuedate',
      'posteddate',
      'postingdate',
      'datetime',
      'bookingdate',
      'trandate',
    ]);
    final typeCol = _col(headers, [
      'type',
      'transactiontype',
      'drcr',
      'crdr',
      'debitcredit',
      'direction',
      'kind',
    ]);
    final categoryCol = _col(headers, [
      'category',
      'categories',
      'tag',
      'tags',
      'group',
      'head',
    ]);
    final titleCol = _col(headers, [
      'title',
      'description',
      'desc',
      'narration',
      'particulars',
      'details',
      'detail',
      'memo',
      'notes',
      'note',
      'name',
      'transaction',
      'remarks',
      'reference',
      'purpose',
    ]);
    final merchantCol = _col(headers, [
      'merchant',
      'payee',
      'vendor',
      'beneficiary',
      'party',
      'counterparty',
    ]);

    String cell(List<dynamic> row, int i) =>
        (i >= 0 && i < row.length) ? row[i].toString().trim() : '';

    final parsed = <Map<String, dynamic>>[];
    for (final row in rows.skip(1)) {
      if (row.every((v) => v.toString().trim().isEmpty)) continue;

      // Amount + direction.
      double? amount;
      bool isDebit = false, isCredit = false;
      final debitVal = _parseAmount(cell(row, debitCol));
      final creditVal = _parseAmount(cell(row, creditCol));
      final signed = _parseAmount(cell(row, amountCol));
      if (debitVal != null && debitVal.abs() > 0) {
        amount = debitVal.abs();
        isDebit = true;
      } else if (creditVal != null && creditVal.abs() > 0) {
        amount = creditVal.abs();
        isCredit = true;
      } else if (signed != null && signed.abs() > 0) {
        amount = signed.abs();
        if (signed < 0) isDebit = true;
      }
      if (amount == null || amount == 0) continue; // no usable amount → skip

      final type = _inferType(
        cell(row, typeCol),
        signedAmount: signed,
        debit: isDebit,
        credit: isCredit,
      );
      final title =
          _firstNonEmpty([cell(row, titleCol), cell(row, merchantCol)]) ??
          'Imported transaction';
      final merchant = _firstNonEmpty([
        cell(row, merchantCol),
        cell(row, titleCol),
      ]);
      final category = _mapCategory(
        cell(row, categoryCol),
        type,
        '$title ${merchant ?? ''}',
      );
      final date = _parseDate(cell(row, dateCol)) ?? _todayIso();

      parsed.add({
        'title': title.length > 255 ? title.substring(0, 255) : title,
        'amount': amount,
        'category': category,
        'transaction_type': type,
        'date': date,
        if (merchant != null && merchant.isNotEmpty) 'merchant': merchant,
      });
    }
    if (parsed.isEmpty) {
      throw const FormatException('no rows with a valid amount were found');
    }
    return parsed;
  }

  static String _normHeader(String h) =>
      h.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  // Exact normalized match first, then a header-contains-alias fallback.
  static int _col(List<String> headers, List<String> aliases) {
    for (final a in aliases) {
      final i = headers.indexOf(a);
      if (i >= 0) return i;
    }
    for (var i = 0; i < headers.length; i++) {
      for (final a in aliases) {
        if (a.length >= 3 && headers[i].contains(a)) return i;
      }
    }
    return -1;
  }

  static double? _parseAmount(String raw) {
    if (raw.trim().isEmpty) return null;
    var s = raw.trim();
    final negative =
        s.startsWith('-') ||
        (s.startsWith('(') && s.endsWith(')')) ||
        RegExp(r'\b(dr|debit)\b', caseSensitive: false).hasMatch(s);
    s = s.replaceAll(RegExp(r'[^0-9.]'), ''); // strip ₹ $ , spaces letters
    if (s.isEmpty) return null;
    final v = double.tryParse(s);
    if (v == null) return null;
    return negative ? -v : v;
  }

  static String _inferType(
    String rawType, {
    double? signedAmount,
    bool debit = false,
    bool credit = false,
  }) {
    if (credit && !debit) return 'Income';
    if (debit && !credit) return 'Expense';
    final t = rawType.toLowerCase().trim();
    if (RegExp(
      r'income|credit|^cr$|deposit|inflow|received|refund|salary',
    ).hasMatch(t)) {
      return 'Income';
    }
    if (RegExp(
      r'expense|debit|^dr$|withdraw|outflow|payment|paid|spent|purchase',
    ).hasMatch(t)) {
      return 'Expense';
    }
    if (signedAmount != null && signedAmount < 0) return 'Expense';
    return 'Expense'; // safest default for statements
  }

  static String _mapCategory(String raw, String type, String context) {
    final allowed = type == 'Income' ? _incomeCats : _expenseCats;
    final r = raw.trim();
    for (final c in allowed) {
      if (c.toLowerCase() == r.toLowerCase()) return c;
    }
    final text = '$r $context'.toLowerCase();
    if (type == 'Income') {
      if (RegExp(r'salary|payroll|wage|stipend').hasMatch(text)) {
        return 'Salary';
      }
      if (RegExp(r'bonus|incentive').hasMatch(text)) return 'Bonus';
      if (RegExp(r'gift|reward|cashback').hasMatch(text)) return 'Gift';
      if (RegExp(
        r'interest|dividend|investment|return|maturity',
      ).hasMatch(text)) {
        return 'Investment';
      }
      return 'Others';
    }
    if (RegExp(
      r'food|restaurant|cafe|coffee|grocer|dining|snack|swiggy|zomato|meal|lunch|dinner|breakfast|pizza|bakery',
    ).hasMatch(text)) {
      return 'Food';
    }
    if (RegExp(
      r'travel|uber|ola|taxi|cab|train|flight|bus|fuel|petrol|diesel|metro|irctc|transport|toll|parking',
    ).hasMatch(text)) {
      return 'Travel';
    }
    if (RegExp(
      r'bill|electric|water|gas|internet|wifi|phone|mobile|recharge|dth|utility|broadband|insurance|emi|loan|subscription',
    ).hasMatch(text)) {
      return 'Bills';
    }
    if (RegExp(
      r'shop|amazon|flipkart|myntra|cloth|movie|entertain|store|mall|gadget|electronic|apparel|fashion',
    ).hasMatch(text)) {
      return 'Shopping';
    }
    if (RegExp(r'\brent\b|lease').hasMatch(text)) return 'Rent';
    return 'Others';
  }

  static String? _parseDate(String raw) {
    var s = raw.trim().replaceAll(',', '');
    if (s.isEmpty) return null;
    // Drop a trailing time component if present ("2026-07-24 09:00" -> date).
    final isoTry = DateTime.tryParse(s);
    if (isoTry != null) return _fmtDate(isoTry);
    const patterns = [
      'dd/MM/yyyy',
      'dd-MM-yyyy',
      'dd.MM.yyyy',
      'MM/dd/yyyy',
      'yyyy/MM/dd',
      'd MMM yyyy',
      'dd MMM yyyy',
      'MMM d yyyy',
      'MMMM d yyyy',
      'd-MMM-yyyy',
      'dd-MMM-yyyy',
      'dd/MM/yy',
      'MM/dd/yy',
      'yyyyMMdd',
    ];
    for (final p in patterns) {
      try {
        return _fmtDate(DateFormat(p).parseStrict(s));
      } catch (_) {}
    }
    return null;
  }

  static String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String _todayIso() => _fmtDate(DateTime.now());

  static String? _firstNonEmpty(List<String> values) {
    for (final v in values) {
      if (v.trim().isNotEmpty) return v.trim();
    }
    return null;
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
    padding: EdgeInsets.symmetric(
      horizontal: context.isWide ? context.pagePadX : 20,
      vertical: 20,
    ),
    // The picker is a single call to action: centred at a comfortable width
    // over the full-bleed page rather than stretched across the window.
    child: Center(
      child: SizedBox(
        width: context.isWide ? 640 : double.infinity,
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
                        'Works with most bank and app exports. Only an amount '
                        '(or debit/credit) column is required — date, description, '
                        'type and category are detected automatically.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.secondaryText,
                          fontSize: 13,
                        ),
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
      ),
    ),
  );

  Widget _review(AppColors colors, ImportBatch batch) => Center(
    child: ConstrainedBox(
      // A review list is read row by row, so it stays a column instead of
      // spreading each row's checkbox and amount to opposite screen edges.
      constraints: const BoxConstraints(maxWidth: 900),
      child: Column(
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
                    _loading
                        ? 'Confirming…'
                        : 'Add ${_selected.length} expenses',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
