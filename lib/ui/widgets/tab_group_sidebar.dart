import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/browser_service.dart';
import '../../data/models/browser_tab.dart';

class TabGroupSidebar extends ConsumerWidget {
  const TabGroupSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final browserState = ref.watch(browserProvider);
    final theme = Theme.of(context);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: Row(
            children: [
              Icon(Icons.tab, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Tab Groups',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add, size: 18),
                onPressed: () => _showNewGroupDialog(context, ref),
                tooltip: 'New Group',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 4),
            children: [
              _buildUngroupedSection(context, ref, browserState),
              ...browserState.groups.map(
                (group) =>
                    _buildGroupSection(context, ref, browserState, group),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: theme.dividerColor)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 20),
                onPressed: () => ref.read(browserProvider.notifier).createTab(),
                tooltip: 'New Tab',
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${browserState.tabs.length} tab${browserState.tabs.length != 1 ? 's' : ''}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUngroupedSection(
    BuildContext context,
    WidgetRef ref,
    BrowserState state,
  ) {
    final theme = Theme.of(context);
    final ungrouped = state.ungroupedTabs;
    if (ungrouped.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            'Ungrouped',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ...ungrouped.map((tab) => _buildTabItem(context, ref, tab)),
      ],
    );
  }

  Widget _buildGroupSection(
    BuildContext context,
    WidgetRef ref,
    BrowserState state,
    TabGroup group,
  ) {
    final theme = Theme.of(context);
    final tabs = state.tabsInGroup(group.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () =>
              ref.read(browserProvider.notifier).toggleGroupExpanded(group.id),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Icon(
                  group.isExpanded ? Icons.expand_more : Icons.chevron_right,
                  size: 16,
                  color: Color(group.color),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Color(group.color),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    group.name,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text('${tabs.length}', style: theme.textTheme.bodySmall),
                IconButton(
                  icon: const Icon(Icons.close, size: 14),
                  onPressed: () =>
                      ref.read(browserProvider.notifier).deleteGroup(group.id),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (group.isExpanded)
          ...tabs.map((tab) => _buildTabItem(context, ref, tab)),
      ],
    );
  }

  Widget _buildTabItem(BuildContext context, WidgetRef ref, BrowserTab tab) {
    final theme = Theme.of(context);
    final isActive = tab.isActive;

    return InkWell(
      onTap: () => ref.read(browserProvider.notifier).setActiveTab(tab.id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        color: isActive
            ? theme.colorScheme.primary.withValues(alpha: 0.1)
            : null,
        child: Row(
          children: [
            if (tab.isLoading)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.primary,
                ),
              )
            else
              const Icon(Icons.language, size: 14),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                tab.title,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isActive ? theme.colorScheme.primary : null,
                  fontWeight: isActive ? FontWeight.w600 : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 12),
              onPressed: () =>
                  ref.read(browserProvider.notifier).closeTab(tab.id),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            ),
          ],
        ),
      ),
    );
  }

  void _showNewGroupDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Tab Group'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Group name'),
          onSubmitted: (_) {
            if (controller.text.isNotEmpty) {
              ref.read(browserProvider.notifier).createGroup(controller.text);
              Navigator.pop(ctx);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                ref.read(browserProvider.notifier).createGroup(controller.text);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
