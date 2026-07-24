import React, { useEffect, useState } from 'react';
import { ActivityIndicator, View } from 'react-native';
import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { StatusBar } from 'expo-status-bar';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { SafeAreaProvider } from 'react-native-safe-area-context';

import { Storage } from './src/storage';
import { ThemeProvider, useTheme } from './src/theme/ThemeContext';

import FirstPageScreen from './src/screens/FirstPageScreen';
import LoginScreen from './src/screens/LoginScreen';
import RegisterScreen from './src/screens/RegisterScreen';
import HomeScreen from './src/screens/HomeScreen';
import AddTransactionScreen from './src/screens/AddTransactionScreen';
import AiAgentScreen from './src/screens/AiAgentScreen';
import AllTransactionsScreen from './src/screens/AllTransactionsScreen';
import AccountScreen from './src/screens/AccountScreen';

const Stack = createNativeStackNavigator();

function Navigation({ initialRoute }) {
  const { colors } = useTheme();
  return (
    <NavigationContainer>
      <StatusBar style={colors.isDark ? 'light' : 'dark'} />
      <Stack.Navigator
        initialRouteName={initialRoute}
        screenOptions={{
          headerStyle: { backgroundColor: colors.background },
          headerTintColor: colors.text,
          headerShadowVisible: false,
          contentStyle: { backgroundColor: colors.background },
        }}
      >
        <Stack.Screen name="FirstPage" component={FirstPageScreen} options={{ headerShown: false }} />
        <Stack.Screen name="Login" component={LoginScreen} options={{ title: 'Login' }} />
        <Stack.Screen name="Register" component={RegisterScreen} options={{ title: 'Register' }} />
        <Stack.Screen name="Home" component={HomeScreen} options={{ headerShown: false }} />
        <Stack.Screen name="AddTransaction" component={AddTransactionScreen} options={{ title: 'Add New Transaction' }} />
        <Stack.Screen name="AiAgent" component={AiAgentScreen} options={{ title: 'FinManager AI' }} />
        <Stack.Screen name="AllTransactions" component={AllTransactionsScreen} options={{ title: 'All Transactions' }} />
        <Stack.Screen name="Account" component={AccountScreen} options={{ title: 'My Account' }} />
      </Stack.Navigator>
    </NavigationContainer>
  );
}

export default function App() {
  const [initialRoute, setInitialRoute] = useState(null);

  useEffect(() => {
    (async () => {
      const loggedIn = await Storage.isLoggedIn();
      setInitialRoute(loggedIn ? 'Home' : 'FirstPage');
    })();
  }, []);

  if (!initialRoute) {
    return (
      <View style={{ flex: 1, justifyContent: 'center', alignItems: 'center' }}>
        <ActivityIndicator size="large" color="#FF5722" />
      </View>
    );
  }

  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <SafeAreaProvider>
        <ThemeProvider>
          <Navigation initialRoute={initialRoute} />
        </ThemeProvider>
      </SafeAreaProvider>
    </GestureHandlerRootView>
  );
}
