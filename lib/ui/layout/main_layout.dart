import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../services/browser_service.dart';
import '../../services/knowledge_service.dart';
import '../../services/ai_service.dart';
import '../../services/settings_service.dart';
import '../../services/agent_service.dart';
import '../../data/stores/vault_store.dart';
import '../widgets/tab_group_sidebar.dart';
import '../widgets/command_bar.dart';
import '../widgets/backlinks_panel.dart';
import '../widgets/note_sidebar.dart';
import '../widgets/split_pane.dart';
import '../pages/editor_page.dart';
import '../pages/browser_page.dart';
import '../pages/ai_chat_panel.dart';
import '../pages/graph_page.dart';
import '../pages/canvas_page.dart';
import '../pages/settings_page.dart';

class MainLayout extends ConsumerStatefulWidget {
  const MainLayout({super.key});

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout> {
  bool _showCommandBar = false;
  bool _isPreview = false;
  Set<ViewType> _activePanels = {
    ViewType.notes,
    ViewType.browser,
    ViewType.editor,
    ViewType.ai,
  };

  static const Map<ViewType, double> _panelFlex = {
    ViewType.notes: 2,
    ViewType.browser: 3,
    ViewType.editor: 3,
    ViewType.canvas: 3,
    ViewType.ai: 2,
    ViewType.graph: 3,
    ViewType.backlinks: 2,
    ViewType.tabs: 2,
  };

  static const List<ViewType> _panelOrder = [
    ViewType.notes,
    ViewType.browser,
    ViewType.editor,
    ViewType.canvas,
    ViewType.ai,
  ];

  bool _isActive(ViewType vt) => _activePanels.contains(vt);

  void _togglePanel(ViewType vt) {
    setState(() {
      final next = Set<ViewType>.from(_activePanels);
      if (next.contains(vt)) {
        next.remove(vt);
      } else {
        next.add(vt);
      }
      _activePanels = next;
    });
  }

  Set<ViewType> _collectViewTypes(SplitNode node) {
    final result = <ViewType>{};
    void walk(SplitNode n) {
      if (n.isLeaf && n.viewType != null) {
        result.add(n.viewType!);
      }
      for (final c in n.children) {
        walk(c);
      }
    }

    walk(node);
    return result;
  }

  void _syncFromTree(SplitNode node) {
    final types = _collectViewTypes(node);
    if (types.isEmpty) {
      setState(() => _activePanels = {});
      return;
    }
    if (!types.containsAll(_activePanels) ||
        _activePanels.difference(types).isNotEmpty) {
      setState(() => _activePanels = types);
    }
  }

  bool get _hasActivePanels => _activePanels.isNotEmpty;

  SplitNode _buildTree() {
    final ordered = _panelOrder.where(_isActive).toList();
    if (ordered.isEmpty) {
      return SplitNode.leaf(id: 'empty', viewType: ViewType.editor);
    }
    if (ordered.length == 1) {
      return SplitNode.leaf(
        id: ordered.first.name,
        viewType: ordered.first,
        flex: _panelFlex[ordered.first] ?? 3,
      );
    }
    return SplitNode.split(
      id: 'root',
      direction: SplitDirection.horizontal,
      children: ordered
          .map(
            (vt) => SplitNode.leaf(
              id: vt.name,
              viewType: vt,
              flex: _panelFlex[vt] ?? 3,
            ),
          )
          .toList(),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    final l = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.dashboard_customize_outlined,
            size: 64,
            color: theme.hintColor.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            l?.noResults ?? 'No panels open',
            style: theme.textTheme.bodyLarge?.copyWith(color: theme.hintColor),
          ),
          const SizedBox(height: 8),
          Text(
            'Use the toolbar above to open panels',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.hintColor.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyK, control: true): () {
            setState(() => _showCommandBar = true);
          },
          const SingleActivator(LogicalKeyboardKey.keyN, control: true): () {
            _createNewNote();
          },
          const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
            ref.read(knowledgeProvider.notifier).saveActiveNote();
          },
          const SingleActivator(LogicalKeyboardKey.keyE, control: true): () {
            _togglePanel(ViewType.editor);
          },
          const SingleActivator(LogicalKeyboardKey.keyB, control: true): () {
            _togglePanel(ViewType.browser);
          },
          const SingleActivator(
            LogicalKeyboardKey.keyG,
            control: true,
            shift: true,
          ): () {
            _togglePanel(ViewType.graph);
          },
          const SingleActivator(LogicalKeyboardKey.keyD, control: true): () {
            ref
                .read(knowledgeProvider.notifier)
                .createDailyNote(DateTime.now());
            if (!_isActive(ViewType.editor)) {
              _togglePanel(ViewType.editor);
            }
          },
          const SingleActivator(LogicalKeyboardKey.keyP, control: true): () {
            setState(() => _isPreview = !_isPreview);
          },
          const SingleActivator(LogicalKeyboardKey.keyW, control: true): () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            );
          },
          const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
            setState(() => _showCommandBar = true);
          },
          const SingleActivator(LogicalKeyboardKey.escape): () {
            if (_showCommandBar) setState(() => _showCommandBar = false);
          },
        },
        child: Focus(
          autofocus: true,
          child: Stack(
            children: [
              Column(
                children: [
                  _buildMenuBar(theme),
                  Expanded(
                    child: _hasActivePanels
                        ? SplitPane(
                            key: ValueKey(_activePanels.hashCode),
                            node: _buildTree(),
                            viewBuilder: _buildView,
                            onChanged: (node) => _syncFromTree(node),
                            onClose: () => setState(() => _activePanels = {}),
                          )
                        : _buildEmptyState(theme),
                  ),
                  _buildStatusBar(theme),
                ],
              ),
              if (_showCommandBar)
                GestureDetector(
                  onTap: () => setState(() => _showCommandBar = false),
                  child: Container(
                    color: Colors.black54,
                    child: CommandBar(
                      onCommand: _handleCommand,
                      onClose: () => setState(() => _showCommandBar = false),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildView(BuildContext context, ViewType viewType) {
    return switch (viewType) {
      ViewType.browser => const BrowserView(),
      ViewType.editor => const EditorView(),
      ViewType.graph => const GraphView(),
      ViewType.ai => const AIChatPanel(),
      ViewType.backlinks => const BacklinksPanel(),
      ViewType.notes => const NoteSidebar(),
      ViewType.tabs => const TabGroupSidebar(),
      ViewType.canvas => const CanvasView(),
    };
  }

  Widget _buildMenuBar(ThemeData theme) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: theme.appBarTheme.backgroundColor,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Icon(Icons.explore, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            'RFBrowser',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 12),
          ..._panelOrder.map(
            (vt) =>
                _buildPanelButton(_viewTypeIcon(vt), _viewTypeLabel(vt), vt),
          ),
          const Spacer(),
          _buildActionButton(
            Icons.folder_open,
            'Switch Vault',
            () => ref.read(vaultProvider.notifier).closeVault(),
          ),
          _buildActionButton(
            Icons.search,
            'Search',
            () => setState(() => _showCommandBar = true),
          ),
          _buildActionButton(
            Icons.settings,
            'Settings',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanelButton(IconData icon, String label, ViewType vt) {
    final theme = Theme.of(context);
    final active = _isActive(vt);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Material(
        color: active
            ? theme.colorScheme.primary.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => _togglePanel(vt),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: active
                ? BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  )
                : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: active
                      ? theme.colorScheme.primary
                      : theme.iconTheme.color?.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    color: active
                        ? theme.colorScheme.primary
                        : theme.iconTheme.color?.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String tooltip,
    VoidCallback onPressed,
  ) {
    final theme = Theme.of(context);
    return IconButton(
      icon: Icon(icon, size: 16, color: theme.iconTheme.color),
      onPressed: onPressed,
      tooltip: tooltip,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }

  String _viewTypeLabel(ViewType vt) => switch (vt) {
    ViewType.browser => 'Browser',
    ViewType.editor => 'Editor',
    ViewType.graph => 'Graph',
    ViewType.ai => 'AI',
    ViewType.backlinks => 'Links',
    ViewType.notes => 'Notes',
    ViewType.tabs => 'Tabs',
    ViewType.canvas => 'Canvas',
  };

  IconData _viewTypeIcon(ViewType vt) => switch (vt) {
    ViewType.browser => Icons.language,
    ViewType.editor => Icons.edit_note,
    ViewType.graph => Icons.hub,
    ViewType.ai => Icons.smart_toy,
    ViewType.backlinks => Icons.link,
    ViewType.notes => Icons.description,
    ViewType.tabs => Icons.tab,
    ViewType.canvas => Icons.dashboard,
  };

  Widget _buildStatusBar(ThemeData theme) {
    final browserState = ref.watch(browserProvider);
    final knowledgeState = ref.watch(knowledgeProvider);
    final vaultState = ref.watch(vaultProvider);
    final hasVault = vaultState.currentVault != null;
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.appBarTheme.backgroundColor,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Text(
            'RFBrowser v0.2.0',
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
          ),
          const SizedBox(width: 12),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: hasVault
                  ? const Color(0xFF2DD4BF)
                  : const Color(0xFFFBBF24),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            hasVault ? 'Ready' : 'No Vault',
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
          ),
          if (hasVault) ...[
            const SizedBox(width: 12),
            Icon(Icons.description, size: 10, color: theme.hintColor),
            const SizedBox(width: 4),
            Text(
              '${knowledgeState.notes.length} notes',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
            ),
          ],
          const Spacer(),
          Text(
            '${browserState.tabs.length} tabs',
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
          ),
          if (hasVault) ...[
            const SizedBox(width: 12),
            Icon(Icons.sync, size: 10, color: theme.hintColor),
            const SizedBox(width: 4),
            Text(
              'Git',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  void _handleCommand(String command) {
    final lower = command.toLowerCase();
    if (lower.contains('new note')) {
      _createNewNote();
    } else if (lower.contains('new tab')) {
      ref.read(browserProvider.notifier).createTab(url: 'https://www.bing.com');
      if (!_isActive(ViewType.browser)) {
        _togglePanel(ViewType.browser);
      }
    } else if (lower.contains('daily note')) {
      ref.read(knowledgeProvider.notifier).createDailyNote(DateTime.now());
      if (!_isActive(ViewType.editor)) {
        _togglePanel(ViewType.editor);
      }
    } else if (lower.contains('graph')) {
      _togglePanel(ViewType.graph);
    } else if (lower.contains('settings')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SettingsPage()),
      );
    } else if (lower.contains('theme')) {
      ref.read(settingsProvider.notifier).toggleDarkMode();
    } else if (lower.contains('research')) {
      ref.read(agentServiceProvider).research(command);
      if (!_isActive(ViewType.ai)) {
        _togglePanel(ViewType.ai);
      }
    } else {
      ref.read(aiProvider.notifier).sendMessage(command);
      if (!_isActive(ViewType.ai)) {
        _togglePanel(ViewType.ai);
      }
    }
  }

  void _createNewNote() async {
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('New Note'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Note title'),
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
    if (title != null && title.isNotEmpty) {
      await ref.read(knowledgeProvider.notifier).createNote(title: title);
      if (!_isActive(ViewType.editor)) {
        _togglePanel(ViewType.editor);
      }
    }
  }
}
