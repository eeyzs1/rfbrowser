/// A single message in a chat conversation.
class ChatRecord {
  final String id;
  final String sessionId;
  final String role;
  final String content;
  final DateTime timestamp;

  const ChatRecord({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'session_id': sessionId,
    'role': role,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
  };

  factory ChatRecord.fromJson(Map<String, dynamic> json) => ChatRecord(
    id: json['id'] as String,
    sessionId: json['session_id'] as String,
    role: json['role'] as String,
    content: json['content'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
  );
}

/// A synthesized memory fragment extracted from conversations.
class MemoryFragment {
  final String id;
  final String sessionId;
  final String content;
  final String category;
  final bool isActive;
  final String? supersededBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MemoryFragment({
    required this.id,
    required this.sessionId,
    required this.content,
    this.category = 'fact',
    this.isActive = true,
    this.supersededBy,
    required this.createdAt,
    required this.updatedAt,
  });

  MemoryFragment copyWith({
    String? content,
    String? category,
    bool? isActive,
    String? supersededBy,
    bool clearSupersededBy = false,
    DateTime? updatedAt,
  }) {
    return MemoryFragment(
      id: id,
      sessionId: sessionId,
      content: content ?? this.content,
      category: category ?? this.category,
      isActive: isActive ?? this.isActive,
      supersededBy: clearSupersededBy
          ? null
          : (supersededBy ?? this.supersededBy),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toRow() => {
    'id': id,
    'session_id': sessionId,
    'content': content,
    'category': category,
    'is_active': isActive ? 1 : 0,
    'superseded_by': supersededBy,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory MemoryFragment.fromRow(Map<String, dynamic> row) => MemoryFragment(
    id: row['id'] as String,
    sessionId: row['session_id'] as String,
    content: row['content'] as String,
    category: (row['category'] as String?) ?? 'fact',
    isActive: (row['is_active'] as int?) == 1,
    supersededBy: row['superseded_by'] as String?,
    createdAt: DateTime.parse(row['created_at'] as String),
    updatedAt: DateTime.parse(row['updated_at'] as String),
  );

  @override
  String toString() => 'MemoryFragment($category: $content)';
}

/// A chat session grouping related messages.
class ChatSession {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  ChatSession copyWith({String? title, DateTime? updatedAt}) {
    return ChatSession(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
