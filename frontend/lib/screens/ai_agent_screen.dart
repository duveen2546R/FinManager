import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';

import '../services/api.dart';
import '../models/chat.dart';
import '../services/voice.dart';
import '../theme/app_colors.dart';
import '../theme/theme_provider.dart';
import '../widgets/district/gradient_card.dart';
import '../widgets/district/motion.dart';
import 'chat_history_screen.dart';

class _Message {
  final String text;
  final bool isUser;
  const _Message(this.text, this.isUser);
}

const _examplePrompts = [
  'How much did I spend on Food this month?',
  'What was my biggest expense in August?',
  'Add a 500 rupee expense for a movie ticket',
];

// Conversational AI assistant: answers money questions and adds transactions.
class AiAgentScreen extends StatefulWidget {
  static const route = '/ai-agent';
  const AiAgentScreen({super.key});

  @override
  State<AiAgentScreen> createState() => _AiAgentScreenState();
}

class _AiAgentScreenState extends State<AiAgentScreen> {
  final List<_Message> _messages = [
    const _Message(
      'I can help you understand spending, spot expense changes, and plan around upcoming bills.',
      false,
    ),
  ];
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _loading = false;
  bool _listening = false;
  bool _autoSpeak = false;
  bool _voiceEnabled = false;
  bool _loadingHistory = false;
  // Multi-turn chat: the backend creates a session on the first message and
  // we keep sending into it so the assistant has conversation context.
  String? _sessionId;

  @override
  void initState() {
    super.initState();
    VoiceInput.init().then((available) {
      if (mounted) setState(() => _voiceEnabled = available);
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    VoiceInput.stop();
    TtsService.stop();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _toggleListening() async {
    if (_listening) {
      await VoiceInput.stop();
      setState(() => _listening = false);
    } else {
      setState(() => _listening = true);
      await VoiceInput.start(
        onResult: (text) => setState(() => _input.text = text),
        onEnd: () {
          if (mounted) setState(() => _listening = false);
        },
      );
    }
  }

  Future<void> _openHistory() async {
    final selected = await Navigator.pushNamed(
      context,
      ChatHistoryScreen.route,
    );
    if (selected is! ChatSession || !mounted) return;
    setState(() => _loadingHistory = true);
    try {
      final history = await Api.getChatHistory(selected.id);
      if (!mounted) return;
      setState(() {
        _sessionId = selected.id;
        _messages
          ..clear()
          ..addAll(
            history.map((message) => _Message(message.content, message.isUser)),
          );
      });
      _scrollToEnd();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  void _newChat() {
    setState(() {
      _sessionId = null;
      _messages
        ..clear()
        ..add(
          const _Message(
            'I can help you understand spending, spot expense changes, and plan around upcoming bills.',
            false,
          ),
        );
    });
  }

  Future<void> _deleteCurrentChat() async {
    final sessionId = _sessionId;
    if (sessionId == null) return;
    final colors = context.read<ThemeProvider>().colors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete conversation?'),
        content: const Text(
          'This will permanently remove every message in this chat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Delete', style: TextStyle(color: colors.expense)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _loading = true);
    try {
      await Api.deleteChatSession(sessionId);
      if (!mounted) return;
      _newChat();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Conversation deleted.')));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendMessage([String? text]) async {
    final messageText = (text ?? _input.text).trim();
    if (messageText.isEmpty) return;

    setState(() {
      _messages.add(_Message(messageText, true));
      _input.clear();
      _loading = true;
    });
    _scrollToEnd();

    try {
      final reply = await Api.askAgent(messageText, sessionId: _sessionId);
      if (!mounted) return;
      setState(() {
        _sessionId = reply.sessionId.isEmpty ? _sessionId : reply.sessionId;
        _messages.add(_Message(reply.answer, false));
      });
      if (_autoSpeak) TtsService.speak(reply.answer);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _messages.add(_Message(e.message, false)));
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _messages.add(
          const _Message(
            'Connection Failed. Please check your network, firewall, '
            'and that the server is running.',
            false,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
      _scrollToEnd();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeProvider>().colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Expense assistant'),
        actions: [
          IconButton(
            icon: Icon(Ionicons.time_outline, color: colors.text),
            tooltip: 'Chat history',
            onPressed: _loading || _loadingHistory ? null : _openHistory,
          ),
          IconButton(
            icon: Icon(Ionicons.add_outline, color: colors.text),
            tooltip: 'New chat',
            onPressed: _loading || _loadingHistory ? null : _newChat,
          ),
          if (_sessionId != null)
            IconButton(
              icon: Icon(Ionicons.trash_outline, color: colors.text),
              tooltip: 'Delete conversation',
              onPressed: _loading || _loadingHistory
                  ? null
                  : _deleteCurrentChat,
            ),
          IconButton(
            icon: Icon(
              _autoSpeak ? Ionicons.volume_high : Ionicons.volume_mute,
              color: colors.text,
            ),
            onPressed: () => setState(() => _autoSpeak = !_autoSpeak),
          ),
          IconButton(
            icon: Icon(Ionicons.stop_circle_outline, color: colors.text),
            onPressed: () => TtsService.stop(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              itemCount: _messages.length + 1,
              itemBuilder: (_, i) => i == 0
                  ? EntranceFade(child: _assistantHero(colors))
                  : EntranceFade(
                      delay: const Duration(milliseconds: 40),
                      child: _bubble(_messages[i - 1], colors),
                    ),
            ),
          ),
          if (_loadingHistory)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Loading conversation…',
                style: TextStyle(color: colors.secondaryText),
              ),
            ),
          if (_loading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.secondaryText,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Thinking…',
                    style: TextStyle(color: colors.secondaryText),
                  ),
                ],
              ),
            ),
          if (_messages.length <= 1 && !_loading)
            SizedBox(
              height: 58,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final prompt in _examplePrompts)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ActionChip(
                        backgroundColor: colors.elevated,
                        side: BorderSide(color: Colors.transparent),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        label: Text(
                          prompt,
                          style: TextStyle(
                            color: colors.text,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        onPressed: () => _sendMessage(prompt),
                      ),
                    ),
                ],
              ),
            ),
          _inputArea(colors),
        ],
      ),
    );
  }

  Widget _assistantHero(AppColors colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: AccentCard(
        color: colors.accent,
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: colors.onAccent.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Ionicons.sparkles_outline,
                color: colors.onAccent,
                size: 23,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your expense copilot',
                    style: TextStyle(
                      color: colors.onAccent,
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Ask about merchants, categories, and upcoming costs.',
                    style: TextStyle(
                      color: colors.onAccent.withValues(alpha: 0.72),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubble(_Message item, AppColors colors) {
    final textColor = item.isUser ? colors.onPrimary : colors.text;
    final dashboardBodyStyle = Theme.of(
      context,
    ).textTheme.bodyLarge!.copyWith(fontSize: 15.5);

    final userBubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.72,
      ),
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Text(
        item.text,
        style: dashboardBodyStyle.copyWith(color: textColor, height: 1.35),
      ),
    );
    final assistantBubble = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.78,
      ),
      child: SurfaceCard(
        color: colors.card,
        padding: const EdgeInsets.all(16),
        radius: 22,
        child: MarkdownBody(
          data: item.text,
          styleSheet: MarkdownStyleSheet(
            p: dashboardBodyStyle.copyWith(color: textColor, height: 1.4),
            listBullet: dashboardBodyStyle.copyWith(color: textColor),
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: item.isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!item.isUser)
            Container(
              width: 34,
              height: 34,
              margin: const EdgeInsets.only(right: 10, bottom: 4),
              decoration: BoxDecoration(
                color: colors.accent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Ionicons.sparkles_outline,
                size: 17,
                color: colors.onAccent,
              ),
            ),
          Flexible(child: item.isUser ? userBubble : assistantBubble),
          if (!item.isUser)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: GestureDetector(
                onTap: () => TtsService.speak(item.text),
                child: Icon(
                  Ionicons.volume_high,
                  size: 20,
                  color: colors.secondaryText,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _inputArea(AppColors colors) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: colors.card,
          border: Border(top: BorderSide(color: colors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.only(left: 16, right: 6),
                decoration: BoxDecoration(
                  color: colors.elevated,
                  border: Border.all(color: colors.border),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                          color: colors.text,
                          fontSize: 16,
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) {
                          if (!_loading) _sendMessage();
                        },
                        decoration: InputDecoration(
                          hintText: _listening ? 'Listening…' : 'Message…',
                          hintStyle: TextStyle(color: colors.secondaryText),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                    if (_voiceEnabled)
                      GestureDetector(
                        onTap: _toggleListening,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(
                            _listening
                                ? Ionicons.mic_off
                                : Ionicons.mic_outline,
                            size: 22,
                            color: _listening
                                ? colors.expense
                                : colors.secondaryText,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                if (!_loading) _sendMessage();
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Ionicons.arrow_up,
                  size: 20,
                  color: colors.onPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
