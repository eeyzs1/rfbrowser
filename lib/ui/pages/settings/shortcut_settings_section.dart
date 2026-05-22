import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/shortcut_service.dart';
import '../../widgets/settings_section.dart';

class ShortcutSettingsSection extends ConsumerStatefulWidget {
  const ShortcutSettingsSection({super.key});

  @override
  ConsumerState<ShortcutSettingsSection> createState() =>
      _ShortcutSettingsSectionState();
}

class _ShortcutSettingsSectionState
    extends ConsumerState<ShortcutSettingsSection> {
  late ShortcutService _service;
  String? _editingAction;
  final FocusNode _editFocusNode = FocusNode();
  bool _globalExpanded = true;
  bool _canvasExpanded = false;

  static const _globalActions = [
    'new_note',
    'save',
    'search',
    'toggle_editor',
    'toggle_browser',
    'toggle_graph',
    'toggle_canvas',
    'switch_capture',
    'switch_think',
    'switch_connect',
    'connect_canvas',
    'connect_graph',
    'daily_note',
    'toggle_preview',
    'settings',
    'find',
  ];

  static const _canvasActions = [
    'canvas_undo',
    'canvas_redo',
    'canvas_delete',
    'canvas_select_all',
    'canvas_group',
    'canvas_ungroup',
  ];

  @override
  void initState() {
    super.initState();
    _service = ref.read(shortcutServiceProvider);
  }

  @override
  void dispose() {
    _editFocusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (_editingAction == null) return KeyEventResult.ignored;
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      setState(() => _editingAction = null);
      return KeyEventResult.handled;
    }

    final isModifier = key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight ||
        key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight ||
        key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight ||
        key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight;
    if (isModifier) return KeyEventResult.handled;

    final parts = <String>[];
    if (HardwareKeyboard.instance.isControlPressed) parts.add('Ctrl');
    if (HardwareKeyboard.instance.isShiftPressed) parts.add('Shift');
    if (HardwareKeyboard.instance.isAltPressed) parts.add('Alt');
    if (HardwareKeyboard.instance.isMetaPressed) parts.add('Meta');

    final keyName = _keyToName(key);
    if (keyName == null) return KeyEventResult.handled;
    parts.add(keyName);

    final shortcut = parts.join('+');
    final existing = _service.findActionForShortcut(shortcut);
    if (existing != null && existing != _editingAction) {
      final l = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.shortcutConflictMsg(shortcut, _actionLabel(existing, l))),
        ),
      );
      return KeyEventResult.handled;
    }

    setState(() {
      _service.register(_editingAction!, shortcut);
      _editingAction = null;
    });
    _service.persist();
    return KeyEventResult.handled;
  }

  String? _keyToName(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.keyA) return 'A';
    if (key == LogicalKeyboardKey.keyB) return 'B';
    if (key == LogicalKeyboardKey.keyC) return 'C';
    if (key == LogicalKeyboardKey.keyD) return 'D';
    if (key == LogicalKeyboardKey.keyE) return 'E';
    if (key == LogicalKeyboardKey.keyF) return 'F';
    if (key == LogicalKeyboardKey.keyG) return 'G';
    if (key == LogicalKeyboardKey.keyH) return 'H';
    if (key == LogicalKeyboardKey.keyI) return 'I';
    if (key == LogicalKeyboardKey.keyJ) return 'J';
    if (key == LogicalKeyboardKey.keyK) return 'K';
    if (key == LogicalKeyboardKey.keyL) return 'L';
    if (key == LogicalKeyboardKey.keyM) return 'M';
    if (key == LogicalKeyboardKey.keyN) return 'N';
    if (key == LogicalKeyboardKey.keyO) return 'O';
    if (key == LogicalKeyboardKey.keyP) return 'P';
    if (key == LogicalKeyboardKey.keyQ) return 'Q';
    if (key == LogicalKeyboardKey.keyR) return 'R';
    if (key == LogicalKeyboardKey.keyS) return 'S';
    if (key == LogicalKeyboardKey.keyT) return 'T';
    if (key == LogicalKeyboardKey.keyU) return 'U';
    if (key == LogicalKeyboardKey.keyV) return 'V';
    if (key == LogicalKeyboardKey.keyW) return 'W';
    if (key == LogicalKeyboardKey.keyX) return 'X';
    if (key == LogicalKeyboardKey.keyY) return 'Y';
    if (key == LogicalKeyboardKey.keyZ) return 'Z';
    if (key == LogicalKeyboardKey.digit0) return '0';
    if (key == LogicalKeyboardKey.digit1) return '1';
    if (key == LogicalKeyboardKey.digit2) return '2';
    if (key == LogicalKeyboardKey.digit3) return '3';
    if (key == LogicalKeyboardKey.digit4) return '4';
    if (key == LogicalKeyboardKey.digit5) return '5';
    if (key == LogicalKeyboardKey.digit6) return '6';
    if (key == LogicalKeyboardKey.digit7) return '7';
    if (key == LogicalKeyboardKey.digit8) return '8';
    if (key == LogicalKeyboardKey.digit9) return '9';
    if (key == LogicalKeyboardKey.delete) return 'Delete';
    if (key == LogicalKeyboardKey.backspace) return 'Backspace';
    if (key == LogicalKeyboardKey.enter) return 'Enter';
    if (key == LogicalKeyboardKey.space) return 'Space';
    if (key == LogicalKeyboardKey.tab) return 'Tab';
    if (key == LogicalKeyboardKey.arrowUp) return 'Up';
    if (key == LogicalKeyboardKey.arrowDown) return 'Down';
    if (key == LogicalKeyboardKey.arrowLeft) return 'Left';
    if (key == LogicalKeyboardKey.arrowRight) return 'Right';
    if (key == LogicalKeyboardKey.f1) return 'F1';
    if (key == LogicalKeyboardKey.f2) return 'F2';
    if (key == LogicalKeyboardKey.f3) return 'F3';
    if (key == LogicalKeyboardKey.f4) return 'F4';
    if (key == LogicalKeyboardKey.f5) return 'F5';
    if (key == LogicalKeyboardKey.f6) return 'F6';
    if (key == LogicalKeyboardKey.f7) return 'F7';
    if (key == LogicalKeyboardKey.f8) return 'F8';
    if (key == LogicalKeyboardKey.f9) return 'F9';
    if (key == LogicalKeyboardKey.f10) return 'F10';
    if (key == LogicalKeyboardKey.f11) return 'F11';
    if (key == LogicalKeyboardKey.f12) return 'F12';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Focus(
      focusNode: _editFocusNode,
      onKeyEvent: _handleKey,
      child: SettingsSection(
        title: l.shortcuts,
        children: [
          _buildCategoryTile(
            theme: theme,
            title: l.globalShortcuts,
            isExpanded: _globalExpanded,
            onToggle: () => setState(() => _globalExpanded = !_globalExpanded),
            actions: _globalActions,
            l: l,
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _buildCategoryTile(
            theme: theme,
            title: l.canvasShortcuts,
            isExpanded: _canvasExpanded,
            onToggle: () => setState(() => _canvasExpanded = !_canvasExpanded),
            actions: _canvasActions,
            l: l,
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.restore, size: 18, color: theme.hintColor),
            title: Text(l.resetToDefaults),
            onTap: _resetToDefaults,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTile({
    required ThemeData theme,
    required String title,
    required bool isExpanded,
    required VoidCallback onToggle,
    required List<String> actions,
    required AppLocalizations l,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: isExpanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: theme.hintColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Column(children: _buildActionList(actions, l, theme)),
          crossFadeState:
              isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
          sizeCurve: Curves.easeInOut,
        ),
      ],
    );
  }

  List<Widget> _buildActionList(
    List<String> actions,
    AppLocalizations l,
    ThemeData theme,
  ) {
    return actions.map((action) {
      final shortcut = _service.getShortcut(action) ?? '';
      final isEditing = _editingAction == action;
      return ListTile(
        title: Text(_actionLabel(action, l)),
        subtitle: isEditing
            ? Text(
                l.pressNewShortcut,
                style: TextStyle(color: theme.colorScheme.primary),
              )
            : null,
        trailing: isEditing
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () => setState(() => _editingAction = null),
                    child: Text(l.cancel),
                  ),
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      shortcut,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 16),
                    onPressed: () {
                      setState(() => _editingAction = action);
                      Future.microtask(() => _editFocusNode.requestFocus());
                    },
                    tooltip: l.edit,
                  ),
                ],
              ),
        onTap: isEditing
            ? null
            : () {
                setState(() => _editingAction = action);
                Future.microtask(() => _editFocusNode.requestFocus());
              },
      );
    }).toList();
  }

  String _actionLabel(String action, AppLocalizations l) {
    return switch (action) {
      'new_note' => l.newNote,
      'save' => l.save,
      'search' => l.search,
      'toggle_editor' => l.editor,
      'toggle_browser' => l.browser,
      'toggle_graph' => l.graph,
      'toggle_canvas' => l.canvas,
      'switch_capture' => '${l.capture} (${l.switchScene})',
      'switch_think' => '${l.think} (${l.switchScene})',
      'switch_connect' => '${l.connect} (${l.switchScene})',
      'connect_canvas' => '${l.canvas} (${l.connect})',
      'connect_graph' => '${l.graph} (${l.connect})',
      'daily_note' => l.dailyNotes,
      'toggle_preview' => l.preview,
      'settings' => l.settings,
      'find' => l.search,
      'canvas_undo' => l.undo,
      'canvas_redo' => l.redo,
      'canvas_delete' => l.delete,
      'canvas_select_all' => l.selectAll,
      'canvas_group' => l.tooltipGroup,
      'canvas_ungroup' => l.ungroup,
      _ => action,
    };
  }

  void _resetToDefaults() {
    setState(() {
      _service.resetToDefaults();
      _editingAction = null;
    });
    _service.persist();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.shortcutsReset)),
    );
  }
}
