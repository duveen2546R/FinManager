import 'package:finmanager/Screens/config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

// Enum for transaction type for better code readability
enum TransactionType { expense, income }

class AddTransactionScreen extends StatefulWidget {
  final String userId; // The screen now requires a userId

  const AddTransactionScreen({super.key, required this.userId});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  
  // State variables for the form
  DateTime _selectedDate = DateTime.now();
  TransactionType _selectedType = TransactionType.expense;
  String? _selectedCategory;
  bool _isLoading = false;

  // Define separate category lists for expenses and income
  final List<String> _expenseCategories = ['Food', 'Travel', 'Bills', 'Shopping', 'Rent', 'Others'];
  final List<String> _incomeCategories = ['Salary', 'Bonus', 'Gift', 'Investment', 'Others'];

  @override
  void initState() {
    super.initState();
    _selectedCategory = _expenseCategories.first;
    // Set the initial text for the date field
    _dateController.text = DateFormat.yMMMd().format(_selectedDate);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  // --- Function to show the date picker ---
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020), // Set a reasonable start date
      lastDate: DateTime.now(),   // User can't select a future date
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat.yMMMd().format(_selectedDate);
      });
    }
  }

  Future<void> _submitTransaction() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    // !! IMPORTANT !!
    // Replace with your computer's local IP address or your deployed server URL.
    const String apiUrl = AppConfig.addTransactionEndpoint; // Example IP

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': widget.userId,
          'title': _titleController.text,
          'description': _descriptionController.text,
          'amount': _amountController.text,
          'category': _selectedCategory,
          'transaction_type': _selectedType == TransactionType.income ? 'Income' : 'Expense',
          // Send the user-selected date in a standard format
          'date': _selectedDate.toIso8601String(),
        }),
      );

      if (!mounted) return;
      final responseData = jsonDecode(response.body);

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Transaction for "${_titleController.text}" added!'),
          backgroundColor: Colors.green,
        ));
        // Return 'true' to signal to the HomeScreen that it needs to refresh
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(responseData['message'] ?? 'Failed to add transaction.'),
          backgroundColor: Colors.red,
        ));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not connect to the server. Please check your IP and network.'),
        backgroundColor: Colors.red,
      ));
    } finally {
      setState(() => _isLoading = false);
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
      backgroundColor: isDarkMode ? Colors.black : Colors.grey[100],
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

              // --- Row for Amount and Date Fields ---
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Amount Field
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _amountController,
                      decoration: InputDecoration(
                        labelText: "Amount",
                        prefixText: "₹ ", // Rupee Symbol for India
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Enter an amount';
                        if (double.tryParse(value) == null || double.parse(value) <= 0) return 'Enter a valid number';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Date Field
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _dateController,
                      decoration: InputDecoration(
                        labelText: "Date",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        suffixIcon: const Icon(Icons.calendar_today),
                      ),
                      readOnly: true,
                      onTap: () => _selectDate(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // --- Description Field ---
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: "Description (Optional)",
                  hintText: "Add any extra notes here...",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                keyboardType: TextInputType.multiline,
                maxLines: 3,
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
                  foregroundColor: Colors.white,
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