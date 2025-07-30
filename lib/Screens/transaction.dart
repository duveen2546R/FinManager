import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart'; // For formatting the date

// Enum to represent the transaction type for better code readability
enum TransactionType { expense, income }

class AddTransactionScreen extends StatefulWidget {
  final String userId; // The screen requires a userId

  const AddTransactionScreen({super.key, required this.userId});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  // --- NEW: Controller for the description field ---
  final TextEditingController _descriptionController = TextEditingController();
  
  // State variables for the form
  TransactionType _selectedType = TransactionType.expense;
  String? _selectedCategory;
  bool _isLoading = false;

  // Define separate category lists for expenses and income
  final List<String> _expenseCategories = ['Food', 'Travel', 'Bills', 'Shopping', 'Rent', 'Others'];
  final List<String> _incomeCategories = ['Salary', 'Bonus', 'Gift', 'Investment', 'Others'];

  @override
  void initState() {
    super.initState();
    // Set the default category based on the initial transaction type
    _selectedCategory = _expenseCategories.first;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    // --- NEW: Dispose the description controller ---
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitTransaction() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // !! IMPORTANT !!
    // Replace with your computer's local IP address where the Flask server is running.
    const String apiUrl = 'http://10.56.42.175:5000/transaction'; // <--- CHANGE THIS

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': widget.userId,
          'title': _titleController.text,
          // --- NEW: Include the description in the API call ---
          'description': _descriptionController.text,
          'amount': _amountController.text,
          'category': _selectedCategory,
          'transaction_type': _selectedType == TransactionType.income ? 'Income' : 'Expense',
          'date': DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(DateTime.now()),
        }),
      );

      if (!mounted) return;

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transaction for "${_titleController.text}" added!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(responseData['message'] ?? 'Failed to add transaction.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not connect to the server. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final currentCategories = _selectedType == TransactionType.expense 
        ? _expenseCategories 
        : _incomeCategories;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Add New Transaction"),
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.blueGrey[700],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Toggle for Expense/Income ---
              SegmentedButton<TransactionType>(
                segments: const <ButtonSegment<TransactionType>>[
                  ButtonSegment<TransactionType>(value: TransactionType.expense, label: Text('Expense'), icon: Icon(Icons.arrow_downward)),
                  ButtonSegment<TransactionType>(value: TransactionType.income, label: Text('Income'), icon: Icon(Icons.arrow_upward)),
                ],
                selected: {_selectedType},
                onSelectionChanged: (Set<TransactionType> newSelection) {
                  setState(() {
                    _selectedType = newSelection.first;
                    _selectedCategory = (_selectedType == TransactionType.expense) ? _expenseCategories.first : _incomeCategories.first;
                  });
                },
              ),
              const SizedBox(height: 30),

              // --- Title Field ---
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: "Title",
                  hintText: "e.g., Coffee, Salary",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) => (value == null || value.isEmpty) ? 'Please enter a title' : null,
              ),
              const SizedBox(height: 20),

              // --- Amount Field ---
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: "Amount",
                  prefixText: "\$ ",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter an amount';
                  if (double.tryParse(value) == null || double.parse(value) <= 0) return 'Please enter a valid, positive number';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              
              // --- NEW: Description Field ---
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: "Description (Optional)",
                  hintText: "Add any extra notes here...",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                keyboardType: TextInputType.multiline,
                maxLines: 3, // Allow for more text
                // No validator as it is an optional field in the schema
              ),
              const SizedBox(height: 20),

              // --- Category Dropdown ---
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  labelText: "Category",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: currentCategories.map((String category) => DropdownMenuItem<String>(value: category, child: Text(category))).toList(),
                onChanged: (newValue) => setState(() => _selectedCategory = newValue),
                validator: (value) => value == null ? 'Please select a category' : null,
              ),
              const SizedBox(height: 40),

              // --- Submit Button ---
              ElevatedButton(
                onPressed: _isLoading ? null : _submitTransaction,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: isDarkMode ? Colors.deepOrange : Colors.blueGrey[800],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                    : const Text("Add Transaction", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}