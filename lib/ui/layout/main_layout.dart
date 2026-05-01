import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/browser_service.dart';
import '../../services/knowledge_service.dart';
import '../../services/ai_service.dart';
import '../../services/settings_service.dart';
import '../../services/agent_service.dart';
import '../widgets/tab_group_sidebar.dart';
import '../widgets/command_bar.dart';
import '../widgets/backlinks_panel.dart';
import '../widgets/note_sidebar.dart';
import '../pages/editor_page.dart';
import '../pages/browser_page.dart';
import '../pages/ai_chat_panel.dart';
import '../pages/graph_page.dart';
import '../pages/settings_page.dart';

enum ViewMode { browser, editor, split, graph, canvas }
enum LeftPanel { tabs, notes }

class MainLayout extends ConsumerStatefulWidget {
  const MainLayout({super.key});

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout> {
  ViewMode _viewMode = ViewMode.split;
  LeftPanel _leftPanel = LeftPanel.notes;
  bool _showCommandBar = false;
  bool _showRightSidebar = true;
  bool _showBacklinks = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: CallbackShortcuts(
        bindings: {
          SingleActivator(LogicalKeyboardKey.keyK, control: true): () {
            setState(() => _showCommandBar = true);
          },
          SingleActivator(LogicalKeyboardKey.keyN, control: true): () {
            _createNewNote();
          },
          SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
            ref.read(knowledgeProvider.notifier).saveActiveNote();
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
                    child: Row(
                      children: [
                        _buildLeftSidebar(theme),
                        Container(width: 1, color: theme.dividerColor),
                        Expanded(child: _buildMainContent(theme)),
                        if (_showRightSidebar || _showBacklinks) ...[
                          Container(width: 1, color: theme.dividerColor),
                          _buildRightPanel(theme),
                        ],
                      ],
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

  Widget _buildMenuBar(ThemeData theme) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.appBarTheme.backgroundColor,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu, size: 16),
            onPressed: () {},
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          const SizedBox(width: 8),
          Text('RFBrowser', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(width: 16),
          _buildViewModeButton(Icons.language, 'Browser', ViewMode.browser),
          _buildViewModeButton(Icons.edit_note, 'Editor', ViewMode.editor),
          _buildViewModeButton(Icons.vertical_split, 'Split', ViewMode.split),
          _buildViewModeButton(Icons.hub, 'Graph', ViewMode.graph),
          _buildViewModeButton(Icons.dashboard, 'Canvas', ViewMode.canvas),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.search, size: 16),
            onPressed: () => setState(() => _showCommandBar = true),
            tooltip: 'Command Bar (Ctrl+K)',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            icon: Icon(Icons.link, size: 16, color: _showBacklinks ? theme.colorScheme.primary : null),
            onPressed: () => setState(() => _showBacklinks = !_showBacklinks),
            tooltip: 'Toggle Backlinks',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            icon: Icon(_showRightSidebar ? Icons.view_sidebar : Icons.view_sidebar_outlined, size: 16),
            onPressed: () => setState(() => _showRightSidebar = !_showRightSidebar),
            tooltip: 'Toggle AI Sidebar',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            icon: const Icon(Icons.settings, size: 16),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())),
            tooltip: 'Settings',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildViewModeButton(IconData icon, String label, ViewMode mode) {
    final theme = Theme.of(context);
    final isActive = _viewMode == mode;
    return TextButton(
      onPressed: () => setState(() => _viewMode = mode),
      style: TextButton.styleFrom(
        foregroundColor: isActive ? theme.colorScheme.primary : theme.textTheme.bodySmall?.color,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildLeftSidebar(ThemeData theme) {
    return SizedBox(
      width: 220,
      child: Column(
        children: [
          Container(
            height: 32,
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => setState(() => _leftPanel = LeftPanel.notes),
                    style: TextButton.styleFrom(
                      foregroundColor: _leftPanel == LeftPanel.notes ? theme.colorScheme.primary : theme.hintColor,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.description, size: 12),
                        const SizedBox(width: 4),
                        Text('Notes', style: TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () => setState(() => _leftPanel = LeftPanel.tabs),
                    style: TextButton.styleFrom(
                      foregroundColor: _leftPanel == LeftPanel.tabs ? theme.colorScheme.primary : theme.hintColor,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.tab, size: 12),
                        const SizedBox(width: 4),
                        Text('Tabs', style: TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _leftPanel == LeftPanel.notes
                ? const NoteSidebar()
                : const TabGroupSidebar(),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(ThemeData theme) {
    switch (_viewMode) {
      case ViewMode.browser:
        return const BrowserView();
      case ViewMode.editor:
        return const EditorView();
      case ViewMode.split:
        return Row(
          children: [
            const Expanded(child: BrowserView()),
            Container(width: 1, color: theme.dividerColor),
            const Expanded(child: EditorView()),
          ],
        );
      case ViewMode.graph:
        return const GraphView();
      case ViewMode.canvas:
        return _buildCanvasPlaceholder(theme);
    }
  }

  Widget _buildRightPanel(ThemeData theme) {
    return SizedBox(
      width: 320,
      child: Column(
        children: [
          if (_showBacklinks && _showRightSidebar)
            Container(
              height: 32,
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: theme.dividerColor)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => setState(() { _showBacklinks = true; _showRightSidebar = false; }),
                      style: TextButton.styleFrom(
                        foregroundColor: _showBacklinks && !_showRightSidebar ? theme.colorScheme.primary : theme.hintColor,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.link, size: 12),
                          const SizedBox(width: 4),
                          Text('Links', style: TextStyle(fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: () => setState(() { _showRightSidebar = true; _showBacklinks = false; }),
                      style: TextButton.styleFrom(
                        foregroundColor: _showRightSidebar && !_showBacklinks ? theme.colorScheme.primary : theme.hintColor,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.smart_toy, size: 12),
                          const SizedBox(width: 4),
                          Text('AI', style: TextStyle(fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _showRightSidebar
                ? const AIChatPanel()
                : const BacklinksPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildCanvasPlaceholder(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.dashboard, size: 64, color: theme.hintColor),
          const SizedBox(height: 16),
          Text('Canvas', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text('Coming in Phase 4', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildStatusBar(ThemeData theme) {
    final browserState = ref.watch(browserProvider);
    final knowledgeState = ref.watch(knowledgeProvider);
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.appBarTheme.backgroundColor,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Text('RFBrowser v0.2.0', style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
          const SizedBox(width: 16),
          Icon(Icons.circle, size: 8, color: Colors.green.shade400),
          const SizedBox(width: 4),
          Text('Ready', style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
          const SizedBox(width: 16),
          Icon(Icons.description, size: 10, color: theme.hintColor),
          const SizedBox(width: 4),
          Text('${knowledgeState.notes.length} notes', style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
          const Spacer(),
          Text(
            '${browserState.tabs.length} tabs',
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
          ),
          const SizedBox(width: 16),
          Icon(Icons.sync, size: 10, color: theme.hintColor),
          const SizedBox(width: 4),
          Text('Git', style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
        ],
      ),
    );
  }

  void _handleCommand(String command) {
    final lower = command.toLowerCase();
    if (lower.contains('new note')) {
      _createNewNote();
    } else if (lower.contains('new tab')) {
      ref.read(browserProvider.notifier).createTab(url: 'https://www.google.com');
      setState(() => _viewMode = ViewMode.browser);
    } else if (lower.contains('daily note')) {
      ref.read(knowledgeProvider.notifier).createDailyNote(DateTime.now());
      setState(() => _viewMode = ViewMode.editor);
    } else if (lower.contains('graph')) {
      setState(() => _viewMode = ViewMode.graph);
    } else if (lower.contains('settings')) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()));
    } else if (lower.contains('theme')) {
      ref.read(settingsProvider.notifier).toggleDarkMode();
    } else if (lower.contains('backlinks')) {
      setState(() => _showBacklinks = !_showBacklinks);
    } else if (lower.contains('research')) {
      ref.read(agentServiceProvider).research(command);
      setState(() { _showRightSidebar = true; _showBacklinks = false; });
    } else {
      ref.read(aiProvider.notifier).sendMessage(command);
      setState(() { _showRightSidebar = true; _showBacklinks = false; });
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
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
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
      setState(() => _viewMode = ViewMode.editor);
    }
  }
}
