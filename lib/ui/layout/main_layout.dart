import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../services/browser_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/knowledge_service.dart';
import '../../services/ai_service.dart';
import '../../services/settings_service.dart';
import '../../services/shortcut_service.dart';
import '../../services/agent_service.dart';
import '../../services/quick_move_service.dart';
import '../../data/stores/vault_store.dart';
import '../widgets/tab_group_sidebar.dart';
import '../widgets/command_bar.dart';
import '../widgets/backlinks_panel.dart';
import '../widgets/note_sidebar.dart';
import '../widgets/split_pane.dart';
import '../widgets/create_note_dialog.dart';
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

    final shortcutService = ref.read(shortcutServiceProvider);

    return Scaffold(
      body: CallbackShortcuts(
        bindings: _buildShortcutBindings(shortcutService),
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
    final connectivityState = ref.watch(connectivityProvider);
    final hasVault = vaultState.currentVault != null;
    final isOffline = !connectivityState.isOnline;
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
              color: isOffline
                  ? const Color(0xFFEF4444)
                  : hasVault
                      ? const Color(0xFF2DD4BF)
                      : const Color(0xFFFBBF24),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isOffline ? 'Offline' : (hasVault ? 'Ready' : 'No Vault'),
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: isOffline ? const Color(0xFFEF4444) : null,
            ),
          ),
          if (isOffline && connectivityState.syncQueue.isNotEmpty) ...[
            const SizedBox(width: 12),
            Icon(Icons.cloud_upload, size: 10, color: theme.hintColor),
            const SizedBox(width: 4),
            Text(
              '${connectivityState.syncQueue.length} pending',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
            ),
          ],
          if (hasVault && !isOffline) ...[
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
    if (command.startsWith('/')) {
      _executeQuickMove(command);
      return;
    }

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
      ref.read(agentProvider.notifier).research(command);
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
    final title = await showCreateNoteDialog(context);
    if (title != null && title.isNotEmpty) {
      await ref.read(knowledgeProvider.notifier).createNote(title: title);
      if (!_isActive(ViewType.editor)) {
        _togglePanel(ViewType.editor);
      }
    }
  }

  void _executeQuickMove(String command) {
    final parts = command.substring(1).split(' ');
    final cmdName = parts[0];
    final input = parts.skip(1).join(' ');

    final quickMoveState = ref.read(quickMoveProvider);
    final match = quickMoveState.matching(cmdName).firstOrNull;

    if (match == null) return;

    ref.read(quickMoveProvider.notifier).recordUsage(match.id);

    final context = ref.read(quickMoveContextProvider);
    final args = <String, String>{
      'input': input,
    };
    if (context.pageContent != null) {
      final truncated = context.pageContent!.length > 8000
          ? context.pageContent!.substring(0, 8000)
          : context.pageContent!;
      args['pageContent'] = truncated;
    }
    if (context.selectedText != null) {
      final truncated = context.selectedText!.length > 4000
          ? context.selectedText!.substring(0, 4000)
          : context.selectedText!;
      args['selectedText'] = truncated;
    }
    if (context.currentUrl != null) {
      args['pageUrl'] = context.currentUrl!;
    }
    if (context.noteContent != null) {
      final truncated = context.noteContent!.length > 8000
          ? context.noteContent!.substring(0, 8000)
          : context.noteContent!;
      args['noteContent'] = truncated;
    }

    final resolvedPrompt = match.resolvePrompt(args);

    ref.read(aiProvider.notifier).sendMessage(resolvedPrompt);
    if (!_isActive(ViewType.ai)) {
      _togglePanel(ViewType.ai);
    }
  }

  Map<ShortcutActivator, VoidCallback> _buildShortcutBindings(
      ShortcutService shortcutService) {
    final bindings = <ShortcutActivator, VoidCallback>{};
    for (final entry in shortcutService.allBindings.entries) {
      final activator = _parseShortcut(entry.value);
      if (activator == null) continue;
      final handler = _handlerForAction(entry.key);
      if (handler != null) {
        bindings[activator] = handler;
      }
    }
    bindings[const SingleActivator(LogicalKeyboardKey.escape)] = () {
      if (_showCommandBar) setState(() => _showCommandBar = false);
    };
    return bindings;
  }

  VoidCallback? _handlerForAction(String action) {
    switch (action) {
      case 'new_note':
        return _createNewNote;
      case 'save':
        return () => ref.read(knowledgeProvider.notifier).saveActiveNote();
      case 'search':
      case 'find':
        return () => setState(() => _showCommandBar = true);
      case 'toggle_editor':
        return () => _togglePanel(ViewType.editor);
      case 'toggle_browser':
        return () => _togglePanel(ViewType.browser);
      case 'toggle_graph':
        return () => _togglePanel(ViewType.graph);
      case 'daily_note':
        return () {
          ref
              .read(knowledgeProvider.notifier)
              .createDailyNote(DateTime.now());
          if (!_isActive(ViewType.editor)) {
            _togglePanel(ViewType.editor);
          }
        };
      case 'toggle_preview':
        return () => setState(() => _isPreview = !_isPreview);
      case 'settings':
        return () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsPage()),
          );
        };
      default:
        return null;
    }
  }

  SingleActivator? _parseShortcut(String text) {
    final parts = text.split('+');
    bool control = false;
    bool shift = false;
    bool alt = false;
    bool meta = false;
    LogicalKeyboardKey? key;

    for (final part in parts) {
      final trimmed = part.trim();
      switch (trimmed.toLowerCase()) {
        case 'ctrl':
        case 'control':
          control = true;
          break;
        case 'shift':
          shift = true;
          break;
        case 'alt':
          alt = true;
          break;
        case 'meta':
        case 'cmd':
          meta = true;
          break;
        default:
          key = _keyFromName(trimmed);
      }
    }

    if (key == null) return null;
    return SingleActivator(key, control: control, shift: shift, alt: alt, meta: meta);
  }

  LogicalKeyboardKey? _keyFromName(String name) {
    switch (name.toUpperCase()) {
      case 'A': return LogicalKeyboardKey.keyA;
      case 'B': return LogicalKeyboardKey.keyB;
      case 'C': return LogicalKeyboardKey.keyC;
      case 'D': return LogicalKeyboardKey.keyD;
      case 'E': return LogicalKeyboardKey.keyE;
      case 'F': return LogicalKeyboardKey.keyF;
      case 'G': return LogicalKeyboardKey.keyG;
      case 'H': return LogicalKeyboardKey.keyH;
      case 'I': return LogicalKeyboardKey.keyI;
      case 'J': return LogicalKeyboardKey.keyJ;
      case 'K': return LogicalKeyboardKey.keyK;
      case 'L': return LogicalKeyboardKey.keyL;
      case 'M': return LogicalKeyboardKey.keyM;
      case 'N': return LogicalKeyboardKey.keyN;
      case 'O': return LogicalKeyboardKey.keyO;
      case 'P': return LogicalKeyboardKey.keyP;
      case 'Q': return LogicalKeyboardKey.keyQ;
      case 'R': return LogicalKeyboardKey.keyR;
      case 'S': return LogicalKeyboardKey.keyS;
      case 'T': return LogicalKeyboardKey.keyT;
      case 'U': return LogicalKeyboardKey.keyU;
      case 'V': return LogicalKeyboardKey.keyV;
      case 'W': return LogicalKeyboardKey.keyW;
      case 'X': return LogicalKeyboardKey.keyX;
      case 'Y': return LogicalKeyboardKey.keyY;
      case 'Z': return LogicalKeyboardKey.keyZ;
      case '0': return LogicalKeyboardKey.digit0;
      case '1': return LogicalKeyboardKey.digit1;
      case '2': return LogicalKeyboardKey.digit2;
      case '3': return LogicalKeyboardKey.digit3;
      case '4': return LogicalKeyboardKey.digit4;
      case '5': return LogicalKeyboardKey.digit5;
      case '6': return LogicalKeyboardKey.digit6;
      case '7': return LogicalKeyboardKey.digit7;
      case '8': return LogicalKeyboardKey.digit8;
      case '9': return LogicalKeyboardKey.digit9;
      case 'ESC':
      case 'ESCAPE':
        return LogicalKeyboardKey.escape;
      case 'SPACE':
        return LogicalKeyboardKey.space;
      case 'ENTER':
      case 'RETURN':
        return LogicalKeyboardKey.enter;
      case 'TAB':
        return LogicalKeyboardKey.tab;
      case 'BACKSPACE':
        return LogicalKeyboardKey.backspace;
      case 'DELETE':
        return LogicalKeyboardKey.delete;
      case 'UP':
        return LogicalKeyboardKey.arrowUp;
      case 'DOWN':
        return LogicalKeyboardKey.arrowDown;
      case 'LEFT':
        return LogicalKeyboardKey.arrowLeft;
      case 'RIGHT':
        return LogicalKeyboardKey.arrowRight;
      case 'F1': return LogicalKeyboardKey.f1;
      case 'F2': return LogicalKeyboardKey.f2;
      case 'F3': return LogicalKeyboardKey.f3;
      case 'F4': return LogicalKeyboardKey.f4;
      case 'F5': return LogicalKeyboardKey.f5;
      case 'F6': return LogicalKeyboardKey.f6;
      case 'F7': return LogicalKeyboardKey.f7;
      case 'F8': return LogicalKeyboardKey.f8;
      case 'F9': return LogicalKeyboardKey.f9;
      case 'F10': return LogicalKeyboardKey.f10;
      case 'F11': return LogicalKeyboardKey.f11;
      case 'F12': return LogicalKeyboardKey.f12;
      default: return null;
    }
  }
}
