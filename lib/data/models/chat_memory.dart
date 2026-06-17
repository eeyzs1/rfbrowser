/// Tier in the progressive-forgetting memory hierarchy.
///
/// Each tier represents a different time horizon and storage strategy:
/// - [short]: Recent, high-fidelity records kept in their original form.
/// - [mid]: Older records whose details may be archived in favor of an L1 summary.
/// - [long]: Oldest records, summarized as L2; raw text typically archived.
enum MemoryTier { short, mid, long }

/// Identifies the summary granularity that replaced the original detail.
enum MemorySummaryTier { none, l1, l2, l3 }

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

/// A memory fragment — either an extracted fact or a synthesized summary.
class MemoryFragment {
  final String id;
  final String sessionId;
  final String content;
  final String category;
  final bool isActive;
  final String? supersededBy;

  // ── Progressive forgetting fields (added in schema v2) ──
  final MemoryTier tier;
  final double importanceScore;
  final int accessCount;
  final DateTime? lastAccessAt;
  final bool isPinned;
  final List<String> mediaRefs;
  final DateTime? archivedAt;
  final MemorySummaryTier summaryTier;
  final String? parentSummaryId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MemoryFragment({
    required this.id,
    required this.sessionId,
    required this.content,
    this.category = 'fact',
    this.isActive = true,
    this.supersededBy,
    this.tier = MemoryTier.short,
    this.importanceScore = 0.0,
    this.accessCount = 0,
    this.lastAccessAt,
    this.isPinned = false,
    this.mediaRefs = const [],
    this.archivedAt,
    this.summaryTier = MemorySummaryTier.none,
    this.parentSummaryId,
    required this.createdAt,
    required this.updatedAt,
  });

  MemoryFragment copyWith({
    String? content,
    String? category,
    bool? isActive,
    String? supersededBy,
    bool clearSupersededBy = false,
    MemoryTier? tier,
    double? importanceScore,
    int? accessCount,
    DateTime? lastAccessAt,
    bool clearLastAccessAt = false,
    bool? isPinned,
    List<String>? mediaRefs,
    DateTime? archivedAt,
    bool clearArchivedAt = false,
    MemorySummaryTier? summaryTier,
    String? parentSummaryId,
    bool clearParentSummaryId = false,
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
      tier: tier ?? this.tier,
      importanceScore: importanceScore ?? this.importanceScore,
      accessCount: accessCount ?? this.accessCount,
      lastAccessAt: clearLastAccessAt
          ? null
          : (lastAccessAt ?? this.lastAccessAt),
      isPinned: isPinned ?? this.isPinned,
      mediaRefs: mediaRefs ?? this.mediaRefs,
      archivedAt: clearArchivedAt ? null : (archivedAt ?? this.archivedAt),
      summaryTier: summaryTier ?? this.summaryTier,
      parentSummaryId: clearParentSummaryId
          ? null
          : (parentSummaryId ?? this.parentSummaryId),
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
    'tier': tier.name,
    'importance_score': importanceScore,
    'access_count': accessCount,
    'last_access_at': lastAccessAt?.toIso8601String(),
    'is_pinned': isPinned ? 1 : 0,
    'media_refs': mediaRefs.isEmpty ? null : mediaRefs.join('|'),
    'archived_at': archivedAt?.toIso8601String(),
    'summary_tier': summaryTier.name,
    'parent_summary_id': parentSummaryId,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory MemoryFragment.fromRow(Map<String, dynamic> row) {
    final tierName = (row['tier'] as String?) ?? MemoryTier.short.name;
    final summaryName =
        (row['summary_tier'] as String?) ?? MemorySummaryTier.none.name;
    final media = (row['media_refs'] as String?)
        ?.split('|')
        .where((s) => s.isNotEmpty)
        .toList();
    return MemoryFragment(
      id: row['id'] as String,
      sessionId: row['session_id'] as String,
      content: row['content'] as String,
      category: (row['category'] as String?) ?? 'fact',
      isActive: (row['is_active'] as int?) == 1,
      supersededBy: row['superseded_by'] as String?,
      tier: MemoryTier.values.firstWhere(
        (t) => t.name == tierName,
        orElse: () => MemoryTier.short,
      ),
      importanceScore:
          (row['importance_score'] as num?)?.toDouble() ?? 0.0,
      accessCount: (row['access_count'] as int?) ?? 0,
      lastAccessAt: row['last_access_at'] == null
          ? null
          : DateTime.parse(row['last_access_at'] as String),
      isPinned: (row['is_pinned'] as int?) == 1,
      mediaRefs: media ?? const [],
      archivedAt: row['archived_at'] == null
          ? null
          : DateTime.parse(row['archived_at'] as String),
      summaryTier: MemorySummaryTier.values.firstWhere(
        (t) => t.name == summaryName,
        orElse: () => MemorySummaryTier.none,
      ),
      parentSummaryId: row['parent_summary_id'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  @override
  String toString() => 'MemoryFragment($category: $content)';
}

/// A consolidated summary produced from a group of fragments.
///
/// Summaries live in the same table as fragments but use [summaryTier] to
/// distinguish themselves; they are the L1/L2/L3 entries in OpenLoomi's
/// three-tier memory pyramid.
class MemorySummary {
  final String summaryId;
  final String userId;
  final MemorySummaryTier summaryTier;
  final MemoryTier sourceTier;
  final DateTime startTimestamp;
  final DateTime endTimestamp;
  final int messageCount;
  final List<String> sourceRecordIds;
  final List<String> keyPoints;
  final List<String> keywords;
  final String summaryText;
  final double? qualityScore;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MemorySummary({
    required this.summaryId,
    required this.userId,
    required this.summaryTier,
    required this.sourceTier,
    required this.startTimestamp,
    required this.endTimestamp,
    required this.messageCount,
    required this.sourceRecordIds,
    required this.keyPoints,
    required this.keywords,
    required this.summaryText,
    this.qualityScore,
    required this.createdAt,
    required this.updatedAt,
  });
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
