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

enum LayoutPreset { browser, editor, split, graph, canvas }

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
    _rootNode = _splitPreset;
  }

  SplitNode get _splitPreset => SplitNode.split(
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

  SplitNode _presetFor(LayoutPreset preset) {
    final mainViewType = switch (preset) {
      LayoutPreset.browser => ViewType.browser,
      LayoutPreset.editor => ViewType.editor,
      LayoutPreset.graph => ViewType.graph,
      LayoutPreset.canvas => ViewType.canvas,
      LayoutPreset.split => ViewType.browser,
    };

    if (preset == LayoutPreset.split) {
      return _splitPreset;
    }

    return SplitNode.split(
      id: 'root',
      direction: SplitDirection.horizontal,
      children: [
        SplitNode.leaf(id: 'notes', viewType: ViewType.notes, flex: 2),
        SplitNode.leaf(id: 'main', viewType: mainViewType, flex: 5),
        SplitNode.leaf(id: 'ai', viewType: ViewType.ai, flex: 2),
      ],
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
            setState(() => _rootNode = _presetFor(LayoutPreset.editor));
          },
          const SingleActivator(LogicalKeyboardKey.keyB, control: true): () {
            setState(() => _rootNode = _presetFor(LayoutPreset.browser));
          },
          const SingleActivator(
            LogicalKeyboardKey.keyG,
            control: true,
            shift: true,
          ): () {
            setState(() => _rootNode = _presetFor(LayoutPreset.graph));
          },
          const SingleActivator(LogicalKeyboardKey.keyD, control: true): () {
            ref
                .read(knowledgeProvider.notifier)
                .createDailyNote(DateTime.now());
            setState(() => _rootNode = _presetFor(LayoutPreset.editor));
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
          _buildPresetButton(Icons.language, 'Browser', LayoutPreset.browser),
          _buildPresetButton(Icons.edit_note, 'Editor', LayoutPreset.editor),
          _buildPresetButton(Icons.vertical_split, 'Split', LayoutPreset.split),
          _buildPresetButton(Icons.hub, 'Graph', LayoutPreset.graph),
          _buildPresetButton(Icons.dashboard, 'Canvas', LayoutPreset.canvas),
          const Spacer(),
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

  Widget _buildPresetButton(IconData icon, String label, LayoutPreset preset) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _rootNode = _presetFor(preset)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: theme.iconTheme.color),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
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
      setState(() => _rootNode = _presetFor(LayoutPreset.browser));
    } else if (lower.contains('daily note')) {
      ref.read(knowledgeProvider.notifier).createDailyNote(DateTime.now());
      setState(() => _rootNode = _presetFor(LayoutPreset.editor));
    } else if (lower.contains('graph')) {
      setState(() => _rootNode = _presetFor(LayoutPreset.graph));
    } else if (lower.contains('settings')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SettingsPage()),
      );
    } else if (lower.contains('theme')) {
      ref.read(settingsProvider.notifier).toggleDarkMode();
    } else if (lower.contains('research')) {
      ref.read(agentServiceProvider).research(command);
      setState(() => _rootNode = _splitPreset);
    } else {
      ref.read(aiProvider.notifier).sendMessage(command);
      setState(() => _rootNode = _splitPreset);
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
      setState(() => _rootNode = _presetFor(LayoutPreset.editor));
    }
  }
}
