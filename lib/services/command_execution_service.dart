import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../ui/layout/scene_scaffold.dart';
import 'agent_service.dart';
import 'ai_service.dart';
import 'browser_service.dart';
import 'knowledge_service.dart';
import 'quick_move_service.dart';
import 'settings_service.dart';

/// Outcome of executing a user command. The UI layer interprets these
/// effects to perform widget-tree actions (show dialog, switch scene, …)
/// that cannot live inside a service.
sealed class CommandEffect {
  const CommandEffect();
}

/// Nothing for the UI to do — the service already performed all side
/// effects (e.g. dispatched an AI message, toggled theme).
class CommandEffectNone extends CommandEffect {
  const CommandEffectNone();
}

/// Ask the UI to switch the active scene.
class CommandEffectSwitchScene extends CommandEffect {
  final SceneType scene;
  const CommandEffectSwitchScene(this.scene);
}

/// Ask the UI to open the settings page.
class CommandEffectOpenSettings extends CommandEffect {
  const CommandEffectOpenSettings();
}

/// Ask the UI to prompt for a new note title and create the note.
class CommandEffectCreateNote extends CommandEffect {
  const CommandEffectCreateNote();
}

/// Ask the UI to open the memory browser page.
class CommandEffectOpenMemoryBrowser extends CommandEffect {
  const CommandEffectOpenMemoryBrowser();
}

/// Executes user commands originating from the command bar, keyboard
/// shortcuts, or quick-move prompts.
///
/// Extracted from `MainLayout` to decouple command business logic from UI
/// coordination. The service performs all service-level side effects and
/// returns a [CommandEffect] describing any remaining UI action.
class CommandExecutionService {
  final Ref _ref;

  CommandExecutionService(this._ref);

  /// Parse and execute a free-text [command]. Returns the [CommandEffect]
  /// the caller should apply on the widget tree.
  Future<CommandEffect> executeCommand(String command) async {
    if (command.startsWith('/')) {
      await _executeQuickMove(command);
      return const CommandEffectNone();
    }

    final c = command.toLowerCase();

    if (c.contains('new note')) {
      return const CommandEffectCreateNote();
    } else if (c.contains('new tab')) {
      _ref
          .read(browserProvider.notifier)
          .createTab(url: 'https://www.bing.com');
      return const CommandEffectSwitchScene(SceneType.capture);
    } else if (c.contains('daily note')) {
      await _ref
          .read(knowledgeProvider.notifier)
          .createDailyNote(DateTime.now());
      return const CommandEffectSwitchScene(SceneType.think);
    } else if (c.contains('graph')) {
      return const CommandEffectSwitchScene(SceneType.connect);
    } else if (c.contains('settings')) {
      return const CommandEffectOpenSettings();
    } else if (c.contains('memory browser')) {
      return const CommandEffectOpenMemoryBrowser();
    } else if (c.contains('theme')) {
      await _toggleTheme();
      return const CommandEffectNone();
    } else if (c.contains('research')) {
      _ref.read(agentProvider.notifier).research(command);
      return const CommandEffectNone();
    } else {
      _ref.read(aiProvider.notifier).sendMessage(command);
      return const CommandEffectNone();
    }
  }

  /// Toggle between a dark and a light scaffold background. Mirrors the
  /// behaviour previously inlined in `MainLayout._handleCommand`.
  Future<void> _toggleTheme() async {
    final settings = _ref.read(settingsProvider);
    final isDark = settings.isDarkMode;
    final newBg = isDark ? const Color(0xFFFAFCFF) : const Color(0xFF0F172A);
    await _ref.read(settingsProvider.notifier).setScaffoldBgColor(newBg);
  }

  /// Resolve a `/name args…` quick-move prompt and dispatch it to the AI.
  Future<void> _executeQuickMove(String command) async {
    final parts = command.substring(1).split(' ');
    final match = _ref.read(quickMoveProvider).matching(parts[0]).firstOrNull;
    if (match == null) return;

    _ref.read(quickMoveProvider.notifier).recordUsage(match.id);

    final ctx = _ref.read(quickMoveContextProvider);
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

    _ref.read(aiProvider.notifier).sendMessage(match.resolvePrompt(args));
  }
}

final commandExecutionProvider = Provider<CommandExecutionService>((ref) {
  return CommandExecutionService(ref);
});
