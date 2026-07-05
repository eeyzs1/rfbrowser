import 'package:flutter/widgets.dart';

/// 自定义 binding：强制禁用 framework semantics。
///
/// 背景：Flutter engine 存在已知 bug（flutter/flutter#98099, #103808），
/// 当 framework semantics 子树 mount/unmount 时，engine 把 semantics 更新
/// 推送到 native AXTree，与 WebView2 自己创建的 native 节点（如 57/63）
/// 在 AXTree diff 阶段冲突，产生 orphan 节点 → AXTree 损坏 → 进程崩溃。
///
/// 在 Windows 上，`platformDispatcher.semanticsEnabled` 从 app 启动起就为 true
/// （Windows 自动探测新窗口的 accessibility），导致 `SemanticsBinding.initInstances`
/// 调用 `_handleSemanticsEnabledChanged()` → `ensureSemantics()` → 创建 `_semanticsHandle`
/// → `_outstandingHandles = 1`，`_semanticsEnabled.value = true`。
/// 这让 `PipelineOwner._updateSemanticsOwner` 看到 semantics 为 enabled → 创建
/// `_semanticsOwner` → `flushSemantics` 调用 `sendSemanticsUpdate` → engine 接收
/// `updateSemantics` → 触发 AXTree diff → 与 WebView2 native 节点冲突 → 错误。
///
/// 已尝试但无效的方案：
/// 1. 替换 `platformDispatcher.onSemanticsEnabledChanged` 为 no-op：
///    太晚 —— handle 在 initInstances 期间已创建
/// 2. `PlatformDispatcher.instance.setSemanticsTreeEnabled(false)`：
///    只告诉 engine "platform 可释放资源"，不阻止 framework 发送 semantics 更新
/// 3. `Offstage` / `AbsorbPointer` / 条件渲染等 UI 层方案：
///    无法消除 mount/unmount 触发的 AXTree 更新冲突
///
/// 正确方案：override `SemanticsBinding.semanticsEnabled` getter 返回 false。
/// - `_semanticsEnabled.value` 内部仍为 true（由 ensureSemantics 设置），
///   但所有读取都经过我们的 getter（返回 false）
/// - `PipelineOwner._updateSemanticsOwner` 检查 `_manifold?.semanticsEnabled`
///   → 返回 false → 不创建 `_semanticsOwner`
/// - `flushSemantics` 检查 `if (_semanticsOwner == null) return;` → 直接 return
/// - 无 `updateSemantics` 发送给 engine → 无 AXTree diff → 无错误
///
/// `_handleFrameworkSemanticsEnabledChanged` 监听 `_semanticsEnabled` ValueNotifier，
/// 当 value 变化时调用 `platformDispatcher.setSemanticsTreeEnabled(semanticsEnabled)`
/// —— 使用我们的 override（false），所以 engine 树也会被禁用。
/// 但这个监听器在 init 期间添加得比 ensureSemantics 调用晚，所以初始的
/// `_semanticsEnabled.value = true` 不会触发它。需要在 main.dart 中显式调用
/// `setSemanticsTreeEnabled(false)` 来兜底禁用 engine 树。
///
/// 代价：屏幕阅读器无法读取 UI。但当前 Flutter engine 存在已知 bug，
/// a11y 已被破坏（AXTree 损坏导致屏幕阅读器行为不可靠），禁用反而让 app
/// 稳定可用。等 Flutter 修复 engine bug（#98099/#103808）后，移除此 override
/// 即可恢复 a11y。
class RFBrowserBinding extends WidgetsFlutterBinding {
  @override
  bool get semanticsEnabled => false;
}
