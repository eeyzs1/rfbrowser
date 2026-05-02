import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  late SplitNode _rootNode;

  @override
  void initState() {
    super.initState();
    _rootNode = _defaultLayout();
  }

  SplitNode _defaultLayout() => SplitNode.split(
    id: 'root',
    direction: SplitDirection.horizontal,
    children: [
      SplitNode.leaf(id: 'notes', viewType: ViewType.notes, flex: 2),
      SplitNode.split(
        id: 'center',
        direction: SplitDirection.horizontal,
        children: [
          SplitNode.leaf(id: 'browser', viewType: ViewType.browser, flex: 1),
          SplitNode.leaf(id: 'editor', viewType: ViewType.editor, flex: 1),
        ],
        flex: 5,
      ),
      SplitNode.leaf(id: 'ai', viewType: ViewType.ai, flex: 2),
    ],
  );

  bool _hasViewType(SplitNode node, ViewType vt) {
    if (node.isLeaf) return node.viewType == vt;
    return node.children.any((c) => _hasViewType(c, vt));
  }

  SplitNode _removeViewType(SplitNode node, ViewType vt) {
    if (node.isLeaf) return node;
    final newChildren = node.children
        .where((c) => !_isOnlyLeafWithViewType(c, vt))
        .map((c) => _removeViewType(c, vt))
        .where((c) => c.isLeaf || c.children.isNotEmpty)
        .toList();
    if (newChildren.isEmpty) {
      return SplitNode.leaf(
        id: node.id,
        viewType: ViewType.editor,
        flex: node.flex,
      );
    }
    if (newChildren.length == 1) {
      final only = newChildren.first;
      return SplitNode.leaf(
        id: only.id,
        viewType: only.viewType,
        flex: node.flex,
      );
    }
    return SplitNode.split(
      id: node.id,
      direction: node.direction,
      children: newChildren,
      flex: node.flex,
    );
  }

  bool _isOnlyLeafWithViewType(SplitNode node, ViewType vt) {
    if (node.isLeaf) return node.viewType == vt;
    return node.children.every((c) => _isOnlyLeafWithViewType(c, vt));
  }

  SplitNode _addViewType(SplitNode node, ViewType vt) {
    if (!node.isLeaf && node.id == 'root') {
      final newLeaf = SplitNode.leaf(
        id: vt.name,
        viewType: vt,
        flex: vt == ViewType.ai ? 2 : (vt == ViewType.notes ? 2 : 5),
      );
      final insertIndex = vt == ViewType.notes ? 0 : node.children.length;
      final newChildren = List<SplitNode>.from(node.children);
      newChildren.insert(insertIndex, newLeaf);
      return SplitNode.split(
        id: node.id,
        direction: node.direction,
        children: newChildren,
        flex: node.flex,
      );
    }
    return node;
  }

  void _togglePanel(ViewType vt) {
    setState(() {
      if (_hasViewType(_rootNode, vt)) {
        _rootNode = _removeViewType(_rootNode, vt);
      } else {
        _rootNode = _addViewType(_rootNode, vt);
      }
    });
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
            if (!_hasViewType(_rootNode, ViewType.editor)) {
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
                    child: SplitPane(
                      node: _rootNode,
                      viewBuilder: _buildView,
                      onChanged: (node) => setState(() => _rootNode = node),
                    ),
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
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.appBarTheme.backgroundColor,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Icon(Icons.explore, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            'RFBrowser',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 20),
          _buildPanelButton(Icons.description, 'Notes', ViewType.notes),
          _buildPanelButton(Icons.language, 'Browser', ViewType.browser),
          _buildPanelButton(Icons.edit_note, 'Editor', ViewType.editor),
          _buildPanelButton(Icons.dashboard, 'Canvas', ViewType.canvas),
          _buildPanelButton(Icons.smart_toy, 'AI', ViewType.ai),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.folder_open, size: 18),
            onPressed: () => ref.read(vaultProvider.notifier).closeVault(),
            tooltip: 'Switch Vault',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            icon: const Icon(Icons.search, size: 18),
            onPressed: () => setState(() => _showCommandBar = true),
            tooltip: 'Command Bar (Ctrl+K)',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            icon: const Icon(Icons.settings, size: 18),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
            tooltip: 'Settings',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildPanelButton(IconData icon, String label, ViewType vt) {
    final theme = Theme.of(context);
    final isActive = _hasViewType(_rootNode, vt);
    return Padding(
      padding: const EdgeInsets.only(right: 2),
      child: Material(
        color: isActive
            ? theme.colorScheme.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _togglePanel(vt),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: isActive
                      ? theme.colorScheme.primary
                      : theme.iconTheme.color,
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    color: isActive
                        ? theme.colorScheme.primary
                        : theme.iconTheme.color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBar(ThemeData theme) {
    final browserState = ref.watch(browserProvider);
    final knowledgeState = ref.watch(knowledgeProvider);
    final vaultState = ref.watch(vaultProvider);
    final hasVault = vaultState.currentVault != null;
    return Container(
      height: 26,
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
      if (!_hasViewType(_rootNode, ViewType.browser)) {
        _togglePanel(ViewType.browser);
      }
    } else if (lower.contains('daily note')) {
      ref.read(knowledgeProvider.notifier).createDailyNote(DateTime.now());
      if (!_hasViewType(_rootNode, ViewType.editor)) {
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
      if (!_hasViewType(_rootNode, ViewType.ai)) {
        _togglePanel(ViewType.ai);
      }
    } else {
      ref.read(aiProvider.notifier).sendMessage(command);
      if (!_hasViewType(_rootNode, ViewType.ai)) {
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
      if (!_hasViewType(_rootNode, ViewType.editor)) {
        _togglePanel(ViewType.editor);
      }
    }
  }
}
