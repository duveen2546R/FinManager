import 'package:finmanager/Screens/Home.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Enums for cleaner state management of filters and sorting
enum TransactionTypeFilter { all, income, expense }
enum SortOrder { newestFirst, oldestFirst, amountHighToLow, amountLowToHigh }

class AllTransactionsScreen extends StatefulWidget {
  final List<Transaction> allTransactions;

  const AllTransactionsScreen({super.key, required this.allTransactions});

  @override
  State<AllTransactionsScreen> createState() => _AllTransactionsScreenState();
}

class _AllTransactionsScreenState extends State<AllTransactionsScreen> {
  late List<Transaction> _processedTransactions;
  TransactionTypeFilter _selectedFilter = TransactionTypeFilter.all;
  SortOrder _sortOrder = SortOrder.newestFirst;

  // Map category names to icons for the UI
  final Map<String, IconData> _categoryIcons = {
    'Food': Icons.fastfood, 'Travel': Icons.train, 'Shopping': Icons.shopping_bag,
    'Bills': Icons.receipt_long, 'Income': Icons.attach_money, 'Salary': Icons.work,
    'Others': Icons.more_horiz,
  };

  @override
  void initState() {
    super.initState();
    _processedTransactions = List.from(widget.allTransactions);
    _applyFiltersAndSort(); 
  }

  void _applyFiltersAndSort() {
    List<Transaction> tempTransactions = List.from(widget.allTransactions);

    // Apply Filter
    if (_selectedFilter == TransactionTypeFilter.income) {
      tempTransactions = tempTransactions.where((t) => t.type == 'Income').toList();
    } else if (_selectedFilter == TransactionTypeFilter.expense) {
      tempTransactions = tempTransactions.where((t) => t.type == 'Expense').toList();
    }

    // Apply Sort
    switch (_sortOrder) {
      case SortOrder.newestFirst:
        tempTransactions.sort((a, b) => b.date.compareTo(a.date));
        break;
      case SortOrder.oldestFirst:
        tempTransactions.sort((a, b) => a.date.compareTo(b.date));
        break;
      case SortOrder.amountHighToLow:
        tempTransactions.sort((a, b) => b.amount.compareTo(a.amount));
        break;
      case SortOrder.amountLowToHigh:
        tempTransactions.sort((a, b) => a.amount.compareTo(b.amount));
        break;
    }

    setState(() {
      _processedTransactions = tempTransactions;
    });
  }

  // Groups transactions by date for a cleaner list view
  Map<String, List<Transaction>> _groupTransactionsByDate() {
    final Map<String, List<Transaction>> grouped = {};
    for (var txn in _processedTransactions) {
      String dateKey = DateFormat.yMMMMd().format(txn.date);
      if (grouped[dateKey] == null) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(txn);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final groupedTransactions = _groupTransactionsByDate();
    final dateKeys = groupedTransactions.keys.toList();
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Transactions'),
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.blueGrey[800],
        actions: [
          IconButton(icon: const Icon(Icons.sort), tooltip: 'Sort By', onPressed: () => _showSortOptions(context)),
          IconButton(icon: const Icon(Icons.filter_list), tooltip: 'Filter By', onPressed: () => _showFilterOptions(context)),
        ],
      ),
      backgroundColor: isDarkMode ? Colors.black : Colors.grey[100],
      body: _processedTransactions.isEmpty
          ? const Center(child: Text("No transactions match the current filter."))
          : ListView.builder(
              itemCount: dateKeys.length,
              itemBuilder: (context, index) {
                String dateKey = dateKeys[index];
                List<Transaction> transactionsOnDate = groupedTransactions[dateKey]!;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date Header
                      Padding(
                        padding: const EdgeInsets.only(left: 16.0, top: 8.0, bottom: 8.0),
                        child: Text(
                          dateKey,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDarkMode ? Colors.white70 : Colors.black54),
                        ),
                      ),
                      // --- UPDATED: Use ExpansionTile to show description ---
                      Card(
                        elevation: 2,
                        color: isDarkMode ? Colors.grey[900] : Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        clipBehavior: Clip.antiAlias, // Ensures the ExpansionTile shape matches the Card
                        child: Column(
                          children: transactionsOnDate.map((txn) {
                            bool isExpense = txn.type == 'Expense';
                            bool hasDescription = txn.description != null && txn.description!.isNotEmpty;

                            return ExpansionTile(
                              leading: CircleAvatar(
                                backgroundColor: (isExpense ? Colors.red : Colors.green).withOpacity(0.1),
                                child: Icon(_categoryIcons[txn.category] ?? Icons.category, color: isExpense ? Colors.red : Colors.green),
                              ),
                              title: Text(txn.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(txn.category),
                              trailing: Text(
                                "${isExpense ? '-' : '+'}\$${txn.amount.toStringAsFixed(2)}",
                                style: TextStyle(fontWeight: FontWeight.bold, color: isExpense ? Colors.redAccent : Colors.green),
                              ),
                              // The expandable part of the tile
                              children: [
                                if (hasDescription)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        txn.description!,
                                        style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black54, fontStyle: FontStyle.italic),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  // --- Dialogs for sorting and filtering ---
  void _showSortOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Wrap(
        children: <Widget>[
          ListTile(title: const Text('Sort by', style: TextStyle(fontWeight: FontWeight.bold))),
          ListTile(leading: const Icon(Icons.new_releases), title: const Text('Newest First'), onTap: () {
            setState(() => _sortOrder = SortOrder.newestFirst);
            _applyFiltersAndSort(); Navigator.pop(ctx);
          }),
          ListTile(leading: const Icon(Icons.history), title: const Text('Oldest First'), onTap: () {
            setState(() => _sortOrder = SortOrder.oldestFirst);
            _applyFiltersAndSort(); Navigator.pop(ctx);
          }),
          ListTile(leading: const Icon(Icons.arrow_downward), title: const Text('Amount: High to Low'), onTap: () {
            setState(() => _sortOrder = SortOrder.amountHighToLow);
            _applyFiltersAndSort(); Navigator.pop(ctx);
          }),
          ListTile(leading: const Icon(Icons.arrow_upward), title: const Text('Amount: Low to High'), onTap: () {
            setState(() => _sortOrder = SortOrder.amountLowToHigh);
            _applyFiltersAndSort(); Navigator.pop(ctx);
          }),
        ],
      ),
    );
  }

  void _showFilterOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Wrap(
        children: <Widget>[
          ListTile(title: const Text('Show', style: TextStyle(fontWeight: FontWeight.bold))),
          ListTile(leading: const Icon(Icons.all_inclusive), title: const Text('All Transactions'), onTap: () {
            setState(() => _selectedFilter = TransactionTypeFilter.all);
            _applyFiltersAndSort(); Navigator.pop(ctx);
          }),
          ListTile(leading: const Icon(Icons.arrow_upward, color: Colors.green), title: const Text('Income Only'), onTap: () {
            setState(() => _selectedFilter = TransactionTypeFilter.income);
            _applyFiltersAndSort(); Navigator.pop(ctx);
          }),
          ListTile(leading: const Icon(Icons.arrow_downward, color: Colors.red), title: const Text('Expenses Only'), onTap: () {
            setState(() => _selectedFilter = TransactionTypeFilter.expense);
            _applyFiltersAndSort(); Navigator.pop(ctx);
          }),
        ],
      ),
    );
  }
}