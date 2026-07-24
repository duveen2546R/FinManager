import React, { useState } from 'react';
import {
  Alert,
  Modal,
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { CommonActions } from '@react-navigation/native';

import { useTheme } from '../theme/ThemeContext';
import { Storage } from '../storage';

export default function AccountScreen({ navigation, route }) {
  const { colors, mode, setMode } = useTheme();
  const { userName, userEmail } = route.params;
  const [themeModal, setThemeModal] = useState(false);

  const logout = () => {
    Alert.alert('Confirm Logout', 'Are you sure you want to log out?', [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Logout',
        style: 'destructive',
        onPress: async () => {
          await Storage.clearUser();
          navigation.dispatch(
            CommonActions.reset({ index: 0, routes: [{ name: 'FirstPage' }] }),
          );
        },
      },
    ]);
  };

  const themeOptions = [
    { key: 'system', label: 'System Default' },
    { key: 'light', label: 'Light Mode' },
    { key: 'dark', label: 'Dark Mode' },
  ];

  return (
    <ScrollView style={{ flex: 1, backgroundColor: colors.background }} contentContainerStyle={{ padding: 16 }}>
      {/* Profile header */}
      <View style={[styles.card, styles.profileCard, { backgroundColor: colors.card }]}>
        <View style={[styles.avatar, { backgroundColor: colors.primary + '33' }]}>
          <Text style={{ fontSize: 32, fontWeight: 'bold', color: colors.primary }}>
            {userName ? userName[0].toUpperCase() : 'U'}
          </Text>
        </View>
        <View style={{ flex: 1, marginLeft: 16 }}>
          <Text style={{ fontSize: 22, fontWeight: 'bold', color: colors.text }} numberOfLines={1}>
            {userName}
          </Text>
          <Text style={{ fontSize: 15, color: colors.secondaryText, marginTop: 4 }} numberOfLines={1}>
            {userEmail}
          </Text>
        </View>
      </View>

      {/* Settings group */}
      <View style={[styles.card, { backgroundColor: colors.card }]}>
        <MenuTile icon="settings-outline" title="Settings" onPress={() => setThemeModal(true)} />
        <View style={[styles.divider, { backgroundColor: colors.border }]} />
        <MenuTile icon="help-circle-outline" title="Help & Support" onPress={() => {}} />
      </View>

      {/* Logout */}
      <View style={[styles.card, { backgroundColor: colors.card }]}>
        <MenuTile icon="log-out-outline" title="Logout" color={colors.expense} onPress={logout} />
      </View>

      {/* Theme settings modal */}
      <Modal visible={themeModal} transparent animationType="fade">
        <TouchableOpacity style={styles.overlay} activeOpacity={1} onPress={() => setThemeModal(false)}>
          <View style={[styles.dialog, { backgroundColor: colors.card }]}>
            <Text style={[styles.dialogTitle, { color: colors.text }]}>Theme Settings</Text>
            {themeOptions.map((opt) => (
              <TouchableOpacity
                key={opt.key}
                style={styles.radioRow}
                onPress={() => {
                  setMode(opt.key);
                  setThemeModal(false);
                }}
              >
                <Ionicons
                  name={mode === opt.key ? 'radio-button-on' : 'radio-button-off'}
                  size={22}
                  color={mode === opt.key ? colors.primary : colors.secondaryText}
                />
                <Text style={{ color: colors.text, fontSize: 16, marginLeft: 12 }}>{opt.label}</Text>
              </TouchableOpacity>
            ))}
          </View>
        </TouchableOpacity>
      </Modal>
    </ScrollView>
  );
}

function MenuTile({ icon, title, color, onPress }) {
  const { colors } = useTheme();
  return (
    <TouchableOpacity style={styles.tile} onPress={onPress}>
      <Ionicons name={icon} size={22} color={color ?? colors.text} />
      <Text style={{ flex: 1, marginLeft: 16, fontSize: 16, fontWeight: '500', color: color ?? colors.text }}>
        {title}
      </Text>
      <Ionicons name="chevron-forward" size={16} color={colors.secondaryText} />
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  card: {
    borderRadius: 16,
    marginBottom: 24,
    elevation: 2,
    shadowColor: '#000',
    shadowOpacity: 0.1,
    shadowRadius: 6,
    shadowOffset: { width: 0, height: 2 },
  },
  profileCard: { flexDirection: 'row', alignItems: 'center', padding: 20 },
  avatar: { width: 70, height: 70, borderRadius: 35, justifyContent: 'center', alignItems: 'center' },
  tile: { flexDirection: 'row', alignItems: 'center', padding: 16 },
  divider: { height: 1, marginHorizontal: 16 },
  overlay: { flex: 1, justifyContent: 'center', alignItems: 'center', backgroundColor: 'rgba(0,0,0,0.4)' },
  dialog: { width: '80%', borderRadius: 12, padding: 20 },
  dialogTitle: { fontSize: 18, fontWeight: 'bold', marginBottom: 16 },
  radioRow: { flexDirection: 'row', alignItems: 'center', paddingVertical: 12 },
});
