import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../services/command_execution_service.dart';
import '../../services/knowledge_service.dart';
import '../../services/shortcut_service.dart';
import '../../services/vault_workflow_service.dart';
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
import 'layout_state_manager.dart';
import 'scene_scaffold.dart';
import 'keyboard_util.dart';

class MainLayout extends ConsumerStatefulWidget {
  const MainLayout({super.key});
  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout> {
  bool _showCommandBar = false;
  bool _showSettings = false;
  SceneType _currentScene = SceneType.capture;

  void _openSettings() {
    setState(() => _showSettings = true);
  }

  void _closeSettings() {
    setState(() => _showSettings = false);
  }

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
      ref.read(layoutStateManagerProvider.notifier).toggleLeftPanel();
  void _toggleRightPanel() =>
      ref.read(layoutStateManagerProvider.notifier).toggleRightPanel();
  void _onNoteOpened() {
    if (_currentScene != SceneType.think) {
      _switchScene(SceneType.think);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vaultState = ref.watch(vaultProvider);
    final layoutState = ref.watch(layoutStateManagerProvider);
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
              // 根因修复（2026-07-05）：用 AbsorbPointer 替代 Offstage。
              //
              // 之前的 Offstage(offstage: true) 会从 semantics 树中移除
              // SceneScaffold 的 23 个节点（#5-#27）。当 _openSettings 触发此
              // 移除时，native AXTree 出现大 diff（28→16 节点），导致 WebView2
              // 的 native accessibility 节点（如 63）失去 Flutter 层的父引用 →
              // orphan → accessibility_bridge.cc(114) Failed to update ui::AXTree
              // → 进程崩溃。
              //
              // 诊断证据（error.log）：
              // - 启动 MainLayout frame #1-3：28 节点，无 accessibility_bridge 报错
              // - _openSettings 后：16 节点（SceneScaffold semantics 被移除）
              // - line 162-163：accessibility_bridge.cc(114) error: 63
              // 节点 63 从未出现在 Flutter 层（#0-#38），是 native 节点。
              //
              // AbsorbPointer(absorbing: true) 只屏蔽触摸，不移除 semantics。
              // SceneScaffold 始终保留在 semantics 树里，native 节点 63 始终有
              // 父引用。开关设置时树只增减 SettingsPage 的节点（~11 个），
              // 不触碰 SceneScaffold（含 WebView 的 native 节点）。
              // 副作用：SceneScaffold 在 settings 期间仍 watch provider 但不显示；
              // WebView 继续运行（保留页面状态）——可接受。
              AbsorbPointer(
                absorbing: _showSettings,
                child: SceneScaffold(
                  initialScene: _currentScene,
                  captureView: (_) => CaptureScene(
                    leftPanelExpanded: layoutState.leftPanelExpanded,
                    rightPanelExpanded: layoutState.rightPanelExpanded,
                    onToggleLeftPanel: _toggleLeftPanel,
                    onToggleRightPanel: _toggleRightPanel,
                    onNoteOpened: _onNoteOpened,
                  ),
                  thinkView: (_) => ThinkScene(
                    leftPanelExpanded: layoutState.leftPanelExpanded,
                    rightPanelExpanded: layoutState.rightPanelExpanded,
                    onToggleLeftPanel: _toggleLeftPanel,
                    onToggleRightPanel: _toggleRightPanel,
                    onCreateNote: _createNewNote,
                    onNoteOpened: _onNoteOpened,
                  ),
                  connectView: (_) => ConnectScene(
                    initialViewMode: layoutState.connectViewMode,
                    leftPanelExpanded: layoutState.leftPanelExpanded,
                    rightPanelExpanded: layoutState.rightPanelExpanded,
                    onToggleLeftPanel: _toggleLeftPanel,
                    onToggleRightPanel: _toggleRightPanel,
                  ),
                  statusBar: StatusBar(
                    onCommandBar: () => setState(() => _showCommandBar = true),
                    onSettings: _openSettings,
                  ),
                  onSceneChanged: _switchScene,
                  onSettings: _openSettings,
                ),
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
              // 根因修复（2026-07-05，final）：条件渲染 + 自定义 binding 禁用 semantics。
              //
              // 这是 Flutter engine 已知 bug（flutter/flutter#98099, #103808）：
              // 当 semantics 子树 mount/unmount 时，Windows accessibility_bridge 的
              // ui::AXTree::Unserialize 会失败（"NNN will not be in the tree"）。
              //
              // 尝试过的方案及结果：
              // 1. Completer（main.dart）：解决启动阶段 race condition ✓
              // 2. AbsorbPointer 替代 Offstage（SceneScaffold）：保留节点 ✓
              // 3. Offstage 替代条件渲染（SettingsPage/SpeedDialFAB）：节点 ID
              //    稳定但 isHidden 标志翻转会从 framework 树移除/重新挂载节点，
              //    错误数从 3 暴增到 27（error 57×22 + 63×1 + 74×1 + 83×1）✗
              // 4. `setSemanticsTreeEnabled(false)` 单独使用：无效，该 API 只告诉
              //    engine "可释放资源"，不阻止 framework 发送 semantics 更新 ✗
              // 5. `onSemanticsEnabledChanged = no-op`：太晚，handle 在 initInstances
              //    期间已创建 ✗
              //
              // 根因（Flutter SDK 源码分析）：
              // - Windows 上 `platformDispatcher.semanticsEnabled` 从 app 启动起就为 true
              // - `SemanticsBinding.initInstances` 调用 `ensureSemantics()` →
              //   `_semanticsEnabled.value = true` → `_semanticsOwner` 创建 →
              //   framework 持续发送 semantics 更新 → AXTree diff 冲突
              //
              // 唯一彻底方案：在 main.dart 中创建自定义 binding 子类
              // `RFBrowserBinding extends WidgetsFlutterBinding`，override
              // `semanticsEnabled` getter 返回 false。这让 PipelineOwner 看到
              // semantics 为 disabled → 不创建 `_semanticsOwner` → flushSemantics
              // 直接 return → 不发送 updateSemantics → 无 AXTree diff → 无冲突。
              // 详见 lib/core/rf_browser_binding.dart。
              //
              // 代价：屏幕阅读器无法读取 UI。但当前状态下 a11y 已被错误破坏，
              // 禁用 semantics 反而让 app 稳定可用。等 Flutter 修复 engine bug 后
              // 可移除 RFBrowserBinding 的 override 恢复 a11y。
              if (_showSettings) SettingsPage(onBack: _closeSettings),
              if (!_showSettings) const SpeedDialFAB(),
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
      ref
          .read(layoutStateManagerProvider.notifier)
          .setConnectViewMode(ConnectViewMode.canvas);
    },
    'connect_graph' => () {
      _switchScene(SceneType.connect);
      ref
          .read(layoutStateManagerProvider.notifier)
          .setConnectViewMode(ConnectViewMode.graph);
    },
    'daily_note' => () {
      ref.read(knowledgeProvider.notifier).createDailyNote(DateTime.now());
      _switchScene(SceneType.think);
    },
    'settings' => _openSettings,
    'memory_browser' => () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MemoryBrowserPage()),
    ),
    _ => null,
  };

  Future<void> _handleCommand(String command) async {
    final effect = await ref
        .read(commandExecutionProvider)
        .executeCommand(command);
    if (!mounted) return;
    switch (effect) {
      case CommandEffectNone():
        break;
      case CommandEffectSwitchScene(:final scene):
        _switchScene(scene);
      case CommandEffectOpenSettings():
        _openSettings();
      case CommandEffectCreateNote():
        _createNewNote();
      case CommandEffectOpenMemoryBrowser():
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MemoryBrowserPage()),
        );
    }
  }

  void _createNewNote() async {
    final title = await showCreateNoteDialog(context);
    if (title != null && title.isNotEmpty) {
      await ref.read(knowledgeProvider.notifier).createNote(title: title);
      _switchScene(SceneType.think);
    }
  }

  Future<void> _openVaultDialog() async {
    final l = AppLocalizations.of(context)!;
    await ref.read(vaultWorkflowProvider).promptAndOpenVault(l);
  }
}
