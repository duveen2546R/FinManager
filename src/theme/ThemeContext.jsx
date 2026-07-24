import React, { createContext, useContext, useEffect, useMemo, useState } from 'react';
import { useColorScheme } from 'react-native';
import { Storage } from '../storage';

// Colour palette derived from the original Flutter ThemeData (orange / deepOrange).
const lightColors = {
  isDark: false,
  primary: '#FF5722', // deepOrange
  background: '#F5F5F5', // grey[100]
  card: '#FFFFFF',
  text: '#212121', // black87
  secondaryText: '#757575', // black54
  border: '#E0E0E0',
  income: '#43A047', // green
  expense: '#E53935', // redAccent
};

const darkColors = {
  isDark: true,
  primary: '#FF5722',
  background: '#000000',
  card: '#212121', // grey[900]
  text: '#FFFFFF',
  secondaryText: '#B0B0B0', // white70-ish
  border: '#333333',
  income: '#66BB6A',
  expense: '#EF5350',
};

const ThemeContext = createContext({
  mode: 'system',
  colors: lightColors,
  setMode: () => {},
});

export function ThemeProvider({ children }) {
  const systemScheme = useColorScheme();
  const [mode, setModeState] = useState('system');

  useEffect(() => {
    (async () => {
      const stored = await Storage.getThemeMode();
      if (stored === 'dark' || stored === 'light' || stored === 'system') {
        setModeState(stored);
      }
    })();
  }, []);

  const setMode = (next) => {
    setModeState(next);
    Storage.setThemeMode(next);
  };

  const isDark = mode === 'system' ? systemScheme === 'dark' : mode === 'dark';
  const colors = isDark ? darkColors : lightColors;

  const value = useMemo(() => ({ mode, colors, setMode }), [mode, colors]);

  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}

export function useTheme() {
  return useContext(ThemeContext);
}
