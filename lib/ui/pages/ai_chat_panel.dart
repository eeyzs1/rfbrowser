// ignore_for_file: unused_element, unused_element_parameter
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../l10n/app_localizations.dart';
import '../../services/ai_service.dart';
import '../../services/agent_chat_bridge.dart';
import '../../services/settings_service.dart';
import '../../services/knowledge_service.dart';
import '../../services/browser_service.dart';
import '../../services/memory_service.dart';
import '../../services/memory_stats_service.dart';
import '../../data/models/ai_provider.dart';
import '../../data/models/chat_memory.dart';
import '../../core/context/assembler.dart';
import '../../core/context/reference_parser.dart';

part 'ai_chat/ai_chat_autocomplete.dart';
part 'ai_chat/ai_chat_messages.dart';
part 'ai_chat/ai_chat_model_selector.dart';
part 'ai_chat/ai_chat_skills.dart';
part 'ai_chat/ai_chat_actions.dart';
part 'ai_chat/ai_chat_memory_widgets.dart';

class AIChatPanel extends ConsumerStatefulWidget {
  const AIChatPanel({super.key});

  @override
  ConsumerState<AIChatPanel> createState() => _AIChatPanelState();
}

/// Base class holding shared state fields and core infrastructure.
/// UI builders and action handlers live in mixins (part files).
abstract class _AIChatPanelStateBase extends ConsumerState<AIChatPanel> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  List<_AutocompleteItem> _autocompleteItems = [];
  bool _showAutocomplete = false;
  bool _agentMode = false;
  bool _showSessionSidebar = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 50), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  IconData _iconForRefType(ContextRefType type) {
    switch (type) {
      case ContextRefType.note:
        return Icons.description;
      case ContextRefType.web:
        return Icons.language;
      case ContextRefType.clip:
        return Icons.content_cut;
      case ContextRefType.file:
        return Icons.insert_drive_file;
      case ContextRefType.agent:
        return Icons.smart_toy;
    }
  }

  // --- Abstract declarations for cross-mixin method calls ---
  void _onTextChanged();
  void _applyAutocomplete(_AutocompleteItem item);
  Widget _buildMessage(ThemeData theme, ChatMessage msg);
  Widget _buildModelSelector(ThemeData theme, AIState aiState);
  void _showSkillPicker(ThemeData theme);
  void _sendMessage();
  void _saveAsNote(String content);
}

class _AIChatPanelState extends _AIChatPanelStateBase
    with
        _AIChatAutocompleteMixin,
        _AIChatMessagesMixin,
        _AIChatModelSelectorMixin,
        _AIChatSkillsMixin,
        _AIChatActionsMixin {
  @override
  Widget build(BuildContext context) {
    final aiState = ref.watch(aiProvider);
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;

    ref.listen<AIState>(aiProvider, (prev, next) {
      if (prev?.messages.length != next.messages.length ||
          (prev?.messages.isNotEmpty == true &&
              next.messages.isNotEmpty &&
              prev!.messages.last.content != next.messages.last.content)) {
        _scrollToBottom();
      }
    });

    return Row(
      children: [
        // 会话列表侧栏（可折叠）
        if (_showSessionSidebar) _buildSessionSidebar(theme, aiState),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: aiState.messages.isEmpty
                    ? Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.08,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  Icons.psychology,
                                  size: 28,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                l.aiAssistant,
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l.askMeAnything,
                                style: theme.textTheme.bodySmall,
                              ),
                              const SizedBox(height: 24),
                              // 示例提示词卡片，点击后自动填入输入框
                              _buildExamplePrompts(theme),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(12),
                        itemCount: aiState.messages.length,
                        itemBuilder: (context, index) {
                          final msg = aiState.messages[index];
                          return _buildMessage(theme, msg);
                        },
                      ),
              ),
        if (aiState.error != null)
          Container(
            padding: const EdgeInsets.all(8),
            color: theme.colorScheme.error.withValues(alpha: 0.1),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  size: 16,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    aiState.error!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
                // 重试按钮：重新发送上一条用户消息
                IconButton(
                  icon: const Icon(Icons.refresh, size: 14),
                  onPressed: aiState.isLoading
                      ? null
                      : () => ref.read(aiProvider.notifier).retryLastMessage(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  tooltip: l.retry,
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 14),
                  onPressed: () => ref.read(aiProvider.notifier).clearError(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: theme.dividerColor)),
          ),
          child: Row(
            children: [
              // 会话侧栏切换按钮
              SizedBox(
                width: 24,
                height: 24,
                child: IconButton(
                  icon: Icon(
                    _showSessionSidebar
                        ? Icons.view_quilt
                        : Icons.view_quilt_outlined,
                    size: 12,
                  ),
                  onPressed: () => setState(
                    () => _showSessionSidebar = !_showSessionSidebar,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                  tooltip: l.sessions,
                  style: IconButton.styleFrom(
                    backgroundColor: _showSessionSidebar
                        ? theme.colorScheme.primary.withValues(alpha: 0.15)
                        : theme.colorScheme.surface,
                    side: BorderSide(color: theme.dividerColor),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              _buildModelSelector(theme, aiState),
              const SizedBox(width: 4),
              SizedBox(
                width: 24,
                height: 24,
                child: IconButton(
                  icon: const Icon(Icons.auto_awesome, size: 12),
                  onPressed: () => _showSkillPicker(theme),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                  tooltip: 'Skills',
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.surface,
                    side: BorderSide(color: theme.dividerColor),
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: 24,
                height: 24,
                child: IconButton(
                  icon: const Icon(Icons.add_comment_outlined, size: 12),
                  onPressed: () =>
                      ref.read(aiProvider.notifier).createSession(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                  tooltip: l.newSession,
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.surface,
                    side: BorderSide(color: theme.dividerColor),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 24,
                height: 24,
                child: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 12),
                  onPressed: () =>
                      ref.read(aiProvider.notifier).clearMessages(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                  tooltip: l.clearChat,
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.surface,
                    side: BorderSide(color: theme.dividerColor),
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: theme.dividerColor)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_showAutocomplete && _autocompleteItems.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.dividerColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: _autocompleteItems.length,
                    itemBuilder: (context, index) {
                      final item = _autocompleteItems[index];
                      return InkWell(
                        onTap: () => _applyAutocomplete(item),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _iconForRefType(item.type),
                                size: 14,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      item.label,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (item.description.isNotEmpty)
                                      Text(
                                        item.description,
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: theme.hintColor,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              if (_showAutocomplete) const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: CallbackShortcuts(
                      bindings: {
                        // Enter 发送消息，Shift+Enter 换行（默认行为）
                        const SingleActivator(LogicalKeyboardKey.enter):
                            _sendMessage,
                      },
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        style: theme.textTheme.bodyMedium,
                        maxLines: 5,
                        minLines: 1,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: l.enterMessage,
                          hintStyle: theme.textTheme.bodySmall,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      _agentMode
                          ? Icons.auto_awesome
                          : Icons.auto_awesome_outlined,
                      size: 18,
                      color: _agentMode
                          ? theme.colorScheme.primary
                          : theme.hintColor,
                    ),
                    tooltip: _agentMode ? l.agentModeOn : l.agentModeOff,
                    onPressed: () => setState(() => _agentMode = !_agentMode),
                    style: IconButton.styleFrom(
                      backgroundColor: _agentMode
                          ? theme.colorScheme.primary.withValues(alpha: 0.15)
                          : Colors.transparent,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: aiState.isLoading
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.onPrimary,
                            ),
                          )
                        : const Icon(Icons.send, size: 18),
                    onPressed: aiState.isLoading ? null : _sendMessage,
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建会话列表侧栏
  Widget _buildSessionSidebar(ThemeData theme, AIState aiState) {
    final l = AppLocalizations.of(context)!;
    final sessions = aiState.sessions;
    final currentId = aiState.currentSessionId;

    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          right: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Column(
        children: [
          // 侧栏标题栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: theme.dividerColor),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.chat_bubble_outline, size: 14, color: theme.hintColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l.sessions,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(
                  width: 20,
                  height: 20,
                  child: IconButton(
                    icon: const Icon(Icons.add, size: 12),
                    onPressed: () =>
                        ref.read(aiProvider.notifier).createSession(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    tooltip: l.newSession,
                  ),
                ),
              ],
            ),
          ),
          // 会话列表
          Expanded(
            child: sessions.isEmpty
                ? Center(
                    child: Text(
                      l.noSessions,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      final isActive = session.id == currentId;
                      final title = session.title.isEmpty
                          ? l.defaultSessionTitle
                          : session.title;
                      return _buildSessionTile(
                        theme,
                        session.id,
                        title,
                        session.createdAt,
                        isActive,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// 构建单个会话列表项
  Widget _buildSessionTile(
    ThemeData theme,
    String sessionId,
    String title,
    DateTime createdAt,
    bool isActive,
  ) {
    final l = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    String timeLabel;
    if (diff.inDays == 0) {
      timeLabel = l.today;
    } else if (diff.inDays == 1) {
      timeLabel = l.yesterday;
    } else {
      timeLabel = l.daysAgo(diff.inDays);
    }

    return GestureDetector(
      onTap: () => ref.read(aiProvider.notifier).switchSession(sessionId),
      onSecondaryTapDown: (details) =>
          _showSessionContextMenu(details.globalPosition, sessionId, title),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? theme.colorScheme.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(
              isActive ? Icons.chat_bubble : Icons.chat_bubble_outline,
              size: 12,
              color: isActive
                  ? theme.colorScheme.primary
                  : theme.hintColor,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      color: isActive
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    timeLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.hintColor,
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

  /// 显示会话右键菜单（重命名/删除）
  void _showSessionContextMenu(
    Offset position,
    String sessionId,
    String currentTitle,
  ) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        PopupMenuItem(
          value: 'rename',
          child: Row(
            children: [
              Icon(Icons.edit, size: 14, color: theme.hintColor),
              const SizedBox(width: 8),
              Text(l.renameSession, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 14, color: theme.colorScheme.error),
              const SizedBox(width: 8),
              Text(l.deleteSession, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'rename') {
        _showRenameSessionDialog(sessionId, currentTitle);
      } else if (value == 'delete') {
        _confirmDeleteSession(sessionId);
      }
    });
  }

  /// 显示重命名会话对话框
  void _showRenameSessionDialog(String sessionId, String currentTitle) {
    final l = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: currentTitle);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.renameSession),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l.sessionTitle,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () {
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty) {
                ref.read(aiProvider.notifier).renameSession(sessionId, newTitle);
              }
              Navigator.pop(ctx);
            },
            child: Text(l.save),
          ),
        ],
      ),
    );
  }

  /// 确认删除会话
  void _confirmDeleteSession(String sessionId) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteSession),
        content: Text(l.deleteSessionConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            onPressed: () {
              ref.read(aiProvider.notifier).deleteSession(sessionId);
              Navigator.pop(ctx);
            },
            child: Text(l.delete),
          ),
        ],
      ),
    );
  }

  /// 构建示例提示词卡片，点击后自动填入输入框。
  Widget _buildExamplePrompts(ThemeData theme) {
    final prompts = <_ExamplePrompt>[
      _ExamplePrompt(
        icon: Icons.summarize,
        text: '总结我的笔记',
      ),
      _ExamplePrompt(
        icon: Icons.lightbulb_outline,
        text: '解释这个概念',
      ),
      _ExamplePrompt(
        icon: Icons.edit_note,
        text: '帮我写一篇日记',
      ),
      _ExamplePrompt(
        icon: Icons.analytics_outlined,
        text: '分析网页内容',
      ),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: prompts.map((p) {
        return InkWell(
          onTap: () {
            _controller.text = p.text;
            _controller.selection = TextSelection.fromPosition(
              TextPosition(offset: p.text.length),
            );
            _focusNode.requestFocus();
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.5,
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(p.icon, size: 14, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  p.text,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// 示例提示词数据模型。
class _ExamplePrompt {
  final IconData icon;
  final String text;
  const _ExamplePrompt({required this.icon, required this.text});
}

class _AutocompleteItem {
  final String label;
  final String description;
  final ContextRefType type;
  final String insertText;
  final int cursorOffset;

  _AutocompleteItem({
    required this.label,
    this.description = '',
    required this.type,
    required this.insertText,
    this.cursorOffset = 0,
  });
}
