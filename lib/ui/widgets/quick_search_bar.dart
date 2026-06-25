import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../services/knowledge_service.dart';
import '../../data/models/note.dart';
import '../theme/design_tokens.dart';

class QuickSearchBar extends ConsumerStatefulWidget {
  final ValueChanged<Note>? onNoteSelected;

  const QuickSearchBar({super.key, this.onNoteSelected});

  @override
  ConsumerState<QuickSearchBar> createState() => _QuickSearchBarState();
}

class _QuickSearchBarState extends ConsumerState<QuickSearchBar> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounceTimer;
  bool _isLoading = false;
  List<_QuickSearchItem> _items = const [];

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// 输入变化时触发防抖搜索（200ms），调用 SearchService.hybridSearch
  void _onChanged(String value) {
    _debounceTimer?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _isLoading = false;
        _items = const [];
      });
      return;
    }
    setState(() => _isLoading = true);
    _debounceTimer = Timer(const Duration(milliseconds: 200), () {
      _performSearch(value.trim());
    });
  }

  Future<void> _performSearch(String query) async {
    final searchNotifier = ref.read(searchServiceProvider.notifier);
    final results = await searchNotifier.hybridSearch(query);
    if (!mounted) return;

    final knowledgeState = ref.read(knowledgeProvider);
    final notes = knowledgeState.notes;
    final items = <_QuickSearchItem>[];

    for (final r in results.take(8)) {
      final kind = r['kind'] as String?;
      if (kind == 'memory') {
        // 记忆片段结果：直接使用返回的 title / preview
        final title = (r['title'] as String?) ?? '';
        final preview = (r['preview'] as String?) ?? '';
        items.add(
          _QuickSearchItem(
            title: title.isEmpty ? '(记忆片段)' : title,
            preview: preview,
            icon: Icons.psychology_outlined,
            isMemory: true,
            note: null,
          ),
        );
      } else {
        // 笔记结果：通过 noteId 查找对应的 Note 对象
        final noteId = (r['noteId'] as String?) ?? '';
        final note = notes.where((n) => n.id == noteId).firstOrNull;
        if (note == null) continue;
        items.add(
          _QuickSearchItem(
            title: note.title,
            preview: note.content.length > 80
                ? '${note.content.substring(0, 80)}...'
                : note.content,
            icon: Icons.description_outlined,
            isMemory: false,
            note: note,
          ),
        );
      }
    }

    setState(() {
      _isLoading = false;
      _items = items;
    });
  }

  void _selectItem(_QuickSearchItem item) {
    if (!item.isMemory && item.note != null) {
      widget.onNoteSelected?.call(item.note!);
    }
    _searchController.clear();
    setState(() {
      _items = const [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    final showDropdown = _items.isNotEmpty || _isLoading;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignSpacing.md,
        vertical: DesignSpacing.sm,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 32,
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: l.searchNotes,
                hintStyle: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
                prefixIcon: const Icon(Icons.search, size: 16),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 4,
                  horizontal: DesignSpacing.sm,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DesignRadius.sm),
                  borderSide: BorderSide(color: theme.dividerColor),
                ),
                filled: true,
                fillColor: theme.colorScheme.surface,
              ),
              style: theme.textTheme.bodyMedium,
              onChanged: _onChanged,
            ),
          ),
          if (showDropdown) ...[
            const SizedBox(height: DesignSpacing.xs),
            Container(
              constraints: const BoxConstraints(maxHeight: 240),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(DesignRadius.sm),
                border: Border.all(color: theme.dividerColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(DesignRadius.sm),
                clipBehavior: Clip.antiAlias,
                child: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: _items.length,
                        separatorBuilder: (context, idx) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              item.icon,
                              size: 16,
                              color: item.isMemory
                                  ? theme.colorScheme.tertiary
                                  : theme.hintColor,
                            ),
                            title: Text(
                              item.title,
                              style: theme.textTheme.bodySmall,
                            ),
                            subtitle: item.preview.isNotEmpty
                                ? Text(
                                    item.preview,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.hintColor,
                                    ),
                                  )
                                : null,
                            onTap: () => _selectItem(item),
                          );
                        },
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 搜索结果展示项，统一封装笔记和记忆片段
class _QuickSearchItem {
  final String title;
  final String preview;
  final IconData icon;
  final bool isMemory;
  final Note? note;

  const _QuickSearchItem({
    required this.title,
    required this.preview,
    required this.icon,
    required this.isMemory,
    this.note,
  });
}
