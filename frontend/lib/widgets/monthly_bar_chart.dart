import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../theme/app_colors.dart';
import '../utils.dart';

// Bar chart of monthly expense totals.
class MonthlyBarChart extends StatelessWidget {
  final List<Txn> transactions;
  final AppColors colors;

  const MonthlyBarChart({
    super.key,
    required this.transactions,
    required this.colors,
  });


  @override
  Widget build(BuildContext context) {
    // Group expenses by month (first-of-month key).
    final byMonth = <int, _MonthTotal>{};
    for (final txn in transactions) {
      if (txn.type != 'Expense') continue;
      final key =
          DateTime(txn.date.year, txn.date.month).millisecondsSinceEpoch;
      final existing = byMonth[key];
      if (existing != null) {
        existing.total += txn.amount;
      } else {
        byMonth[key] = _MonthTotal(
            DateTime.fromMillisecondsSinceEpoch(key), txn.amount);
      }
    }

    final sorted = byMonth.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    if (sorted.isEmpty) {
      return Text(
        'Not enough data for monthly chart.',
        style: TextStyle(color: colors.secondaryText),
        textAlign: TextAlign.center,
      );
    }

    final maxY = sorted.fold<double>(0, (m, e) => e.total > m ? e.total : m);

    return SizedBox(
      height: 250,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY * 1.2,
          barTouchData: BarTouchData(enabled: true),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: colors.border, strokeWidth: 0.5),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (value, meta) {
                  if (value == meta.max) return const SizedBox.shrink();
                  return Text(
                    '₹${value.toInt()}',
                    style: TextStyle(color: colors.secondaryText, fontSize: 10),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= sorted.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      monthLabel(sorted[i].date),
                      style:
                          TextStyle(color: colors.secondaryText, fontSize: 11),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < sorted.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: sorted[i].total,
                    color: colors.accent,
                    width: 18,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4)),
                  ),
                ],
                showingTooltipIndicators: const [],
              ),
          ],
        ),
      ),
    );
  }
}

class _MonthTotal {
  final DateTime date;
  double total;
  _MonthTotal(this.date, this.total);
}
