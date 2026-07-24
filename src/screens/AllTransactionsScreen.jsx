import React, { useLayoutEffect, useMemo, useState } from 'react';
import {
  Modal,
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';

import { useTheme } from '../theme/ThemeContext';
import { formatLongDate, formatRupee, iconForCategory } from '../utils';

export default function AllTransactionsScreen({ navigation, route }) {
  const { colors } = useTheme();
  const all = route.params.transactions;

  const [filter, setFilter] = useState('all'); // all | income | expense
  const [sort, setSort] = useState('newest'); // newest | oldest | amountHigh | amountLow
  const [expanded, setExpanded] = useState({});
  const [sortModal, setSortModal] = useState(false);
  const [filterModal, setFilterModal] = useState(false);

  useLayoutEffect(() => {
    navigation.setOptions({
      headerRight: () => (
        <View style={{ flexDirection: 'row' }}>
          <TouchableOpacity onPress={() => setSortModal(true)} style={{ marginRight: 16 }}>
            <Ionicons name="swap-vertical" size={22} color={colors.text} />
          </TouchableOpacity>
          <TouchableOpacity onPress={() => setFilterModal(true)}>
            <Ionicons name="filter" size={22} color={colors.text} />
          </TouchableOpacity>
        </View>
      ),
    });
  }, [navigation, colors.text]);

  const processed = useMemo(() => {
    let list = [...all];
    if (filter === 'income') list = list.filter((t) => t.type === 'Income');
    else if (filter === 'expense') list = list.filter((t) => t.type === 'Expense');

    switch (sort) {
      case 'newest':
        list.sort((a, b) => b.date.getTime() - a.date.getTime());
        break;
      case 'oldest':
        list.sort((a, b) => a.date.getTime() - b.date.getTime());
        break;
      case 'amountHigh':
        list.sort((a, b) => b.amount - a.amount);
        break;
      case 'amountLow':
        list.sort((a, b) => a.amount - b.amount);
        break;
    }
    return list;
  }, [all, filter, sort]);

  // Group by formatted date, preserving processed order.
  const groups = useMemo(() => {
    const map = new Map();
    for (const txn of processed) {
      const key = formatLongDate(txn.date);
      if (!map.has(key)) map.set(key, []);
      map.get(key).push(txn);
    }
    return [...map.entries()];
  }, [processed]);

  return (
    <View style={{ flex: 1, backgroundColor: colors.background }}>
      {processed.length === 0 ? (
        <View style={styles.center}>
          <Text style={{ color: colors.secondaryText }}>No transactions match the current filter.</Text>
        </View>
      ) : (
        <ScrollView contentContainerStyle={{ padding: 8 }}>
          {groups.map(([dateKey, txns]) => (
            <View key={dateKey} style={{ marginBottom: 8 }}>
              <Text style={[styles.dateHeader, { color: colors.secondaryText }]}>{dateKey}</Text>
              <View style={[styles.card, { backgroundColor: colors.card }]}>
                {txns.map((txn) => {
                  const isExpense = txn.type === 'Expense';
                  const color = isExpense ? colors.expense : colors.income;
                  const hasDescription = !!txn.description && txn.description.length > 0;
                  const isOpen = expanded[txn.id];
                  return (
                    <View key={txn.id}>
                      <TouchableOpacity
                        style={styles.txnRow}
                        disabled={!hasDescription}
                        onPress={() => setExpanded((prev) => ({ ...prev, [txn.id]: !prev[txn.id] }))}
                      >
                        <View style={[styles.avatar, { backgroundColor: color + '22' }]}>
                          <Ionicons name={iconForCategory(txn.category)} size={20} color={color} />
                        </View>
                        <View style={{ flex: 1 }}>
                          <Text style={{ fontWeight: '600', color: colors.text }}>{txn.title}</Text>
                          <Text style={{ color: colors.secondaryText, fontSize: 13 }}>{txn.category}</Text>
                        </View>
                        <Text style={{ fontWeight: 'bold', color }}>
                          {isExpense ? '-' : '+'}
                          {formatRupee(txn.amount)}
                        </Text>
                        {hasDescription && (
                          <Ionicons
                            name={isOpen ? 'chevron-up' : 'chevron-down'}
                            size={18}
                            color={colors.secondaryText}
                            style={{ marginLeft: 8 }}
                          />
                        )}
                      </TouchableOpacity>
                      {hasDescription && isOpen && (
                        <Text style={[styles.description, { color: colors.secondaryText }]}>
                          {txn.description}
                        </Text>
                      )}
                    </View>
                  );
                })}
              </View>
            </View>
          ))}
        </ScrollView>
      )}

      <OptionSheet
        visible={sortModal}
        title="Sort by"
        onClose={() => setSortModal(false)}
        options={[
          { key: 'newest', label: 'Newest First', icon: 'sparkles' },
          { key: 'oldest', label: 'Oldest First', icon: 'time' },
          { key: 'amountHigh', label: 'Amount: High to Low', icon: 'arrow-down' },
          { key: 'amountLow', label: 'Amount: Low to High', icon: 'arrow-up' },
        ]}
        selected={sort}
        onSelect={(k) => setSort(k)}
      />

      <OptionSheet
        visible={filterModal}
        title="Show"
        onClose={() => setFilterModal(false)}
        options={[
          { key: 'all', label: 'All Transactions', icon: 'infinite' },
          { key: 'income', label: 'Income Only', icon: 'arrow-up', color: colors.income },
          { key: 'expense', label: 'Expenses Only', icon: 'arrow-down', color: colors.expense },
        ]}
        selected={filter}
        onSelect={(k) => setFilter(k)}
      />
    </View>
  );
}

function OptionSheet({ visible, title, options, selected, onSelect, onClose }) {
  const { colors } = useTheme();
  return (
    <Modal visible={visible} transparent animationType="slide">
      <TouchableOpacity style={styles.overlay} activeOpacity={1} onPress={onClose}>
        <View style={[styles.sheet, { backgroundColor: colors.card }]}>
          <Text style={[styles.sheetTitle, { color: colors.text }]}>{title}</Text>
          {options.map((opt) => (
            <TouchableOpacity
              key={opt.key}
              style={styles.sheetItem}
              onPress={() => {
                onSelect(opt.key);
                onClose();
              }}
            >
              <Ionicons name={opt.icon} size={20} color={opt.color ?? colors.text} />
              <Text style={{ color: colors.text, fontSize: 16, marginLeft: 16, flex: 1 }}>
                {opt.label}
              </Text>
              {selected === opt.key && <Ionicons name="checkmark" size={20} color={colors.primary} />}
            </TouchableOpacity>
          ))}
        </View>
      </TouchableOpacity>
    </Modal>
  );
}

const styles = StyleSheet.create({
  center: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  dateHeader: { fontWeight: 'bold', fontSize: 16, marginLeft: 16, marginTop: 8, marginBottom: 8 },
  card: { borderRadius: 12, marginHorizontal: 8, elevation: 2, overflow: 'hidden' },
  txnRow: { flexDirection: 'row', alignItems: 'center', paddingVertical: 12, paddingHorizontal: 16 },
  avatar: {
    width: 40,
    height: 40,
    borderRadius: 20,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 12,
  },
  description: { fontStyle: 'italic', paddingHorizontal: 16, paddingBottom: 16 },
  overlay: { flex: 1, justifyContent: 'flex-end', backgroundColor: 'rgba(0,0,0,0.4)' },
  sheet: { borderTopLeftRadius: 16, borderTopRightRadius: 16, padding: 16, paddingBottom: 40 },
  sheetTitle: { fontSize: 16, fontWeight: 'bold', marginBottom: 8, paddingHorizontal: 8 },
  sheetItem: { flexDirection: 'row', alignItems: 'center', paddingVertical: 14, paddingHorizontal: 8 },
});
