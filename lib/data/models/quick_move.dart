import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';

enum QuickMoveType { user, preset }

const _defaultIconCodePoint = 0xe0a2;

class QuickMove {
  final String id;
  final String name;
  final String promptTemplate;
  final int iconCodePoint;
  final int colorValue;
  final QuickMoveType type;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastUsedAt;
  final int useCount;

  QuickMove({
    String? id,
    required this.name,
    required this.promptTemplate,
    this.iconCodePoint = _defaultIconCodePoint,
    this.colorValue = 0xFF0EA5E9,
    this.type = QuickMoveType.user,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.lastUsedAt,
    this.useCount = 0,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');

  Color get color => Color(colorValue);

  QuickMove copyWith({
    String? name,
    String? promptTemplate,
    int? iconCodePoint,
    int? colorValue,
    QuickMoveType? type,
    DateTime? updatedAt,
    DateTime? lastUsedAt,
    int? useCount,
    bool clearLastUsedAt = false,
  }) {
    return QuickMove(
      id: id,
      name: name ?? this.name,
      promptTemplate: promptTemplate ?? this.promptTemplate,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorValue: colorValue ?? this.colorValue,
      type: type ?? this.type,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      lastUsedAt: clearLastUsedAt ? null : (lastUsedAt ?? this.lastUsedAt),
      useCount: useCount ?? this.useCount,
    );
  }

  String resolvePrompt(Map<String, String> args) {
    var result = promptTemplate;
    for (final entry in args.entries) {
      result = result.replaceAll('{${entry.key}}', entry.value);
    }
    return result;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'promptTemplate': promptTemplate,
        'iconCodePoint': iconCodePoint,
        'colorValue': colorValue,
        'type': type.name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'lastUsedAt': lastUsedAt?.toIso8601String(),
        'useCount': useCount,
      };

  factory QuickMove.fromJson(Map<String, dynamic> json) => QuickMove(
        id: json['id'] as String,
        name: json['name'] as String,
        promptTemplate: json['promptTemplate'] as String,
        iconCodePoint: json['iconCodePoint'] as int? ?? _defaultIconCodePoint,
        colorValue: json['colorValue'] as int? ?? 0xFF0EA5E9,
        type: QuickMoveType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => QuickMoveType.user,
        ),
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'] as String)
            : DateTime.now(),
        lastUsedAt: json['lastUsedAt'] != null
            ? DateTime.parse(json['lastUsedAt'] as String)
            : null,
        useCount: json['useCount'] as int? ?? 0,
      );

  static List<QuickMove> defaultPresets() => [
        QuickMove(
          id: 'preset_translate',
          name: '翻译',
          promptTemplate:
              'Translate the following text to English. Only return the translation, no explanations:\n\n{input}',
          iconCodePoint: 0xe8e2,
          colorValue: 0xFF64748B,
          type: QuickMoveType.preset,
        ),
        QuickMove(
          id: 'preset_summarize',
          name: '总结',
          promptTemplate:
              'Summarize the following content in 3 bullet points:\n\n{input}',
          iconCodePoint: 0xf071,
          colorValue: 0xFF0EA5E9,
          type: QuickMoveType.preset,
        ),
        QuickMove(
          id: 'preset_explain',
          name: '解释',
          promptTemplate:
              'Explain the following concept in simple terms:\n\n{input}',
          iconCodePoint: 0xea4a,
          colorValue: 0xFF8B5CF6,
          type: QuickMoveType.preset,
        ),
        QuickMove(
          id: 'preset_email',
          name: '邮件',
          promptTemplate:
              'Write a professional email based on the following context:\n\n{input}',
          iconCodePoint: 0xe158,
          colorValue: 0xFF10B981,
          type: QuickMoveType.preset,
        ),
        QuickMove(
          id: 'preset_grammar',
          name: '语法',
          promptTemplate:
              'Fix grammar and spelling errors in the following text. Only return the corrected version:\n\n{input}',
          iconCodePoint: 0xe8ce,
          colorValue: 0xFFF59E0B,
          type: QuickMoveType.preset,
        ),
      ];
}

class QuickMoveState {
  final List<QuickMove> moves;
  final Map<String, QuickMove> byId;

  QuickMoveState({
    List<QuickMove>? moves,
    Map<String, QuickMove>? byId,
  })  : moves = moves ?? [],
        byId = byId ?? {};

  factory QuickMoveState.initial() {
    final presets = QuickMove.defaultPresets();
    final byId = <String, QuickMove>{};
    for (final m in presets) {
      byId[m.id] = m;
    }
    return QuickMoveState(moves: presets, byId: byId);
  }

  List<QuickMove> get byLastUsed {
    final sorted = List<QuickMove>.from(moves);
    sorted.sort((a, b) {
      final aTime = a.lastUsedAt ?? a.createdAt;
      final bTime = b.lastUsedAt ?? b.createdAt;
      return bTime.compareTo(aTime);
    });
    return sorted;
  }

  List<QuickMove> matching(String prefix) {
    if (prefix.isEmpty) return byLastUsed;
    return byLastUsed
        .where((m) => m.name.toLowerCase().contains(prefix.toLowerCase()))
        .toList();
  }

  QuickMoveState copyWith({
    List<QuickMove>? moves,
  }) {
    final newMoves = moves ?? this.moves;
    final byId = <String, QuickMove>{};
    for (final m in newMoves) {
      byId[m.id] = m;
    }
    return QuickMoveState(moves: newMoves, byId: byId);
  }

  Map<String, dynamic> toJson() => {
        'moves': moves.map((m) => m.toJson()).toList(),
      };

  factory QuickMoveState.fromJson(Map<String, dynamic> json) {
    final movesList = (json['moves'] as List<dynamic>?)
            ?.map((e) => QuickMove.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    final byId = <String, QuickMove>{};
    for (final m in movesList) {
      byId[m.id] = m;
    }
    return QuickMoveState(moves: movesList, byId: byId);
  }
}

class QuickMoveContext {
  final String? currentUrl;
  final String? pageTitle;
  final String? pageContent;
  final String? selectedText;
  final String? noteContent;

  QuickMoveContext({
    this.currentUrl,
    this.pageTitle,
    this.pageContent,
    this.selectedText,
    this.noteContent,
  });

  QuickMoveContext copyWith({
    String? currentUrl,
    String? pageTitle,
    String? pageContent,
    String? selectedText,
    String? noteContent,
    bool clearCurrentUrl = false,
    bool clearPageTitle = false,
    bool clearPageContent = false,
    bool clearSelectedText = false,
    bool clearNoteContent = false,
  }) {
    return QuickMoveContext(
      currentUrl: clearCurrentUrl ? null : (currentUrl ?? this.currentUrl),
      pageTitle: clearPageTitle ? null : (pageTitle ?? this.pageTitle),
      pageContent:
          clearPageContent ? null : (pageContent ?? this.pageContent),
      selectedText:
          clearSelectedText ? null : (selectedText ?? this.selectedText),
      noteContent:
          clearNoteContent ? null : (noteContent ?? this.noteContent),
    );
  }
}
