import React from 'react';
import { Dimensions, Text } from 'react-native';
import { PieChart } from 'react-native-chart-kit';
import { useTheme } from '../theme/ThemeContext';

const palette = [
  '#42A5F5', '#EF5350', '#66BB6A', '#FFA726',
  '#AB47BC', '#26A69A', '#EC407A', '#FFCA28',
];

export function SpendingPieChart({ spendingByCategory }) {
  const { colors } = useTheme();
  const entries = Object.entries(spendingByCategory);
  const total = entries.reduce((sum, [, v]) => sum + v, 0);

  if (entries.length === 0 || total === 0) {
    return <Text style={{ color: colors.secondaryText, textAlign: 'center' }}>No expense data for chart.</Text>;
  }

  const data = entries.map(([name, value], i) => ({
    name,
    amount: value,
    color: palette[i % palette.length],
    legendFontColor: colors.text,
    legendFontSize: 13,
  }));

  return (
    <PieChart
      data={data}
      width={Dimensions.get('window').width - 72}
      height={240}
      accessor="amount"
      backgroundColor="transparent"
      paddingLeft="8"
      chartConfig={{ color: () => colors.text }}
    />
  );
}
