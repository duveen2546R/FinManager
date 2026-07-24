import React, { useEffect, useRef } from 'react';
import { Animated, StyleSheet, Text } from 'react-native';

// Lightweight replacement for Flutter's ScaffoldMessenger.showSnackBar.
// variant: 'error' (red, default) or 'success' (green).
export function Toast({ message, onHide, variant = 'error', duration = 3000 }) {
  const opacity = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    if (!message) return;
    Animated.timing(opacity, { toValue: 1, duration: 200, useNativeDriver: true }).start();
    const timer = setTimeout(() => {
      Animated.timing(opacity, { toValue: 0, duration: 200, useNativeDriver: true }).start(
        ({ finished }) => finished && onHide(),
      );
    }, duration);
    return () => clearTimeout(timer);
  }, [message]);

  if (!message) return null;

  return (
    <Animated.View
      pointerEvents="none"
      style={[
        styles.toast,
        { opacity, backgroundColor: variant === 'success' ? '#43A047' : '#D32F2F' },
      ]}
    >
      <Text style={styles.text}>{message}</Text>
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  toast: {
    position: 'absolute',
    left: 16,
    right: 16,
    bottom: 32,
    borderRadius: 8,
    paddingVertical: 14,
    paddingHorizontal: 16,
    elevation: 6,
    shadowColor: '#000',
    shadowOpacity: 0.2,
    shadowRadius: 6,
    shadowOffset: { width: 0, height: 3 },
  },
  text: { color: '#FFFFFF', fontSize: 14 },
});
