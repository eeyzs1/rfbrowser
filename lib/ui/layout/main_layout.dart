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
                        Expanded(child: _buildMainContent(theme)),
                        if (_showRightSidebar || _showBacklinks) ...[
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
          _buildViewModeButton(Icons.language, 'Browser', ViewMode.browser),
          _buildViewModeButton(Icons.edit_note, 'Editor', ViewMode.editor),
          _buildViewModeButton(Icons.vertical_split, 'Split', ViewMode.split),
          _buildViewModeButton(Icons.hub, 'Graph', ViewMode.graph),
          _buildViewModeButton(Icons.dashboard, 'Canvas', ViewMode.canvas),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.search, size: 18),
            onPressed: () => setState(() => _showCommandBar = true),
            tooltip: 'Command Bar (Ctrl+K)',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            icon: Icon(
              Icons.link,
              size: 18,
              color: _showBacklinks ? theme.colorScheme.primary : null,
            ),
            onPressed: () => setState(() => _showBacklinks = !_showBacklinks),
            tooltip: 'Toggle Backlinks',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            icon: Icon(
              _showRightSidebar
                  ? Icons.view_sidebar
                  : Icons.view_sidebar_outlined,
              size: 18,
            ),
            onPressed: () =>
                setState(() => _showRightSidebar = !_showRightSidebar),
            tooltip: 'Toggle AI Sidebar',
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

  Widget _buildViewModeButton(IconData icon, String label, ViewMode mode) {
    final theme = Theme.of(context);
    final isActive = _viewMode == mode;
    return Padding(
      padding: const EdgeInsets.only(right: 2),
      child: Material(
        color: isActive
            ? theme.colorScheme.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _viewMode = mode),
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
                    color: isActive
                        ? theme.colorScheme.primary
                        : theme.textTheme.bodySmall?.color,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeftSidebar(ThemeData theme) {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: theme.appBarTheme.backgroundColor,
        border: Border(right: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        children: [
          Container(
            height: 36,
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildTabButton(
                    icon: Icons.description,
                    label: 'Notes',
                    isActive: _leftPanel == LeftPanel.notes,
                    onTap: () => setState(() => _leftPanel = LeftPanel.notes),
                  ),
                ),
                Expanded(
                  child: _buildTabButton(
                    icon: Icons.tab,
                    label: 'Tabs',
                    isActive: _leftPanel == LeftPanel.tabs,
                    onTap: () => setState(() => _leftPanel = LeftPanel.tabs),
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

  Widget _buildTabButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: isActive
          ? theme.colorScheme.primary.withValues(alpha: 0.08)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 12,
                color: isActive ? theme.colorScheme.primary : theme.hintColor,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isActive ? theme.colorScheme.primary : theme.hintColor,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
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
    return Container(
      width: 340,
      decoration: BoxDecoration(
        color: theme.appBarTheme.backgroundColor,
        border: Border(left: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        children: [
          if (_showBacklinks && _showRightSidebar)
            Container(
              height: 36,
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: theme.dividerColor)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTabButton(
                      icon: Icons.link,
                      label: 'Links',
                      isActive: _showBacklinks && !_showRightSidebar,
                      onTap: () => setState(() {
                        _showBacklinks = true;
                        _showRightSidebar = false;
                      }),
                    ),
                  ),
                  Expanded(
                    child: _buildTabButton(
                      icon: Icons.smart_toy,
                      label: 'AI',
                      isActive: _showRightSidebar && !_showBacklinks,
                      onTap: () => setState(() {
                        _showRightSidebar = true;
                        _showBacklinks = false;
                      }),
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
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.dashboard,
              size: 36,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),
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
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: hasVault
                  ? const Color(0xFF73DACA)
                  : const Color(0xFFFF9E64),
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
      ref
          .read(browserProvider.notifier)
          .createTab(url: 'https://www.google.com');
      setState(() => _viewMode = ViewMode.browser);
    } else if (lower.contains('daily note')) {
      ref.read(knowledgeProvider.notifier).createDailyNote(DateTime.now());
      setState(() => _viewMode = ViewMode.editor);
    } else if (lower.contains('graph')) {
      setState(() => _viewMode = ViewMode.graph);
    } else if (lower.contains('settings')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SettingsPage()),
      );
    } else if (lower.contains('theme')) {
      ref.read(settingsProvider.notifier).toggleDarkMode();
    } else if (lower.contains('backlinks')) {
      setState(() => _showBacklinks = !_showBacklinks);
    } else if (lower.contains('research')) {
      ref.read(agentServiceProvider).research(command);
      setState(() {
        _showRightSidebar = true;
        _showBacklinks = false;
      });
    } else {
      ref.read(aiProvider.notifier).sendMessage(command);
      setState(() {
        _showRightSidebar = true;
        _showBacklinks = false;
      });
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
      setState(() => _viewMode = ViewMode.editor);
    }
  }
}
