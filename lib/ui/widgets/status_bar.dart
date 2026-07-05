import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../services/browser_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/knowledge_service.dart';
import '../../services/webdav_sync_service.dart';
import '../../data/stores/vault_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StatusBar extends ConsumerStatefulWidget {
  final VoidCallback? onCommandBar;
  final VoidCallback? onSettings;
  const StatusBar({super.key, this.onCommandBar, this.onSettings});

  @override
  ConsumerState<StatusBar> createState() => _StatusBarState();
}

class _StatusBarState extends ConsumerState<StatusBar> {
  DateTime? _lastSyncTime;

  @override
  void initState() {
    super.initState();
    _loadLastSyncTime();
  }

  /// 从 SharedPreferences 加载上次同步时间
  Future<void> _loadLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final iso = prefs.getString('lastSyncTime');
    if (iso != null) {
      final parsed = DateTime.tryParse(iso);
      if (parsed != null && mounted) setState(() => _lastSyncTime = parsed);
    }
  }

  /// 持久化上次同步时间
  Future<void> _saveLastSyncTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastSyncTime', time.toIso8601String());
  }

  /// 格式化相对时间（如"2分钟前"）
  String _relativeTime(DateTime time) {
    final d = DateTime.now().difference(time);
    if (d.inSeconds < 5) return '刚刚';
    if (d.inMinutes < 1) return '${d.inSeconds}秒前';
    if (d.inHours < 1) return '${d.inMinutes}分钟前';
    if (d.inDays < 1) return '${d.inHours}小时前';
    return '${d.inDays}天前';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    final browserState = ref.watch(browserProvider);
    final knowledgeState = ref.watch(knowledgeProvider);
    final vaultState = ref.watch(vaultProvider);
    final connectivityState = ref.watch(connectivityProvider);
    final webdavState = ref.watch(webdavSyncProvider);
    final hasVault = vaultState.currentVault != null;
    final isOffline = !connectivityState.isOnline;

    // 监听 WebDAV 同步状态变化，成功时记录时间
    ref.listen<WebDAVSyncState>(webdavSyncProvider, (prev, next) {
      if (prev?.status != SyncStatus.success &&
          next.status == SyncStatus.success) {
        final now = DateTime.now();
        _saveLastSyncTime(now);
        setState(() => _lastSyncTime = now);
      }
    });

    // 计算同步状态展示内容
    final syncWidget = _buildSyncStatus(
      theme: theme,
      l: l,
      isOffline: isOffline,
      isSyncing: connectivityState.isSyncing ||
          webdavState.status == SyncStatus.syncing,
      hasError: webdavState.status == SyncStatus.error,
    );

    // 稳定语义策略：StatusBar 有两类内容 ——
    // (1) 纯状态文本（版本号、在线/离线、笔记数、标签数、同步状态文本）：
    //     受 5 个 provider 驱动频繁 churn，用 ExcludeSemantics 屏蔽，避免
    //     启动时 AXTree diff 失败。
    // (2) 交互入口（命令栏按钮 + 同步设置跳转）：之前的 outer ExcludeSemantics
    //     把这两个交互元素也一并移除，屏幕阅读器用户无法触发命令栏或跳转
    //     同步设置 —— a11y 倒退。注释"纯状态指示器"也是错误的。
    //     现拆分：左侧状态文本用 Expanded+ExcludeSemantics+Spacer 占满左侧；
    //     命令栏和同步入口用 Semantics(button, label)+ExcludeSemantics(InkWell)
    //     提供稳定 button 节点，InkWell 的动态 semantics 被屏蔽。
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.appBarTheme.backgroundColor,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          // 左侧状态文本：Expanded 让 Spacer 把右侧内容推到右边。
          Expanded(
            child: ExcludeSemantics(
              child: Row(
                children: [
                  Text('RFBrowser v0.3.0', style: theme.textTheme.bodySmall),
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
                    isOffline ? l.offline : (hasVault ? l.ready : l.noVault),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isOffline ? const Color(0xFFEF4444) : null,
                    ),
                  ),
                  if (isOffline &&
                      connectivityState.syncQueue.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.cloud_upload, size: 10, color: theme.hintColor),
                    const SizedBox(width: 4),
                    Text(
                      l.pendingCount(connectivityState.syncQueue.length),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  if (hasVault && !isOffline) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.description, size: 10, color: theme.hintColor),
                    const SizedBox(width: 4),
                    Text(
                      l.notesCount(knowledgeState.notes.length),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  const Spacer(),
                ],
              ),
            ),
          ),
          // 命令栏入口（交互元素，与 Ctrl+K 快捷键效果相同）：
          // Semantics 提供稳定 button 角色 + label，ExcludeSemantics 屏蔽
          // InkWell 动态 semantics。
          if (widget.onCommandBar != null) ...[
            Semantics(
              button: true,
              label: l.commandBar,
              child: ExcludeSemantics(
                child: InkWell(
                  onTap: widget.onCommandBar,
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search, size: 12, color: theme.hintColor),
                        const SizedBox(width: 4),
                        Text(
                          l.commandBar,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.hintColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          // 标签数（纯文本状态）：ExcludeSemantics
          ExcludeSemantics(
            child: Text(
              l.tabsCount(browserState.tabs.length),
              style: theme.textTheme.bodySmall,
            ),
          ),
          // 同步状态入口（可点击跳转同步设置）：Semantics 提供稳定 button 角色，
          // 屏蔽内部 churning 状态文本 + CircularProgressIndicator。
          if (hasVault) ...[
            const SizedBox(width: 12),
            Semantics(
              button: true,
              label: 'Sync settings',
              child: ExcludeSemantics(child: syncWidget),
            ),
          ],
        ],
      ),
    );
  }

  /// 构建同步状态区域（可点击跳转到同步设置）
  Widget _buildSyncStatus({
    required ThemeData theme,
    required AppLocalizations l,
    required bool isOffline,
    required bool isSyncing,
    required bool hasError,
  }) {
    // 离线：灰色图标 + "离线"
    if (isOffline) {
      return _syncTapTarget(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 10, color: theme.hintColor),
            const SizedBox(width: 4),
            Text(l.offline, style: theme.textTheme.bodySmall?.copyWith(
              color: theme.hintColor,
            )),
          ],
        ),
      );
    }

    // 同步中：旋转图标 + "同步中..."
    if (isSyncing) {
      return _syncTapTarget(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ExcludeSemantics：CircularProgressIndicator 内部用
            // AnimationController.repeat() 每帧更新语义 value 属性，
            // 持续向 AXTree 提交更新。在 AXTree 已脆弱时（如启动期间
            // 或主题切换触发的全树重建），会触发 accessibility_bridge
            // AXTree diff 失败导致进程崩溃。ExcludeSemantics 后该
            // 指示器不再向语义树贡献节点。
            ExcludeSemantics(
              child: SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Text(l.syncing, style: theme.textTheme.bodySmall),
          ],
        ),
      );
    }

    // 同步失败：红色图标 + "同步失败"
    if (hasError) {
      return _syncTapTarget(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sync_problem, size: 10, color: theme.colorScheme.error),
            const SizedBox(width: 4),
            Text(
              l.syncFailed,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ),
      );
    }

    // 同步成功 / 空闲：显示上次同步时间
    if (_lastSyncTime != null) {
      return _syncTapTarget(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sync, size: 10, color: theme.hintColor),
            const SizedBox(width: 4),
            Text(
              l.syncedAgo(_relativeTime(_lastSyncTime!)),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    // 无同步记录：显示静态 Git 文字（与原行为一致）
    return _syncTapTarget(
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sync, size: 10, color: theme.hintColor),
          const SizedBox(width: 4),
          Text(l.git, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  /// 包装同步状态为可点击区域，点击跳转到设置页
  Widget _syncTapTarget(Widget child) {
    return Tooltip(
      message: 'Sync settings',
      child: InkWell(
        onTap: widget.onSettings,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: child,
        ),
      ),
    );
  }
}
