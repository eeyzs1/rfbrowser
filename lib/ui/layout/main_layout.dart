import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/browser_service.dart';
import '../../services/knowledge_service.dart';
import '../../services/ai_service.dart';
import '../../services/settings_service.dart';
import '../../services/shortcut_service.dart';
import '../../services/agent_service.dart';
import '../../services/quick_move_service.dart';
import '../../data/stores/vault_store.dart';
import '../widgets/command_bar.dart';
import '../widgets/create_note_dialog.dart';
import '../widgets/empty_vault_guide.dart';
import '../widgets/status_bar.dart';
import '../scenes/capture/capture_scene.dart';
import '../scenes/think/think_scene.dart';
import '../scenes/connect/connect_scene.dart';
import '../pages/settings_page.dart';
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

  void _switchScene(SceneType scene) => setState(() => _currentScene = scene);

  @override
  Widget build(BuildContext context) {
    final vaultState = ref.watch(vaultProvider);
    if (vaultState.currentVault == null && !vaultState.isLoading) {
      return Scaffold(
        body: EmptyVaultGuide(
          onCreateVault: () => ref.read(vaultProvider.notifier).closeVault(),
        ),
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
                captureView: (_) => const CaptureScene(),
                thinkView: (_) => ThinkScene(onCreateNote: _createNewNote),
                connectView: (_) => const ConnectScene(),
                statusBar: const StatusBar(),
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
      if (_showCommandBar) setState(() => _showCommandBar = false);
    };
    b[const SingleActivator(LogicalKeyboardKey.digit1, control: true)] =
        () => _switchScene(SceneType.capture);
    b[const SingleActivator(LogicalKeyboardKey.digit2, control: true)] =
        () => _switchScene(SceneType.think);
    b[const SingleActivator(LogicalKeyboardKey.digit3, control: true)] =
        () => _switchScene(SceneType.connect);
    return b;
  }

  VoidCallback? _handler(String action) => switch (action) {
    'new_note' => _createNewNote,
    'save' => () => ref.read(knowledgeProvider.notifier).saveActiveNote(),
    'search' || 'find' => () => setState(() => _showCommandBar = true),
    'toggle_editor' => () => _switchScene(SceneType.think),
    'toggle_browser' => () => _switchScene(SceneType.capture),
    'toggle_graph' || 'toggle_canvas' => () => _switchScene(SceneType.connect),
    'daily_note' => () {
      ref.read(knowledgeProvider.notifier).createDailyNote(DateTime.now());
      _switchScene(SceneType.think);
    },
    'settings' => () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsPage()),
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
      ref.read(settingsProvider.notifier).toggleDarkMode();
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
      if (ctx.pageContent != null) 'pageContent': ctx.pageContent!.length > 8000 ? ctx.pageContent!.substring(0, 8000) : ctx.pageContent!,
      if (ctx.selectedText != null) 'selectedText': ctx.selectedText!.length > 4000 ? ctx.selectedText!.substring(0, 4000) : ctx.selectedText!,
      if (ctx.currentUrl != null) 'pageUrl': ctx.currentUrl!,
      if (ctx.noteContent != null) 'noteContent': ctx.noteContent!.length > 8000 ? ctx.noteContent!.substring(0, 8000) : ctx.noteContent!,
    };
    ref.read(aiProvider.notifier).sendMessage(match.resolvePrompt(args));
  }
}
