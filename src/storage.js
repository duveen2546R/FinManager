import AsyncStorage from '@react-native-async-storage/async-storage';

// Thin wrapper around AsyncStorage, replacing Flutter's SharedPreferences.
export const Storage = {
  async setLoggedIn(value) {
    await AsyncStorage.setItem('isLoggedIn', value ? 'true' : 'false');
  },
  async isLoggedIn() {
    return (await AsyncStorage.getItem('isLoggedIn')) === 'true';
  },
  async setUser(user) {
    await AsyncStorage.setItem('user_id', user.user_id);
    if (user.name) await AsyncStorage.setItem('user_name', user.name);
    if (user.email) await AsyncStorage.setItem('user_email', user.email);
  },
  async getUser() {
    const [user_id, name, email] = await Promise.all([
      AsyncStorage.getItem('user_id'),
      AsyncStorage.getItem('user_name'),
      AsyncStorage.getItem('user_email'),
    ]);
    return { user_id, name, email };
  },
  async clearUser() {
    await AsyncStorage.multiRemove(['user_id', 'user_name', 'user_email']);
    await AsyncStorage.setItem('isLoggedIn', 'false');
  },
  async getThemeMode() {
    return AsyncStorage.getItem('themeMode');
  },
  async setThemeMode(mode) {
    await AsyncStorage.setItem('themeMode', mode);
  },
};
