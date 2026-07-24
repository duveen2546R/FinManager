import React from 'react';
import { Image, StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import { useTheme } from '../theme/ThemeContext';

export default function FirstPageScreen({ navigation }) {
  const { colors } = useTheme();

  return (
    <View style={[styles.root, { backgroundColor: colors.background }]}>
      {/* Logo section (~60%) */}
      <View style={styles.logoSection}>
        <Image source={require('../../assets/logo.png')} style={styles.logo} resizeMode="contain" />
      </View>

      {/* Description strip (~10%) */}
      <View style={[styles.descStrip, { backgroundColor: colors.isDark ? '#1A1A1A' : '#FFE0B2' }]}>
        <Text style={[styles.descText, { color: colors.text }]}>
          Track your expenses, manage budgets, and visualize financial stats with your AI-powered
          FinManager.
        </Text>
      </View>

      {/* Buttons section (~30%) */}
      <View style={styles.buttonsSection}>
        <TouchableOpacity
          style={[styles.button, { backgroundColor: colors.isDark ? '#FF5722' : '#424242' }]}
          onPress={() => navigation.replace('Login')}
        >
          <Text style={styles.buttonText}>Login</Text>
        </TouchableOpacity>

        <View style={{ height: 30 }} />

        <TouchableOpacity
          style={[styles.button, { backgroundColor: colors.isDark ? '#FF5722' : '#424242' }]}
          onPress={() => navigation.navigate('Register')}
        >
          <Text style={styles.buttonText}>Register</Text>
        </TouchableOpacity>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1 },
  logoSection: { flex: 60, width: '100%' },
  logo: { width: '100%', height: '100%' },
  descStrip: {
    flex: 10,
    width: '100%',
    justifyContent: 'center',
    paddingHorizontal: 20,
    paddingVertical: 10,
  },
  descText: { textAlign: 'center', fontSize: 15 },
  buttonsSection: { flex: 30, justifyContent: 'center', alignItems: 'center' },
  button: {
    width: '60%',
    paddingVertical: 18,
    borderRadius: 20,
    alignItems: 'center',
    elevation: 10,
    shadowColor: '#FF9800',
    shadowOpacity: 0.5,
    shadowRadius: 8,
    shadowOffset: { width: 0, height: 4 },
  },
  buttonText: { color: '#FFFFFF', fontSize: 18, fontWeight: 'bold' },
});
