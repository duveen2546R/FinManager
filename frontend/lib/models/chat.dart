class ChatSession {
  final String id;
  final String title;
  final bool isArchived;
  final DateTime? lastMessageAt;

  const ChatSession({
    required this.id,
    required this.title,
    required this.isArchived,
    this.lastMessageAt,
  });

  factory ChatSession.fromJson(Map<String, dynamic> json) => ChatSession(
    id: json['session_id'] as String,
    title: (json['title'] as String?) ?? 'New expense chat',
    isArchived: json['is_archived'] == true,
    lastMessageAt: json['last_message_at'] == null
        ? null
        : DateTime.tryParse(json['last_message_at'].toString()),
  );
}

class ChatMessage {
  final String id;
  final String role; // user | assistant
  final String content;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  bool get isUser => role == 'user';

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['message_id'] as String,
    role: json['role'] as String,
    content: json['content'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}
