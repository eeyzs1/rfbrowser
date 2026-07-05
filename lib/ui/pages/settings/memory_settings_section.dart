import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/logging/app_logger.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/dreaming_service.dart';
import '../../../services/memory_service.dart';
import '../../../services/settings_service.dart';
import '../../widgets/settings_section.dart';

part 'memory_settings_widgets.dart';

/// SharedPreferences key 用于持久化高级参数区域的展开状态。
const _kAdvancedExpandedKey = 'memory_settings_advanced_expanded';

/// Settings panel for the memory subsystem — basic settings + operations.
///
/// 基础设置（始终显示）：环境上下文注入、Progressive forgetting 开关、
/// Dreaming 开关。操作状态：手动导出、备份恢复、Dreaming 状态卡片。
///
/// 高级参数（阈值、半衰期、衰减常数、Hebbian 连接等 10 个 Slider + 2 个
/// SwitchListTile）已拆出至 [MemoryAdvancedSettingsSection]，独立成 section。
/// 拆分目的：避免单 section 同时挂载大量 Slider，拖拽某个 Slider 时
/// onChanged 每帧写 provider 触发整个 section rebuild，放大 semantics
/// 节点时序竞争。拆分后基础设置与高级参数各自独立 rebuild。
///
/// Values are written through to [settingsProvider], which the dreaming
/// service and Hebbian service read on every rebuild — so changes take
/// effect immediately.
class MemorySettingsSection extends ConsumerWidget {
  const MemorySettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 用 select watch 整个 memory 子对象（参见 editor_settings_section.dart
    // 中的详细注释）。AppSettings.copyWith 在未传 memory 参数时复用
    // this.memory 引用（settings_service.dart:176），所以其他字段变化时
    // select 看到的 memory 引用相同 → 不会触发本 section 重建。
    final memory = ref.watch(settingsProvider.select((s) => s.memory));
    final notifier = ref.read(settingsProvider.notifier);
    final l = AppLocalizations.of(context)!;

    return SettingsSection(
      title: l.memorySettingsTitle,
      children: [
        // ── 基础设置（始终显示）──────────────────────────────────────
        _SectionHeader(label: l.ambientContext),
        SwitchListTile(
          title: const Text('Inject request context into AI prompts'),
          subtitle: const Text(
            'Send the current vault, active note, selection, and scene as '
            'part of every AI request. Disable for fully isolated chats.',
          ),
          value: memory.injectContext,
          onChanged: notifier.setMemoryInjectContext,
        ),
        const Divider(height: 1),
        const _SectionHeader(label: 'Progressive forgetting'),
        SwitchListTile(
          title: const Text('Use last-access time in recency scoring'),
          subtitle: const Text(
            'When on, recently-accessed memories are protected from '
            'forgetting even if they were extracted long ago. '
            'When off, the score uses the createdAt timestamp only '
            '(OpenLoomi original behavior).',
          ),
          value: memory.useLastAccessForRecency,
          onChanged: notifier.setMemoryUseLastAccessForRecency,
        ),
        const Divider(height: 1),
        _SectionHeader(label: l.autoExport),
        SwitchListTile(
          title: const Text('Enable background dreaming'),
          subtitle: const Text(
            'If disabled, the engine stops scoring and tier-transitioning '
            'fragments until you re-enable it.',
          ),
          value: memory.dreamingEnabled,
          onChanged: notifier.setMemoryDreamingEnabled,
        ),

        // ── 操作与状态（始终显示）────────────────────────────────────
        const Divider(height: 1),
        const _ManualExportTile(),
        const Divider(height: 1),
        _SectionHeader(label: l.backupAndRestore),
        const _BackupRestoreRow(),
        const Divider(height: 1),
        _SectionHeader(label: l.dreamingActivity),
        const _DreamingStatusCard(),
      ],
    );
  }
}

/// 高级参数 section（阈值、半衰期、衰减常数、Hebbian 连接等）。
///
/// 从原 [MemorySettingsSection] 拆出，独立成 section。默认折叠，展开时挂载
/// 10 个 Slider + 2 个 SwitchListTile。折叠时只渲染 toggle，子树完全不挂载，
/// 避免与基础设置 section 的 rebuild 牵连。
///
/// 展开状态持久化到 SharedPreferences（key: [_kAdvancedExpandedKey]）。
///
/// 条件渲染（无动画）：AnimatedCrossFade 在 200ms 动画期间会同时挂载
/// firstChild + secondChild 两套语义子树，批量涌入触发 AXTree diff 失败。
/// 改用 if/else 条件渲染，折叠时完全不挂载子树。
class MemoryAdvancedSettingsSection extends ConsumerStatefulWidget {
  const MemoryAdvancedSettingsSection({super.key});

  @override
  ConsumerState<MemoryAdvancedSettingsSection> createState() =>
      _MemoryAdvancedSettingsSectionState();
}

class _MemoryAdvancedSettingsSectionState
    extends ConsumerState<MemoryAdvancedSettingsSection> {
  /// 高级参数区域是否展开。从 SharedPreferences 读取初始值。
  bool _advancedExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadExpansionState();
  }

  Future<void> _loadExpansionState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _advancedExpanded = prefs.getBool(_kAdvancedExpandedKey) ?? false;
        });
      }
    } catch (e) {
      appLog.debug('MemoryAdvancedSettings: failed to load expansion state: $e');
    }
  }

  Future<void> _toggleAdvanced() async {
    final next = !_advancedExpanded;
    setState(() => _advancedExpanded = next);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kAdvancedExpandedKey, next);
    } catch (e) {
      appLog.debug('MemoryAdvancedSettings: failed to persist expansion state: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final memory = ref.watch(settingsProvider.select((s) => s.memory));
    final notifier = ref.read(settingsProvider.notifier);
    final l = AppLocalizations.of(context)!;

    return SettingsSection(
      title: l.memoryAdvancedSettings,
      children: [
        _AdvancedSettingsToggle(
          expanded: _advancedExpanded,
          onTap: _toggleAdvanced,
        ),
        if (_advancedExpanded)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IntSlider(
                label: 'Memory context budget',
                suffix: 'tokens',
                value: memory.contextBudget,
                min: 200,
                max: 4000,
                divisions: 38,
                onChanged: notifier.setMemoryContextBudget,
              ),
              SwitchListTile(
                title: const Text('Use LLM summarizer'),
                subtitle: const Text(
                  'Ask the configured AI to summarize fragments during dreaming. '
                  'Higher quality but slower; requires an AI provider.',
                ),
                value: memory.useLlmSummarizer,
                onChanged: notifier.setMemoryUseLlmSummarizer,
              ),
              SwitchListTile(
                title: const Text('Use LLM re-ranking'),
                subtitle: const Text(
                  'Re-rank recall hits with the LLM after FTS+Hebbian. Slower '
                  'first-token time; off by default.',
                ),
                value: memory.useLlmRerank,
                onChanged: notifier.setMemoryUseLlmRerank,
              ),
              const Divider(height: 1),
              const _SectionHeader(label: 'Thresholds'),
              _ThresholdSlider(
                label: 'Short → Mid threshold',
                value: memory.shortToMidThreshold,
                min: 0.1,
                max: 0.95,
                onChanged: notifier.setMemoryShortToMidThreshold,
              ),
              _ThresholdSlider(
                label: 'Mid → Long threshold',
                value: memory.midToLongThreshold,
                min: 0.05,
                max: 0.9,
                onChanged: notifier.setMemoryMidToLongThreshold,
              ),
              _IntSlider(
                label: 'Short-tier max age',
                suffix: 'days',
                value: memory.shortMaxAgeDays,
                min: 1,
                max: 30,
                onChanged: notifier.setMemoryShortMaxAgeDays,
              ),
              _IntSlider(
                label: 'Mid-tier max age',
                suffix: 'days',
                value: memory.midMaxAgeDays,
                min: 7,
                max: 180,
                onChanged: notifier.setMemoryMidMaxAgeDays,
              ),
              _IntSlider(
                label: 'Created recency half-life',
                suffix: 'days',
                value: memory.createdRecencyHalfLifeDays,
                min: 30,
                max: 730,
                divisions: 70,
                onChanged: notifier.setMemoryCreatedRecencyHalfLifeDays,
              ),
              _IntSlider(
                label: 'Last-access recency half-life',
                suffix: 'days',
                value: memory.accessRecencyHalfLifeDays,
                min: 1,
                max: 90,
                divisions: 89,
                onChanged: notifier.setMemoryAccessRecencyHalfLifeDays,
              ),
              const Divider(height: 1),
              const _SectionHeader(label: 'Hebbian connections'),
              _IntSlider(
                label: 'Co-access window',
                suffix: 'minutes',
                value: memory.hebbianCoAccessMinutes,
                min: 1,
                max: 60,
                onChanged: notifier.setMemoryHebbianCoAccessMinutes,
              ),
              _IntSlider(
                label: 'Edge decay constant',
                suffix: 'days',
                value: memory.hebbianDecayDays,
                min: 1,
                max: 365,
                onChanged: notifier.setMemoryHebbianDecayDays,
              ),
              _IntSlider(
                label: 'Export chat to Markdown every',
                suffix: memory.autoExportEveryNMessages == 0
                    ? 'disabled'
                    : 'messages',
                value: memory.autoExportEveryNMessages,
                min: 0,
                max: 64,
                divisions: 16,
                onChanged: notifier.setMemoryAutoExportEveryNMessages,
              ),
            ],
          ),
      ],
    );
  }
}

/// 高级参数区域的展开/折叠切换按钮。
class _AdvancedSettingsToggle extends StatelessWidget {
  final bool expanded;
  final VoidCallback onTap;
  const _AdvancedSettingsToggle({required this.expanded, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              Icons.tune,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              l.memoryAdvancedSettings,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              color: theme.colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ThresholdSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final Future<void> Function(double) onChanged;
  const _ThresholdSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      subtitle: Text(value.toStringAsFixed(2)),
      trailing: SizedBox(
        width: 200,
        // ExcludeSemantics：Slider 拖拽时每帧触发 AXTree 更新，包裹后
        // 不再贡献语义节点，subtitle Text 仍可朗读当前值。
        child: ExcludeSemantics(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: ((max - min) * 20).round(),
            label: value.toStringAsFixed(2),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

class _IntSlider extends StatelessWidget {
  final String label;
  final String suffix;
  final int value;
  final int min;
  final int max;
  final int? divisions;
  final Future<void> Function(int) onChanged;
  const _IntSlider({
    required this.label,
    required this.suffix,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      subtitle: Text('$value $suffix'),
      trailing: SizedBox(
        width: 200,
        child: ExcludeSemantics(
          child: Slider(
            value: value.toDouble().clamp(min.toDouble(), max.toDouble()),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: divisions ?? (max - min),
            label: '$value $suffix',
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
      ),
    );
  }
}
