import 'package:finmanager/Screens/account.dart';
import 'package:finmanager/Screens/aiagent.dart';
import 'package:finmanager/Screens/all_transactions.dart';
import 'package:finmanager/Screens/transaction.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // Import for API calls
import 'dart:convert';                   // Import for JSON handling
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math';

// --- Transaction model to match the backend JSON structure ---
class Transaction {
  final String id;
  final String title;
  final String? description;
  final String category;
  final double amount;
  final String type; // 'Income' or 'Expense'
  final DateTime date;

  Transaction({
    required this.id,
    required this.title,
    this.description,
    required this.category,
    required this.amount,
    required this.type,
    required this.date,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['transaction_id'],
      title: json['title'],
      description: json['description'],
      category: json['category'],
      amount: double.parse(json['amount'].toString()),
      type: json['transaction_type'],
      date: DateTime.parse(json['date']),
    );
  }
}

// --- HomeScreen StatefulWidget ---
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // --- State variables ---
  bool _isLoading = true;
  String? _errorMessage;
  String _userName = 'User';
  String? _userId;
  String _userEmail = '';

  List<Transaction> _transactions = [];
  double _totalBalance = 0;
  double _highestSpend = 0;
  double _dailyAverage = 0;
  Map<String, double> _spendingByCategory = {};

  final Map<String, IconData> _categoryIcons = {
    'Food': Icons.fastfood, 'Travel': Icons.train, 'Shopping': Icons.shopping_bag,
    'Bills': Icons.receipt_long, 'Income': Icons.attach_money, 'Salary': Icons.work,
    'Others': Icons.more_horiz,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      _userId = args['user_id'];
      _userName = args['name'] ?? 'User';
      _userEmail = args['email'] ?? 'no-email@finmanager.com';

      if (_userId != null) {
        _fetchDashboardData();
      } else {
        setState(() {
          _errorMessage = "Could not identify user. Please log in again.";
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _fetchDashboardData() async {
    if (_userId == null) return;
    setState(() { _isLoading = true; _errorMessage = null; });

    final String apiUrl = 'http://10.56.42.175:5000/transactions/$_userId';

    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final List<dynamic> transactionList = responseData['transactions'];
        final List<Transaction> fetchedTransactions =
            transactionList.map((json) => Transaction.fromJson(json)).toList();
        _processTransactions(fetchedTransactions);
      } else {
        final responseData = jsonDecode(response.body);
        setState(() => _errorMessage = responseData['message'] ?? 'Failed to load data.');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Could not connect to the server. Check your network and IP address.');
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  void _processTransactions(List<Transaction> transactions) {
    double totalIncome = 0, totalExpense = 0, highestSingleSpend = 0;
    Map<String, double> categorySpending = {};
    for (var txn in transactions) {
      if (txn.type == 'Income') { totalIncome += txn.amount;
      } else if (txn.type == 'Expense') {
        totalExpense += txn.amount;
        if (txn.amount > highestSingleSpend) highestSingleSpend = txn.amount;
        categorySpending.update(txn.category, (v) => v + txn.amount, ifAbsent: () => txn.amount);
      }
    }
    final int days = transactions.isNotEmpty ? DateTime.now().difference(transactions.last.date).inDays + 1 : 1;
    final double average = totalExpense / (days > 0 ? days : 1);
    setState(() {
      _transactions = transactions; _totalBalance = totalIncome - totalExpense;
      _highestSpend = highestSingleSpend; _dailyAverage = average;
      _spendingByCategory = categorySpending;
    });
  }
  
  void _navigateAndRefresh() async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => AddTransactionScreen(userId: _userId!)));
    if (result == true) _fetchDashboardData();
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    Color primaryTextColor = isDarkMode ? Colors.white : Colors.black87;
    Color secondaryTextColor = isDarkMode ? Colors.white70 : Colors.black54;
    Color cardBackgroundColor = isDarkMode ? Colors.grey[900]! : Colors.white;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.grey[100],
      appBar: AppBar(
        title: const Text("Dashboard"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), tooltip: "Refresh Data", onPressed: _isLoading ? null : _fetchDashboardData),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: "My Account",
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => AccountScreen(userName: _userName, userEmail: _userEmail)));
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_errorMessage!, style: const TextStyle(fontSize: 16), textAlign: TextAlign.center),
                        const SizedBox(height: 20),
                        ElevatedButton(onPressed: _fetchDashboardData, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchDashboardData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Welcome Back,", style: TextStyle(fontSize: 22, color: secondaryTextColor)),
                        Text(_userName, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: primaryTextColor)),
                        const SizedBox(height: 20),
                        
                        _buildTotalBalanceCard(cardBackgroundColor, secondaryTextColor, primaryTextColor),
                        const SizedBox(height: 25),
                        _buildQuickStatsCard(cardBackgroundColor, isDarkMode),
                        const SizedBox(height: 25),
                        _buildPieChartCard(cardBackgroundColor, primaryTextColor, isDarkMode),
                        const SizedBox(height: 25),
                        _buildBarChartCard(cardBackgroundColor, primaryTextColor, isDarkMode),
                        const SizedBox(height: 25),
                        _buildRecentTransactions(primaryTextColor, cardBackgroundColor),
                        
                        const SizedBox(height: 100), // Padding for FAB
                      ],
                    ),
                  ),
                ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // --- UPDATED: AI Agent Button ---
            FloatingActionButton.extended(
              onPressed: () {
                // Navigate to the AI Agent screen
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AiAgentScreen(userId: _userId!)),
                );
              },
              heroTag: 'ai_agent_fab',
              label: const Text("AI Agent"),
              icon: const Icon(Icons.auto_awesome),
              backgroundColor: Colors.deepPurple,
            ),
            const SizedBox(width: 16),
            FloatingActionButton(
              onPressed: _navigateAndRefresh,
              heroTag: 'add_transaction_fab',
              backgroundColor: Colors.deepOrange,
              tooltip: 'Add Transaction',
              child: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }

  // --- Reusable Helper Methods for Building UI Components ---
  Widget _buildTotalBalanceCard(Color cardBackgroundColor, Color secondaryTextColor, Color primaryTextColor) {
    return Card(
      elevation: 4, color: cardBackgroundColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Total Balance", style: TextStyle(fontSize: 16, color: secondaryTextColor)),
            const SizedBox(height: 8),
            Text("\$${_totalBalance.toStringAsFixed(2)}", style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: primaryTextColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStatsCard(Color cardBackgroundColor, bool isDarkMode) {
    return Card(
      elevation: 4, color: cardBackgroundColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem("Daily Average", "\$${_dailyAverage.toStringAsFixed(2)}", Colors.blueAccent, isDarkMode),
            _buildStatItem("Highest Spend", "\$${_highestSpend.toStringAsFixed(2)}", Colors.redAccent, isDarkMode),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPieChartCard(Color cardBackgroundColor, Color primaryTextColor, bool isDarkMode) {
    return Card(
      elevation: 4, color: cardBackgroundColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Expense Breakdown", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryTextColor)),
            const SizedBox(height: 20),
            SizedBox(height: 300, child: PieChartSample(isDarkMode: isDarkMode, spendingData: _spendingByCategory)),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChartCard(Color cardBackgroundColor, Color primaryTextColor, bool isDarkMode) {
    return Card(
      elevation: 4, color: cardBackgroundColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Monthly Spending", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryTextColor)),
            const SizedBox(height: 20),
            SizedBox(height: 250, child: BarChartSample(isDarkMode: isDarkMode, transactions: _transactions)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTransactions(Color primaryTextColor, Color cardBackgroundColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text("Recent Transactions", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryTextColor)),
            TextButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => AllTransactionsScreen(allTransactions: _transactions)));
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _transactions.isEmpty
            ? Card(color: cardBackgroundColor, child: const Padding(padding: EdgeInsets.all(20.0), child: Center(child: Text("No transactions recorded yet."))))
            : Card(
                elevation: 4, color: cardBackgroundColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Column(
                  children: _transactions.take(5).map((txn) {
                    bool isExpense = txn.type == 'Expense';
                    return ListTile(
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
                    );
                  }).toList(),
                ),
              ),
      ],
    );
  }
  
  Widget _buildStatItem(String title, String value, Color color, bool isDarkMode) {
    return Column(children: [
      Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
      const SizedBox(height: 4),
      Text(title, style: TextStyle(fontSize: 14, color: isDarkMode ? Colors.white70 : Colors.black54)),
    ]);
  }
}

// --- Pie Chart Widget with Legend ---
class PieChartSample extends StatelessWidget {
  final bool isDarkMode;
  final Map<String, double> spendingData;
  const PieChartSample({super.key, required this.isDarkMode, required this.spendingData});

  @override
  Widget build(BuildContext context) {
    if (spendingData.isEmpty) return const Center(child: Text("No expense data for chart."));
    final double totalSpending = spendingData.values.reduce((a, b) => a + b);
    if (totalSpending == 0) return const Center(child: Text("No spending to display in chart."));
    
    final colorList = [
      Colors.blue.shade400, Colors.red.shade400, Colors.green.shade400, Colors.orange.shade400,
      Colors.purple.shade400, Colors.teal.shade400, Colors.pink.shade400, Colors.amber.shade400,
    ];
    int colorIndex = 0;
    final chartSections = spendingData.entries.map((entry) {
      final color = colorList[colorIndex % colorList.length]; colorIndex++;
      final percentage = (entry.value / totalSpending) * 100;
      return PieChartSectionData(
        color: color, value: entry.value, title: '${percentage.toStringAsFixed(0)}%',
        radius: 50, titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 2)]),
      );
    }).toList();

    colorIndex = 0;
    final legendIndicators = spendingData.entries.map((entry) {
      final color = colorList[colorIndex % colorList.length]; colorIndex++;
      return LegendIndicator(color: color, text: entry.key, isSquare: true);
    }).toList();

    return Column(children: [
      Expanded(child: PieChart(PieChartData(
        pieTouchData: PieTouchData(touchCallback: (event, pieTouchResponse) {}),
        borderData: FlBorderData(show: false), sectionsSpace: 2, centerSpaceRadius: 40, sections: chartSections,
      ))),
      const SizedBox(height: 16),
      Wrap(spacing: 12, runSpacing: 8, alignment: WrapAlignment.center, children: legendIndicators)
    ]);
  }
}

// --- Reusable Legend Indicator Widget ---
class LegendIndicator extends StatelessWidget {
  const LegendIndicator({super.key, required this.color, required this.text, this.isSquare = false, this.size = 16, this.textColor});
  final Color color; final String text; final bool isSquare; final double size; final Color? textColor;
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
      Container(width: size, height: size, decoration: BoxDecoration(shape: isSquare ? BoxShape.rectangle : BoxShape.circle, color: color)),
      const SizedBox(width: 8),
      Text(text, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor))
    ]);
  }
}

// --- Bar Chart Widget ---
class BarChartSample extends StatelessWidget {
  final bool isDarkMode;
  final List<Transaction> transactions;
  const BarChartSample({super.key, required this.isDarkMode, required this.transactions});

  Map<DateTime, double> _calculateMonthlySpending() {
    final Map<DateTime, double> data = {};
    for (var txn in transactions) {
      if (txn.type == 'Expense') {
        final monthKey = DateTime(txn.date.year, txn.date.month);
        data.update(monthKey, (value) => value + txn.amount, ifAbsent: () => txn.amount);
      }
    }
    return data;
  }

  @override
  Widget build(BuildContext context) {
    final monthlySpending = _calculateMonthlySpending();
    if (monthlySpending.isEmpty) return const Center(child: Text("Not enough data for monthly chart."));
    final maxY = monthlySpending.values.reduce(max);
    
    final barGroups = monthlySpending.entries.map((entry) {
      return BarChartGroupData(x: entry.key.month, barRods: [
        BarChartRodData(toY: entry.value, color: isDarkMode ? Colors.teal.shade400 : Colors.teal, width: 20, borderRadius: BorderRadius.circular(4)),
      ]);
    }).toList();

    return BarChart(BarChartData(
      barTouchData: BarTouchData(touchTooltipData: BarTouchTooltipData(tooltipBgColor: isDarkMode ? Colors.grey[800] : Colors.blueGrey)),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (double value, TitleMeta meta) {
            final monthStr = DateFormat.MMM().format(DateTime(0, value.toInt()));
            return SideTitleWidget(axisSide: meta.axisSide, space: 8, child: Text(monthStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)));
          },
          reservedSize: 38,
        )),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, interval: maxY > 0 ? (maxY / 5).ceilToDouble() : 1)),
      ),
      borderData: FlBorderData(show: false),
      barGroups: barGroups,
      gridData: const FlGridData(show: true, drawVerticalLine: false),
    ));
  }
}