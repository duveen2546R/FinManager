import React from 'react';
import { Dimensions, Text } from 'react-native';
import { BarChart } from 'react-native-chart-kit';
import { monthLabel } from '../utils';
import { useTheme } from '../theme/ThemeContext';

export function MonthlyBarChart({ transactions }) {
  const { colors } = useTheme();

  // Group expenses by month (first-of-month key), matching the Flutter BarChartSample.
  const byMonth = new Map();
  for (const txn of transactions) {
    if (txn.type !== 'Expense') continue;
    const key = new Date(txn.date.getFullYear(), txn.date.getMonth()).getTime();
    const existing = byMonth.get(key);
    if (existing) existing.total += txn.amount;
    else byMonth.set(key, { date: new Date(key), total: txn.amount });
  }

  const sorted = [...byMonth.values()].sort((a, b) => a.date.getTime() - b.date.getTime());

  if (sorted.length === 0) {
    return <Text style={{ color: colors.secondaryText, textAlign: 'center' }}>Not enough data for monthly chart.</Text>;
  }

  const data = {
    labels: sorted.map((e) => monthLabel(e.date)),
    datasets: [{ data: sorted.map((e) => e.total) }],
  };

  return (
    <BarChart
      data={data}
      width={Dimensions.get('window').width - 72}
      height={250}
      yAxisLabel="₹"
      yAxisSuffix=""
      fromZero
      showValuesOnTopOfBars
      chartConfig={{
        backgroundGradientFrom: colors.card,
        backgroundGradientTo: colors.card,
        decimalPlaces: 0,
        color: (opacity = 1) => `rgba(38, 166, 154, ${opacity})`, // teal
        labelColor: () => colors.secondaryText,
        barPercentage: 0.6,
      }}
      style={{ borderRadius: 12 }}
    />
  );
}
