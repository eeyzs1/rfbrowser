import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lightweight information about the active vault, derived from any widget
/// that knows the current workspace. The [vaultProvider] (already wired in
/// [MemoryService]) gives us the canonical root.
class VaultSnapshot {
  final String name;
  final String path;
  const VaultSnapshot({required this.name, required this.path});
}

/// Snapshot of the active note the user is reading or editing.
class ActiveNoteSnapshot {
  final String id;
  final String title;
  final String? path;
  final List<String> tags;
  const ActiveNoteSnapshot({
    required this.id,
    required this.title,
    this.path,
    this.tags = const [],
  });
}

/// The currently selected text in any editor surface. Used to anchor the
/// AI's response to a concrete passage when present.
class SelectionSnapshot {
  final String text;
  final int? startOffset;
  final int? endOffset;
  const SelectionSnapshot({
    required this.text,
    this.startOffset,
    this.endOffset,
  });
}

/// The top-level scene (capture / think / connect) the user is currently in.
enum AppScene { capture, think, connect, other }

/// Per-request ambient context. Mirrors OpenLoomi's `setAIUserContext` /
/// `AIUserContext` pattern: rather than threading a context argument
/// through every AI call site, callers set the ambient state on a global
/// notifier and the AI service reads it lazily inside `sendMessage`.
///
/// In RFBrowser this is much simpler than the OpenLoomi implementation
/// (no multi-tenant identity) — it's a single global "what is the user
/// doing right now" snapshot.
@immutable
class RequestContext {
  final VaultSnapshot? vault;
  final ActiveNoteSnapshot? activeNote;
  final SelectionSnapshot? selection;
  final AppScene scene;
  final DateTime? capturedAt;

  const RequestContext({
    this.vault,
    this.activeNote,
    this.selection,
    this.scene = AppScene.other,
    this.capturedAt,
  });

  static const RequestContext empty = RequestContext();

  RequestContext copyWith({
    VaultSnapshot? vault,
    bool clearVault = false,
    ActiveNoteSnapshot? activeNote,
    bool clearActiveNote = false,
    SelectionSnapshot? selection,
    bool clearSelection = false,
    AppScene? scene,
  }) {
    return RequestContext(
      vault: clearVault ? null : (vault ?? this.vault),
      activeNote: clearActiveNote ? null : (activeNote ?? this.activeNote),
      selection: clearSelection ? null : (selection ?? this.selection),
      scene: scene ?? this.scene,
      capturedAt: DateTime.now(),
    );
  }

  /// Format the context as a system-prompt block. Returns an empty string
  /// when no context is set, so the AI service can simply concatenate.
  String toSystemPromptBlock() {
    final buffer = StringBuffer();
    if (vault != null) {
      buffer.writeln('- Vault: ${vault!.name} (${vault!.path})');
    }
    if (activeNote != null) {
      final tags = activeNote!.tags.isEmpty
          ? ''
          : ' [tags: ${activeNote!.tags.join(', ')}]';
      buffer.writeln('- Active note: ${activeNote!.title}$tags');
    }
    if (selection != null && selection!.text.trim().isNotEmpty) {
      buffer.writeln(
        '- Current selection (verbatim):\n  ```\n  '
        '${selection!.text.trim().replaceAll('\n', '\n  ')}\n  ```',
      );
    }
    if (scene != AppScene.other) {
      buffer.writeln('- Current scene: ${scene.name}');
    }
    if (buffer.isEmpty) return '';
    return '[Ambient request context]\n${buffer.toString()}';
  }
}

class RequestContextNotifier extends Notifier<RequestContext> {
  @override
  RequestContext build() => RequestContext.empty;

  void updateVault(VaultSnapshot? vault) {
    // 相等性检查：避免 vault 内容未变时仍触发 state 赋值。
    // 之前的实现总是调用 copyWith(capturedAt: DateTime.now())，
    // 即使 vault 没变也会产生新实例并触发 Riverpod 通知，
    // 在 AXTree 已脆弱时加剧 widget tree churn。
    final oldVault = state.vault;
    final unchanged =
        (oldVault == null && vault == null) ||
        (oldVault != null &&
            vault != null &&
            oldVault.name == vault.name &&
            oldVault.path == vault.path);
    if (unchanged) return;
    state = state.copyWith(vault: vault, clearVault: vault == null);
  }

  void updateActiveNote(ActiveNoteSnapshot? note) {
    state = state.copyWith(activeNote: note, clearActiveNote: note == null);
  }

  void updateSelection(SelectionSnapshot? selection) {
    state = state.copyWith(
      selection: selection,
      clearSelection: selection == null,
    );
  }

  void updateScene(AppScene scene) {
    // 相等性检查：避免 scene 未变时仍触发 state 赋值。
    // copyWith 总是设置 capturedAt: DateTime.now()，即使 scene 没变
    // 也会产生新实例并触发 Riverpod 通知，在 AXTree 已脆弱时加剧 churn。
    if (state.scene == scene) return;
    state = state.copyWith(scene: scene);
  }

  /// Replace the entire snapshot in one call (used by the layout shell
  /// when scene switching changes multiple fields at once).
  void replace(RequestContext next) {
    state = next;
  }
}

/// Global provider for the ambient request context. UI components (e.g.
/// the main layout, editor pages) call setters on this notifier to keep
/// the AI service informed of the user's current focus.
final requestContextProvider =
    NotifierProvider<RequestContextNotifier, RequestContext>(
      RequestContextNotifier.new,
    );
