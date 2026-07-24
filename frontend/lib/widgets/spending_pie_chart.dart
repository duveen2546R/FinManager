import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

// Pie chart of expense spend by category.
class SpendingPieChart extends StatelessWidget {
  final Map<String, double> spendingByCategory;
  final AppColors colors;

  const SpendingPieChart({
    super.key,
    required this.spendingByCategory,
    required this.colors,
  });

  // Neobank palette: lime lead, then muted supporting tones.
  static const List<Color> _palette = [
    Color(0xFFC8E84E), Color(0xFF6C9BFF), Color(0xFFFFB84D), Color(0xFFFF7A9E),
    Color(0xFF52C79B), Color(0xFFA98BFF), Color(0xFFFFD84D), Color(0xFF9AA0A6),
  ];

  @override
  Widget build(BuildContext context) {
    final entries = spendingByCategory.entries.toList();
    final total = entries.fold<double>(0, (sum, e) => sum + e.value);

    if (entries.isEmpty || total == 0) {
      return Text(
        'No expense data for chart.',
        style: TextStyle(color: colors.secondaryText),
        textAlign: TextAlign.center,
      );
    }

    final sections = <PieChartSectionData>[];
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      final pct = e.value / total * 100;
      sections.add(PieChartSectionData(
        value: e.value,
        color: _palette[i % _palette.length],
        title: '${pct.toStringAsFixed(0)}%',
        radius: 90,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Color(0xFF171717),
        ),
      ));
    }

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 0,
              sectionsSpace: 2,
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Legend
        Wrap(
          spacing: 16,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i < entries.length; i++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _palette[i % _palette.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    entries[i].key,
                    style: TextStyle(color: colors.text, fontSize: 13),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
