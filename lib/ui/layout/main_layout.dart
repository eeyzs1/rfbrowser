import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../services/browser_service.dart';
import '../../services/knowledge_service.dart';
import '../../services/ai_service.dart';
import '../../services/settings_service.dart';
import '../../services/shortcut_service.dart';
import '../../services/agent_service.dart';
import '../../services/quick_move_service.dart';
import '../../data/stores/vault_store.dart';
import '../../core/ai/request_context.dart';
import '../widgets/command_bar.dart';
import '../widgets/create_note_dialog.dart';
import '../widgets/empty_vault_guide.dart';
import '../widgets/status_bar.dart';
import '../widgets/speed_dial_fab.dart';
import '../scenes/capture/capture_scene.dart';
import '../scenes/think/think_scene.dart';
import '../scenes/connect/connect_scene.dart';
import '../pages/settings_page.dart';
import '../pages/memory_browser_page.dart';
import 'scene_scaffold.dart';
import 'keyboard_util.dart';

class MainLayout extends ConsumerStatefulWidget {
  const MainLayout({super.key});
  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout> {
  bool _showCommandBar = false;
  SceneType _currentScene = SceneType.capture;
  bool _leftPanelExpanded = true;
  bool _rightPanelExpanded = true;
  ConnectViewMode _connectViewMode = ConnectViewMode.canvas;

  void _switchScene(SceneType scene) {
    // 守卫：避免 scene 未变时触发 setState + updateScene。
    // 之前 _SceneButton.onTap = active ? null : widget.onTap 阻止了
    // 点击已激活按钮，但修复 AXTree 不一致后 onTap 始终有效，需要此守卫
    // 避免相同 scene 的重复 setState 和 Riverpod 通知。
    if (_currentScene == scene) return;
    setState(() => _currentScene = scene);
    // Push the new scene into the ambient AI context so subsequent
    // AI requests know what the user is currently doing.
    ref
        .read(requestContextProvider.notifier)
        .updateScene(_sceneToAppScene(scene));
  }

  AppScene _sceneToAppScene(SceneType scene) {
    switch (scene) {
      case SceneType.capture:
        return AppScene.capture;
      case SceneType.think:
        return AppScene.think;
      case SceneType.connect:
        return AppScene.connect;
    }
  }

  void _toggleLeftPanel() =>
      setState(() => _leftPanelExpanded = !_leftPanelExpanded);
  void _toggleRightPanel() =>
      setState(() => _rightPanelExpanded = !_rightPanelExpanded);
  void _onNoteOpened() {
    if (_currentScene != SceneType.think) {
      _switchScene(SceneType.think);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vaultState = ref.watch(vaultProvider);
    // 用 ref.listen 监听 vault 变化，只在 vault 真正变化时才更新 requestContext。
    // 之前的实现是在 build 中注册 addPostFrameCallback —— 这是反模式：
    // 1) 每次 MainLayout rebuild 都注册一个新 callback（每帧都注册）
    // 2) callback 调用 updateVault，而 copyWith(capturedAt: DateTime.now())
    //    总是产生新实例，总是触发 Riverpod 通知
    // 3) 即使无 widget watch requestContextProvider，notifier 的 state 赋值
    //    仍会触发内部处理，在 AXTree 已脆弱时加剧 churn
    // ref.listen 是 Riverpod 推荐方式：只在依赖变化时触发，不在每帧调用。
    ref.listen<VaultState>(vaultProvider, (prev, next) {
      final notifier = ref.read(requestContextProvider.notifier);
      if (next.currentVault == null) {
        notifier.updateVault(null);
      } else {
        final v = next.currentVault!;
        notifier.updateVault(VaultSnapshot(name: v.name, path: v.path));
      }
    });
    if (vaultState.currentVault == null && !vaultState.isLoading) {
      return Scaffold(
        body: EmptyVaultGuide(onCreateVault: () => _openVaultDialog()),
      );
    }
    return Scaffold(
      body: CallbackShortcuts(
        bindings: _shortcuts(),
        child: Focus(
          autofocus: true,
          child: Stack(
            children: [
              SceneScaffold(
                initialScene: _currentScene,
                captureView: (_) => CaptureScene(
                  leftPanelExpanded: _leftPanelExpanded,
                  rightPanelExpanded: _rightPanelExpanded,
                  onToggleLeftPanel: _toggleLeftPanel,
                  onToggleRightPanel: _toggleRightPanel,
                  onNoteOpened: _onNoteOpened,
                ),
                thinkView: (_) => ThinkScene(
                  leftPanelExpanded: _leftPanelExpanded,
                  rightPanelExpanded: _rightPanelExpanded,
                  onToggleLeftPanel: _toggleLeftPanel,
                  onToggleRightPanel: _toggleRightPanel,
                  onCreateNote: _createNewNote,
                  onNoteOpened: _onNoteOpened,
                ),
                connectView: (_) => ConnectScene(
                  initialViewMode: _connectViewMode,
                  leftPanelExpanded: _leftPanelExpanded,
                  rightPanelExpanded: _rightPanelExpanded,
                  onToggleLeftPanel: _toggleLeftPanel,
                  onToggleRightPanel: _toggleRightPanel,
                ),
                statusBar: StatusBar(
                  onCommandBar: () =>
                      setState(() => _showCommandBar = true),
                ),
                onSceneChanged: _switchScene,
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
              const SpeedDialFAB(),
            ],
          ),
        ),
      ),
    );
  }

  Map<ShortcutActivator, VoidCallback> _shortcuts() {
    final b = <ShortcutActivator, VoidCallback>{};
    for (final e in ref.read(shortcutServiceProvider).allBindings.entries) {
      final a = parseShortcut(e.value);
      final h = _handler(e.key);
      if (a != null && h != null) b[a] = h;
    }
    b[const SingleActivator(LogicalKeyboardKey.escape)] = () {
      if (_showCommandBar) {
        setState(() => _showCommandBar = false);
      }
    };
    return b;
  }

  VoidCallback? _handler(String action) => switch (action) {
    'new_note' => _createNewNote,
    'save' => () => ref.read(knowledgeProvider.notifier).saveActiveNote(),
    'search' || 'find' => () => setState(() => _showCommandBar = true),
    'toggle_editor' || 'switch_think' => () => _switchScene(SceneType.think),
    'toggle_browser' ||
    'switch_capture' => () => _switchScene(SceneType.capture),
    'toggle_graph' ||
    'toggle_canvas' ||
    'switch_connect' => () => _switchScene(SceneType.connect),
    'connect_canvas' => () {
      _switchScene(SceneType.connect);
      _connectViewMode = ConnectViewMode.canvas;
    },
    'connect_graph' => () {
      _switchScene(SceneType.connect);
      _connectViewMode = ConnectViewMode.graph;
    },
    'daily_note' => () {
      ref.read(knowledgeProvider.notifier).createDailyNote(DateTime.now());
      _switchScene(SceneType.think);
    },
    'settings' => () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    ),
    'memory_browser' => () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MemoryBrowserPage()),
    ),
    _ => null,
  };

  void _handleCommand(String command) {
    if (command.startsWith('/')) {
      _executeQuickMove(command);
      return;
    }
    final c = command.toLowerCase();
    if (c.contains('new note')) {
      _createNewNote();
    } else if (c.contains('new tab')) {
      ref.read(browserProvider.notifier).createTab(url: 'https://www.bing.com');
      _switchScene(SceneType.capture);
    } else if (c.contains('daily note')) {
      ref.read(knowledgeProvider.notifier).createDailyNote(DateTime.now());
      _switchScene(SceneType.think);
    } else if (c.contains('graph')) {
      _switchScene(SceneType.connect);
    } else if (c.contains('settings')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SettingsPage()),
      );
    } else if (c.contains('theme')) {
      final settings = ref.read(settingsProvider);
      final isDark = settings.isDarkMode;
      final newBg = isDark ? const Color(0xFFFAFCFF) : const Color(0xFF0F172A);
      ref.read(settingsProvider.notifier).setScaffoldBgColor(newBg);
    } else if (c.contains('research')) {
      ref.read(agentProvider.notifier).research(command);
    } else {
      ref.read(aiProvider.notifier).sendMessage(command);
    }
  }

  void _createNewNote() async {
    final title = await showCreateNoteDialog(context);
    if (title != null && title.isNotEmpty) {
      await ref.read(knowledgeProvider.notifier).createNote(title: title);
      _switchScene(SceneType.think);
    }
  }

  void _executeQuickMove(String command) {
    final parts = command.substring(1).split(' ');
    final match = ref.read(quickMoveProvider).matching(parts[0]).firstOrNull;
    if (match == null) return;
    ref.read(quickMoveProvider.notifier).recordUsage(match.id);
    final ctx = ref.read(quickMoveContextProvider);
    final args = <String, String>{
      'input': parts.skip(1).join(' '),
      if (ctx.pageContent != null)
        'pageContent': ctx.pageContent!.length > 8000
            ? ctx.pageContent!.substring(0, 8000)
            : ctx.pageContent!,
      if (ctx.selectedText != null)
        'selectedText': ctx.selectedText!.length > 4000
            ? ctx.selectedText!.substring(0, 4000)
            : ctx.selectedText!,
      if (ctx.currentUrl != null) 'pageUrl': ctx.currentUrl!,
      if (ctx.noteContent != null)
        'noteContent': ctx.noteContent!.length > 8000
            ? ctx.noteContent!.substring(0, 8000)
            : ctx.noteContent!,
    };
    ref.read(aiProvider.notifier).sendMessage(match.resolvePrompt(args));
  }

  Future<void> _openVaultDialog() async {
    final l = AppLocalizations.of(context)!;
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: l.selectVaultLocation,
    );
    if (result != null) {
      await ref.read(vaultProvider.notifier).openVault(result);
      ref.read(knowledgeProvider.notifier).loadAllNotes();
      ref.read(browserProvider.notifier).loadBookmarks();
    }
  }
}
