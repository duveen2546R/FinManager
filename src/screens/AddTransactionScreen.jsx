import React, { useState } from 'react';
import {
  ActivityIndicator,
  Modal,
  Platform,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  View,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import DateTimePicker from '@react-native-community/datetimepicker';

import { useTheme } from '../theme/ThemeContext';
import { Api } from '../api/client';
import { formatShortDate } from '../utils';
import { Toast } from '../components/Toast';

const EXPENSE_CATEGORIES = ['Food', 'Travel', 'Bills', 'Shopping', 'Rent', 'Others'];
const INCOME_CATEGORIES = ['Salary', 'Bonus', 'Gift', 'Investment', 'Others'];

export default function AddTransactionScreen({ navigation, route }) {
  const { colors } = useTheme();
  const { userId } = route.params;

  const [type, setType] = useState('Expense');
  const [title, setTitle] = useState('');
  const [amount, setAmount] = useState('');
  const [description, setDescription] = useState('');
  const [date, setDate] = useState(new Date());
  const [showDatePicker, setShowDatePicker] = useState(false);
  const [category, setCategory] = useState('Food');
  const [categoryModal, setCategoryModal] = useState(false);
  const [loading, setLoading] = useState(false);
  const [toast, setToast] = useState(null);

  const categories = type === 'Expense' ? EXPENSE_CATEGORIES : INCOME_CATEGORIES;

  const onTypeChange = (next) => {
    setType(next);
    setCategory(next === 'Expense' ? EXPENSE_CATEGORIES[0] : INCOME_CATEGORIES[0]);
  };

  const validate = () => {
    if (!title) return 'Please enter a title';
    const amt = parseFloat(amount);
    if (!amount || isNaN(amt) || amt <= 0) return 'Enter a valid amount';
    if (!category) return 'Please select a category';
    return null;
  };

  const submit = async () => {
    const error = validate();
    if (error) {
      setToast({ msg: error, variant: 'error' });
      return;
    }
    setLoading(true);
    try {
      await Api.addTransaction({
        user_id: userId,
        title,
        description,
        amount,
        category,
        transaction_type: type,
        date: date.toISOString(),
      });
      // Navigate back; Home refreshes automatically via useFocusEffect.
      navigation.goBack();
    } catch (e) {
      setToast({ msg: e?.message ?? 'Could not connect to the server.', variant: 'error' });
    } finally {
      setLoading(false);
    }
  };

  const inputStyle = [styles.input, { color: colors.text, borderColor: colors.border }];

  return (
    <View style={{ flex: 1, backgroundColor: colors.background }}>
      <ScrollView contentContainerStyle={{ padding: 20 }}>
        {/* Segmented Expense / Income toggle */}
        <View style={[styles.segment, { borderColor: colors.primary }]}>
          {['Expense', 'Income'].map((opt) => {
            const active = type === opt;
            return (
              <TouchableOpacity
                key={opt}
                style={[styles.segmentButton, active && { backgroundColor: colors.primary }]}
                onPress={() => onTypeChange(opt)}
              >
                <Ionicons
                  name={opt === 'Expense' ? 'arrow-down' : 'arrow-up'}
                  size={16}
                  color={active ? '#FFFFFF' : colors.text}
                />
                <Text style={{ color: active ? '#FFFFFF' : colors.text, marginLeft: 6, fontWeight: '600' }}>
                  {opt}
                </Text>
              </TouchableOpacity>
            );
          })}
        </View>

        <Text style={[styles.label, { color: colors.secondaryText }]}>Title</Text>
        <TextInput
          style={inputStyle}
          placeholder="e.g., Coffee, Salary"
          placeholderTextColor={colors.secondaryText}
          value={title}
          onChangeText={setTitle}
        />

        <View style={styles.row}>
          <View style={{ flex: 2, marginRight: 16 }}>
            <Text style={[styles.label, { color: colors.secondaryText }]}>Amount</Text>
            <TextInput
              style={inputStyle}
              placeholder="₹ 0.00"
              placeholderTextColor={colors.secondaryText}
              keyboardType="decimal-pad"
              value={amount}
              onChangeText={setAmount}
            />
          </View>
          <View style={{ flex: 3 }}>
            <Text style={[styles.label, { color: colors.secondaryText }]}>Date</Text>
            <TouchableOpacity style={inputStyle} onPress={() => setShowDatePicker(true)}>
              <View style={styles.dateInner}>
                <Text style={{ color: colors.text }}>{formatShortDate(date)}</Text>
                <Ionicons name="calendar" size={18} color={colors.secondaryText} />
              </View>
            </TouchableOpacity>
          </View>
        </View>

        <Text style={[styles.label, { color: colors.secondaryText }]}>Description (Optional)</Text>
        <TextInput
          style={[inputStyle, { height: 80, textAlignVertical: 'top' }]}
          placeholder="Add any extra notes here..."
          placeholderTextColor={colors.secondaryText}
          multiline
          value={description}
          onChangeText={setDescription}
        />

        <Text style={[styles.label, { color: colors.secondaryText }]}>Category</Text>
        <TouchableOpacity style={inputStyle} onPress={() => setCategoryModal(true)}>
          <View style={styles.dateInner}>
            <Text style={{ color: colors.text }}>{category}</Text>
            <Ionicons name="chevron-down" size={18} color={colors.secondaryText} />
          </View>
        </TouchableOpacity>

        <TouchableOpacity
          style={[styles.submit, { backgroundColor: colors.primary, opacity: loading ? 0.7 : 1 }]}
          onPress={submit}
          disabled={loading}
        >
          {loading ? (
            <ActivityIndicator color="#FFFFFF" />
          ) : (
            <Text style={styles.submitText}>Add Transaction</Text>
          )}
        </TouchableOpacity>
      </ScrollView>

      {showDatePicker && (
        <DateTimePicker
          value={date}
          mode="date"
          maximumDate={new Date()}
          minimumDate={new Date(2020, 0, 1)}
          onChange={(event, selected) => {
            setShowDatePicker(Platform.OS === 'ios');
            if (event.type === 'set' && selected) setDate(selected);
          }}
        />
      )}

      {/* Category picker modal */}
      <Modal visible={categoryModal} transparent animationType="slide">
        <TouchableOpacity
          style={styles.modalOverlay}
          activeOpacity={1}
          onPress={() => setCategoryModal(false)}
        >
          <View style={[styles.modalSheet, { backgroundColor: colors.card }]}>
            <Text style={[styles.modalTitle, { color: colors.text }]}>Select Category</Text>
            {categories.map((cat) => (
              <TouchableOpacity
                key={cat}
                style={styles.modalItem}
                onPress={() => {
                  setCategory(cat);
                  setCategoryModal(false);
                }}
              >
                <Text style={{ color: colors.text, fontSize: 16 }}>{cat}</Text>
                {cat === category && <Ionicons name="checkmark" size={20} color={colors.primary} />}
              </TouchableOpacity>
            ))}
          </View>
        </TouchableOpacity>
      </Modal>

      <Toast message={toast?.msg ?? null} variant={toast?.variant} onHide={() => setToast(null)} />
    </View>
  );
}

const styles = StyleSheet.create({
  segment: {
    flexDirection: 'row',
    borderWidth: 1,
    borderRadius: 10,
    overflow: 'hidden',
    marginBottom: 30,
  },
  segmentButton: {
    flex: 1,
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    paddingVertical: 12,
  },
  label: { fontSize: 13, marginBottom: 6, marginTop: 4 },
  input: {
    borderWidth: 1,
    borderRadius: 12,
    paddingHorizontal: 14,
    paddingVertical: 14,
    fontSize: 16,
    marginBottom: 20,
    justifyContent: 'center',
  },
  row: { flexDirection: 'row' },
  dateInner: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  submit: {
    paddingVertical: 16,
    borderRadius: 12,
    alignItems: 'center',
    marginTop: 20,
  },
  submitText: { color: '#FFFFFF', fontSize: 18, fontWeight: 'bold' },
  modalOverlay: { flex: 1, justifyContent: 'flex-end', backgroundColor: 'rgba(0,0,0,0.4)' },
  modalSheet: { borderTopLeftRadius: 16, borderTopRightRadius: 16, padding: 20, paddingBottom: 40 },
  modalTitle: { fontSize: 16, fontWeight: 'bold', marginBottom: 12 },
  modalItem: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 14,
  },
});
