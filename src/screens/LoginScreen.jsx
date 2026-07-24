import React, { useState } from 'react';
import {
  ActivityIndicator,
  Image,
  KeyboardAvoidingView,
  Platform,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  View,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '../theme/ThemeContext';
import { Api } from '../api/client';
import { Storage } from '../storage';
import { Toast } from '../components/Toast';

export default function LoginScreen({ navigation }) {
  const { colors } = useTheme();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [passwordVisible, setPasswordVisible] = useState(false);
  const [loading, setLoading] = useState(false);
  const [toast, setToast] = useState(null);

  const validate = () => {
    if (!email || !email.includes('@')) return 'Please enter a valid email';
    if (!password) return 'Please enter your password';
    return null;
  };

  const login = async () => {
    const error = validate();
    if (error) {
      setToast(error);
      return;
    }
    setLoading(true);
    try {
      const result = await Api.login(email, password);
      await Storage.setLoggedIn(true);
      await Storage.setUser({ user_id: result.user_id, name: result.name, email: result.email });
      navigation.reset({
        index: 0,
        routes: [
          {
            name: 'Home',
            params: {
              user_id: result.user_id,
              name: result.name,
              email: result.email,
              phone_no: result.phone_no,
            },
          },
        ],
      });
    } catch (e) {
      setToast(e?.message ?? 'Could not connect to the server. Please check your network.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <KeyboardAvoidingView
      style={{ flex: 1, backgroundColor: colors.background }}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
    >
      <ScrollView contentContainerStyle={{ flexGrow: 1 }}>
        <Image source={require('../../assets/login_image.png')} style={styles.hero} resizeMode="contain" />

        <View style={styles.padding}>
          <View style={[styles.card, { backgroundColor: colors.card }]}>
            <TextInput
              style={[styles.input, { color: colors.text, borderColor: colors.border }]}
              placeholder="Email"
              placeholderTextColor={colors.secondaryText}
              keyboardType="email-address"
              autoCapitalize="none"
              value={email}
              onChangeText={setEmail}
            />

            <View style={[styles.passwordRow, { borderColor: colors.border }]}>
              <TextInput
                style={[styles.passwordInput, { color: colors.text }]}
                placeholder="Password"
                placeholderTextColor={colors.secondaryText}
                secureTextEntry={!passwordVisible}
                value={password}
                onChangeText={setPassword}
              />
              <TouchableOpacity onPress={() => setPasswordVisible((v) => !v)}>
                <Ionicons
                  name={passwordVisible ? 'eye-off' : 'eye'}
                  size={22}
                  color={colors.secondaryText}
                />
              </TouchableOpacity>
            </View>

            <TouchableOpacity
              style={[styles.button, { opacity: loading ? 0.7 : 1 }]}
              onPress={login}
              disabled={loading}
            >
              {loading ? (
                <ActivityIndicator color="#FFFFFF" />
              ) : (
                <Text style={styles.buttonText}>Login</Text>
              )}
            </TouchableOpacity>

            <TouchableOpacity onPress={() => navigation.navigate('Register')}>
              <Text style={[styles.linkText, { color: colors.secondaryText }]}>
                Don't have an account? Register
              </Text>
            </TouchableOpacity>
          </View>
        </View>
      </ScrollView>
      <Toast message={toast} onHide={() => setToast(null)} />
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  hero: { width: '100%', height: 240 },
  padding: { padding: 20 },
  card: {
    borderRadius: 15,
    padding: 20,
    elevation: 4,
    shadowColor: '#000',
    shadowOpacity: 0.1,
    shadowRadius: 8,
    shadowOffset: { width: 0, height: 2 },
  },
  input: {
    borderBottomWidth: 1,
    paddingVertical: 10,
    fontSize: 16,
    marginBottom: 20,
  },
  passwordRow: {
    flexDirection: 'row',
    alignItems: 'center',
    borderBottomWidth: 1,
    marginBottom: 30,
  },
  passwordInput: { flex: 1, paddingVertical: 10, fontSize: 16 },
  button: {
    backgroundColor: '#FF5722',
    paddingVertical: 15,
    borderRadius: 15,
    alignItems: 'center',
  },
  buttonText: { color: '#FFFFFF', fontSize: 18, fontWeight: 'bold' },
  linkText: { textAlign: 'center', marginTop: 15 },
});
