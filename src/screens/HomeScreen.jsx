import React, { useCallback, useEffect, useState } from 'react';
import {
  ActivityIndicator,
  RefreshControl,
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useFocusEffect } from '@react-navigation/native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { useTheme } from '../theme/ThemeContext';
import { Api } from '../api/client';
import { Storage } from '../storage';
import { formatRupee, iconForCategory } from '../utils';
import { SpendingPieChart } from '../components/SpendingPieChart';
import { MonthlyBarChart } from '../components/MonthlyBarChart';

function computeStats(transactions) {
  let totalIncome = 0;
  let totalExpense = 0;
  let highestSpend = 0;
  const spendingByCategory = {};

  for (const txn of transactions) {
    if (txn.type === 'Income') {
      totalIncome += txn.amount;
    } else {
      totalExpense += txn.amount;
      if (txn.amount > highestSpend) highestSpend = txn.amount;
      spendingByCategory[txn.category] = (spendingByCategory[txn.category] ?? 0) + txn.amount;
    }
  }

  // Days since the oldest transaction (list is sorted newest-first from the API).
  const oldest = transactions.length ? transactions[transactions.length - 1].date : new Date();
  const days = Math.max(1, Math.floor((Date.now() - oldest.getTime()) / 86400000) + 1);

  return {
    totalBalance: totalIncome - totalExpense,
    highestSpend,
    dailyAverage: totalExpense / days,
    spendingByCategory,
  };
}

export default function HomeScreen({ navigation, route }) {
  const { colors } = useTheme();
  const insets = useSafeAreaInsets();

  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [errorMessage, setErrorMessage] = useState(null);
  const [userId, setUserId] = useState(null);
  const [userName, setUserName] = useState('User');
  const [userEmail, setUserEmail] = useState('no-email@finmanager.com');
  const [transactions, setTransactions] = useState([]);
  const [stats, setStats] = useState({
    totalBalance: 0,
    highestSpend: 0,
    dailyAverage: 0,
    spendingByCategory: {},
  });

  const fetchData = useCallback(async (id) => {
    setErrorMessage(null);
    try {
      const txns = await Api.getTransactions(id);
      setTransactions(txns);
      setStats(computeStats(txns));
    } catch (e) {
      setErrorMessage(
        e?.message ?? 'Could not connect to the server. Check your network and IP address.',
      );
    }
  }, []);

  // Resolve the user id once (from route args or storage), then load.
  useEffect(() => {
    (async () => {
      let id = route.params?.user_id ?? null;
      let name = route.params?.name ?? null;
      let email = route.params?.email ?? null;
      if (!id) {
        const stored = await Storage.getUser();
        id = stored.user_id;
        name = stored.name;
        email = stored.email;
      }
      setUserName(name ?? 'User');
      setUserEmail(email ?? 'no-email@finmanager.com');
      setUserId(id);
      if (id) {
        await fetchData(id);
      } else {
        setErrorMessage('Could not identify user. Please log in again.');
      }
      setLoading(false);
    })();
  }, []);

  // Refresh when returning from Add Transaction / AI Agent.
  useFocusEffect(
    useCallback(() => {
      if (userId) fetchData(userId);
    }, [userId, fetchData]),
  );

  const onRefresh = async () => {
    if (!userId) return;
    setRefreshing(true);
    await fetchData(userId);
    setRefreshing(false);
  };

  if (loading) {
    return (
      <View style={[styles.center, { backgroundColor: colors.background }]}>
        <ActivityIndicator size="large" color={colors.primary} />
      </View>
    );
  }

  return (
    <View style={{ flex: 1, backgroundColor: colors.background, paddingTop: insets.top }}>
      {/* Custom header (no back button, account action) */}
      <View style={styles.header}>
        <Text style={[styles.headerTitle, { color: colors.text }]}>Dashboard</Text>
        <TouchableOpacity onPress={() => navigation.navigate('Account', { userName, userEmail })}>
          <Ionicons name="person-circle-outline" size={28} color={colors.text} />
        </TouchableOpacity>
      </View>

      {errorMessage ? (
        <View style={styles.center}>
          <Text style={{ color: colors.text, fontSize: 16, textAlign: 'center', marginBottom: 20 }}>
            {errorMessage}
          </Text>
          <TouchableOpacity style={styles.retryButton} onPress={() => userId && fetchData(userId)}>
            <Text style={styles.retryText}>Retry</Text>
          </TouchableOpacity>
        </View>
      ) : (
        <ScrollView
          contentContainerStyle={{ padding: 16, paddingBottom: 120 }}
          refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} />}
        >
          <Text style={{ fontSize: 22, color: colors.secondaryText }}>Welcome Back,</Text>
          <Text style={{ fontSize: 28, fontWeight: 'bold', color: colors.text }}>{userName}</Text>
          <View style={{ height: 20 }} />

          {/* Total balance */}
          <View style={[styles.card, { backgroundColor: colors.card }]}>
            <Text style={{ fontSize: 16, color: colors.secondaryText }}>Total Balance</Text>
            <Text style={{ fontSize: 36, fontWeight: 'bold', color: colors.text, marginTop: 8 }}>
              {formatRupee(stats.totalBalance)}
            </Text>
          </View>

          {/* Quick stats */}
          <View style={[styles.card, styles.statsRow, { backgroundColor: colors.card }]}>
            <StatItem label="Daily Average" value={formatRupee(stats.dailyAverage)} color="#448AFF" />
            <StatItem label="Highest Spend" value={formatRupee(stats.highestSpend)} color="#FF5252" />
          </View>

          {/* Pie */}
          <View style={[styles.card, { backgroundColor: colors.card }]}>
            <Text style={[styles.cardTitle, { color: colors.text }]}>Expense Breakdown</Text>
            <View style={{ alignItems: 'center' }}>
              <SpendingPieChart spendingByCategory={stats.spendingByCategory} />
            </View>
          </View>

          {/* Bar */}
          <View style={[styles.card, { backgroundColor: colors.card }]}>
            <Text style={[styles.cardTitle, { color: colors.text }]}>Monthly Spending</Text>
            <View style={{ alignItems: 'center' }}>
              <MonthlyBarChart transactions={transactions} />
            </View>
          </View>

          {/* Recent transactions */}
          <View style={styles.recentHeader}>
            <Text style={{ fontSize: 20, fontWeight: 'bold', color: colors.text }}>
              Recent Transactions
            </Text>
            <TouchableOpacity onPress={() => navigation.navigate('AllTransactions', { transactions })}>
              <Text style={{ color: colors.primary, fontWeight: '600' }}>View All</Text>
            </TouchableOpacity>
          </View>

          {transactions.length === 0 ? (
            <View style={[styles.card, { backgroundColor: colors.card, alignItems: 'center' }]}>
              <Text style={{ color: colors.secondaryText }}>No transactions recorded yet.</Text>
            </View>
          ) : (
            <View style={[styles.card, { backgroundColor: colors.card, padding: 0 }]}>
              {transactions.slice(0, 5).map((txn) => (
                <TransactionRow key={txn.id} txn={txn} />
              ))}
            </View>
          )}
        </ScrollView>
      )}

      {/* Floating action buttons */}
      <View style={[styles.fabRow, { bottom: insets.bottom + 16 }]}>
        <TouchableOpacity
          style={[styles.fabExtended, { backgroundColor: '#03A9F4' }]}
          onPress={() => userId && navigation.navigate('AiAgent', { userId })}
        >
          <Ionicons name="sparkles" size={20} color="#FFFFFF" />
          <Text style={styles.fabLabel}>AI Agent</Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={[styles.fab, { backgroundColor: '#FF5722' }]}
          onPress={() => userId && navigation.navigate('AddTransaction', { userId })}
        >
          <Ionicons name="add" size={28} color="#FFFFFF" />
        </TouchableOpacity>
      </View>
    </View>
  );
}

function StatItem({ label, value, color }) {
  const { colors } = useTheme();
  return (
    <View style={{ alignItems: 'center' }}>
      <Text style={{ fontSize: 22, fontWeight: 'bold', color }}>{value}</Text>
      <Text style={{ fontSize: 14, color: colors.secondaryText, marginTop: 4 }}>{label}</Text>
    </View>
  );
}

function TransactionRow({ txn }) {
  const { colors } = useTheme();
  const isExpense = txn.type === 'Expense';
  const color = isExpense ? colors.expense : colors.income;
  return (
    <View style={styles.txnRow}>
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
    </View>
  );
}

const styles = StyleSheet.create({
  center: { flex: 1, justifyContent: 'center', alignItems: 'center', padding: 20 },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 12,
  },
  headerTitle: { fontSize: 20, fontWeight: '600' },
  card: {
    borderRadius: 15,
    padding: 20,
    marginBottom: 25,
    elevation: 4,
    shadowColor: '#000',
    shadowOpacity: 0.08,
    shadowRadius: 8,
    shadowOffset: { width: 0, height: 2 },
  },
  cardTitle: { fontSize: 18, fontWeight: 'bold', marginBottom: 20 },
  statsRow: { flexDirection: 'row', justifyContent: 'space-around' },
  recentHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 10,
  },
  txnRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 12,
    paddingHorizontal: 16,
  },
  avatar: {
    width: 40,
    height: 40,
    borderRadius: 20,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 12,
  },
  retryButton: { backgroundColor: '#FF5722', paddingHorizontal: 24, paddingVertical: 10, borderRadius: 8 },
  retryText: { color: '#FFFFFF', fontWeight: 'bold' },
  fabRow: { position: 'absolute', right: 16, flexDirection: 'row', alignItems: 'center' },
  fabExtended: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    height: 48,
    borderRadius: 24,
    marginRight: 16,
    elevation: 6,
  },
  fabLabel: { color: '#FFFFFF', fontWeight: '600', marginLeft: 8 },
  fab: {
    width: 56,
    height: 56,
    borderRadius: 28,
    justifyContent: 'center',
    alignItems: 'center',
    elevation: 6,
  },
});
