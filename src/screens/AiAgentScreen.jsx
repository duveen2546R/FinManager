import React, { useEffect, useRef, useState } from 'react';
import {
  ActivityIndicator,
  FlatList,
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
import Markdown from 'react-native-markdown-display';
import * as Speech from 'expo-speech';
import { useNavigation } from '@react-navigation/native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { useTheme } from '../theme/ThemeContext';
import { Api } from '../api/client';
import { isVoiceAvailable, VoiceInput } from '../voice';

const EXAMPLE_PROMPTS = [
  'How much did I spend on Food this month?',
  'What was my biggest expense in August?',
  'Add a 500 rupee expense for a movie ticket',
];

export default function AiAgentScreen({ route }) {
  const { colors } = useTheme();
  const insets = useSafeAreaInsets();
  const navigation = useNavigation();
  const { userId } = route.params;

  const [messages, setMessages] = useState([
    {
      text: 'Hello! How can I help you with your finances today? You can ask me to find or add transactions.',
      isUser: false,
    },
  ]);
  const [input, setInput] = useState('');
  const [loading, setLoading] = useState(false);
  const [listening, setListening] = useState(false);
  const [autoSpeak, setAutoSpeak] = useState(false);
  const voiceEnabled = isVoiceAvailable();

  const listRef = useRef(null);

  // Header actions: auto-speak toggle + stop speaking.
  useEffect(() => {
    navigation.setOptions({
      headerRight: () => (
        <View style={{ flexDirection: 'row' }}>
          <TouchableOpacity onPress={() => setAutoSpeak((v) => !v)} style={{ marginRight: 16 }}>
            <Ionicons
              name={autoSpeak ? 'volume-high' : 'volume-mute'}
              size={22}
              color={colors.text}
            />
          </TouchableOpacity>
          <TouchableOpacity onPress={() => Speech.stop()}>
            <Ionicons name="stop-circle-outline" size={22} color={colors.text} />
          </TouchableOpacity>
        </View>
      ),
    });
  }, [navigation, autoSpeak, colors.text]);

  // Wire up voice recognition callbacks.
  useEffect(() => {
    if (!voiceEnabled) return;
    const unsubscribe = VoiceInput.subscribe(
      (text) => setInput(text),
      () => setListening(false),
    );
    return unsubscribe;
  }, [voiceEnabled]);

  const speak = (text) => {
    Speech.speak(text, { language: 'en-US', pitch: 1.0 });
  };

  const toggleListening = async () => {
    if (listening) {
      await VoiceInput.stop();
      setListening(false);
    } else {
      setListening(true);
      await VoiceInput.start();
    }
  };

  const sendMessage = async (text) => {
    const messageText = (text ?? input).trim();
    if (!messageText) return;

    setMessages((prev) => [...prev, { text: messageText, isUser: true }]);
    setInput('');
    setLoading(true);

    try {
      const answer = await Api.askAgent(userId, messageText);
      setMessages((prev) => [...prev, { text: answer, isUser: false }]);
      if (autoSpeak) speak(answer);
    } catch {
      setMessages((prev) => [
        ...prev,
        {
          text: 'Connection Failed. Please check your network, firewall, and that the server is running.',
          isUser: false,
        },
      ]);
    } finally {
      setLoading(false);
    }
  };

  const renderBubble = ({ item }) => {
    const userBubble = '#007AFF';
    const aiBubble = colors.isDark ? '#2C2C2E' : '#E5E5EA';
    const textColor = item.isUser ? '#FFFFFF' : colors.text;

    return (
      <View style={[styles.bubbleRow, { justifyContent: item.isUser ? 'flex-end' : 'flex-start' }]}>
        {!item.isUser && (
          <Ionicons name="sparkles" size={18} color={colors.secondaryText} style={{ marginRight: 8, marginBottom: 4 }} />
        )}
        <View
          style={[
            styles.bubble,
            {
              backgroundColor: item.isUser ? userBubble : aiBubble,
              borderBottomLeftRadius: item.isUser ? 20 : 4,
              borderBottomRightRadius: item.isUser ? 4 : 20,
            },
          ]}
        >
          {item.isUser ? (
            <Text style={{ color: textColor, fontSize: 16 }}>{item.text}</Text>
          ) : (
            <Markdown
              style={{
                body: { color: textColor, fontSize: 16 },
                bullet_list: { color: textColor },
                ordered_list: { color: textColor },
              }}
            >
              {item.text}
            </Markdown>
          )}
        </View>
        {!item.isUser && (
          <TouchableOpacity onPress={() => speak(item.text)} style={{ marginLeft: 4 }}>
            <Ionicons name="volume-high" size={20} color={colors.secondaryText} />
          </TouchableOpacity>
        )}
      </View>
    );
  };

  return (
    <KeyboardAvoidingView
      style={{ flex: 1, backgroundColor: colors.background }}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      keyboardVerticalOffset={90}
    >
      <FlatList
        ref={listRef}
        data={messages}
        keyExtractor={(_, i) => String(i)}
        renderItem={renderBubble}
        contentContainerStyle={{ padding: 16 }}
        onContentSizeChange={() => listRef.current?.scrollToEnd({ animated: true })}
      />

      {loading && (
        <View style={styles.typingRow}>
          <ActivityIndicator size="small" color={colors.secondaryText} />
          <Text style={{ color: colors.secondaryText, marginLeft: 8 }}>Thinking…</Text>
        </View>
      )}

      {messages.length <= 1 && !loading && (
        <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.prompts}>
          {EXAMPLE_PROMPTS.map((prompt) => (
            <TouchableOpacity
              key={prompt}
              style={[styles.promptChip, { backgroundColor: colors.card, borderColor: colors.border }]}
              onPress={() => sendMessage(prompt)}
            >
              <Text style={{ color: colors.text, fontWeight: '500' }}>{prompt}</Text>
            </TouchableOpacity>
          ))}
        </ScrollView>
      )}

      {/* Input area */}
      <View
        style={[
          styles.inputArea,
          { backgroundColor: colors.card, borderTopColor: colors.border, paddingBottom: insets.bottom || 8 },
        ]}
      >
        <View style={[styles.inputPill, { backgroundColor: colors.background, borderColor: colors.border }]}>
          <TextInput
            style={[styles.textInput, { color: colors.text }]}
            placeholder={listening ? 'Listening…' : 'Message…'}
            placeholderTextColor={colors.secondaryText}
            value={input}
            onChangeText={setInput}
            onSubmitEditing={() => !loading && sendMessage()}
            returnKeyType="send"
          />
          {voiceEnabled && (
            <TouchableOpacity onPress={toggleListening} style={{ paddingHorizontal: 6 }}>
              <Ionicons
                name={listening ? 'mic-off' : 'mic-outline'}
                size={22}
                color={listening ? colors.expense : colors.secondaryText}
              />
            </TouchableOpacity>
          )}
        </View>
        <TouchableOpacity
          style={styles.sendButton}
          onPress={() => !loading && sendMessage()}
          disabled={loading}
        >
          <Ionicons name="arrow-up" size={20} color="#FFFFFF" />
        </TouchableOpacity>
      </View>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  bubbleRow: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    marginVertical: 4,
  },
  bubble: {
    maxWidth: '75%',
    paddingVertical: 10,
    paddingHorizontal: 14,
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
  },
  typingRow: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: 16, paddingVertical: 8 },
  prompts: { paddingHorizontal: 12, paddingBottom: 8, flexGrow: 0 },
  promptChip: {
    borderWidth: 1,
    borderRadius: 24,
    paddingHorizontal: 12,
    paddingVertical: 8,
    marginHorizontal: 4,
    justifyContent: 'center',
  },
  inputArea: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 12,
    paddingTop: 8,
    borderTopWidth: 1,
  },
  inputPill: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    borderWidth: 1,
    borderRadius: 24,
    paddingLeft: 16,
    paddingRight: 6,
  },
  textInput: { flex: 1, paddingVertical: 10, fontSize: 16 },
  sendButton: {
    marginLeft: 8,
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: '#007AFF',
    justifyContent: 'center',
    alignItems: 'center',
  },
});
