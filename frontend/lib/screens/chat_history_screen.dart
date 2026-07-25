import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';

import '../models/chat.dart';
import '../services/api.dart';
import '../theme/app_colors.dart';
import '../theme/theme_provider.dart';
import '../utils.dart';
import '../widgets/toast.dart';
import '../widgets/responsive.dart';

class ChatHistoryScreen extends StatefulWidget {
  static const route = '/chat-history';
  const ChatHistoryScreen({super.key});

  @override
  State<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen> {
  bool _loading = true;
  List<ChatSession> _sessions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final sessions = await Api.getChatSessions();
      if (mounted) setState(() => _sessions = sessions);
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(ChatSession session) async {
    try {
      await Api.deleteChatSession(session.id);
      if (mounted) {
        setState(() => _sessions.removeWhere((item) => item.id == session.id));
      }
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeProvider>().colors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('Chat history')),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: colors.primary))
          : _sessions.isEmpty
          ? Center(
              child: Text(
                'Your saved expense chats will appear here.',
                style: TextStyle(color: colors.secondaryText),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              // Laptop: saved chats tile across the full window width.
              child: context.isWide
                  ? ListView(
                      padding: EdgeInsets.fromLTRB(
                        context.pagePadX,
                        16,
                        context.pagePadX,
                        40,
                      ),
                      children: [
                        ResponsiveTileGrid(
                          columns: context.screenWidth >= 1500 ? 4 : 3,
                          gap: 12,
                          children: [
                            for (final session in _sessions)
                              _sessionTile(session, colors),
                          ],
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _sessions.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, index) =>
                          _sessionTile(_sessions[index], colors),
                    ),
            ),
    );
  }

  Widget _sessionTile(ChatSession session, AppColors colors) {
    return Dismissible(
      key: ValueKey(session.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Delete conversation?'),
          content: const Text('This cannot be undone.'),
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
      ),
      onDismissed: (_) => _delete(session),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: colors.expense,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Ionicons.trash_outline, color: Colors.white),
      ),
      child: Material(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.pop(context, session),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Ionicons.chatbubble_ellipses_outline,
                  color: colors.primary,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (session.lastMessageAt != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          formatShortDate(session.lastMessageAt!),
                          style: TextStyle(
                            color: colors.secondaryText,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Ionicons.chevron_forward, color: colors.secondaryText),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
