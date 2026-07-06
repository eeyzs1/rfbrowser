import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/settings_service.dart';
import '../../widgets/settings_section.dart';

/// 生成参数设置 section。
///
/// 分聊天/Agent/Dreaming 三场景,每场景独立配置 temperature 和 max_tokens。
/// 修复此前主聊天不传采样参数、Anthropic 硬编码 max_tokens=4096、
/// Dreaming 硬编码 temperature=0.3/max_tokens=1024 的不一致问题。
///
/// Slider 拖拽时用 *Live setter 即时更新 state(不写盘),拖拽结束 onChangeEnd
/// 时才持久化,避免每帧 I/O。Slider 包裹 ExcludeSemantics 防止 AXTree 帧风暴。
class SamplingSettingsSection extends ConsumerWidget {
  const SamplingSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sampling = ref.watch(settingsProvider.select((s) => s.sampling));
    final notifier = ref.read(settingsProvider.notifier);
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return SettingsSection(
      title: l.samplingSettings,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            l.samplingSettingsHint,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
        ),
        const Divider(height: 1),

        // ── Chat scene ──────────────────────────────────────────────────
        _SceneHeader(label: l.samplingChat),
        _TemperatureSlider(
          label: l.samplingTemperature,
          hint: l.samplingChatTempHint,
          value: sampling.chatTemperature,
          onChanged: notifier.setSamplingChatTemperatureLive,
          onChangeEnd: notifier.setSamplingChatTemperature,
        ),
        _MaxTokensTile(
          label: l.samplingMaxTokens,
          value: sampling.chatMaxTokens,
          unsetLabel: l.samplingMaxTokensUnset,
          onChanged: notifier.setSamplingChatMaxTokens,
        ),
        const Divider(height: 1),

        // ── Agent scene ─────────────────────────────────────────────────
        _SceneHeader(label: l.samplingAgent),
        _TemperatureSlider(
          label: l.samplingTemperature,
          hint: l.samplingAgentTempHint,
          value: sampling.agentTemperature,
          onChanged: notifier.setSamplingAgentTemperatureLive,
          onChangeEnd: notifier.setSamplingAgentTemperature,
        ),
        _MaxTokensTile(
          label: l.samplingMaxTokens,
          value: sampling.agentMaxTokens,
          onChanged: (v) {
            if (v != null) notifier.setSamplingAgentMaxTokens(v);
          },
        ),
        const Divider(height: 1),

        // ── Dreaming scene ──────────────────────────────────────────────
        _SceneHeader(label: l.samplingDreaming),
        _TemperatureSlider(
          label: l.samplingTemperature,
          hint: l.samplingDreamingTempHint,
          value: sampling.dreamingTemperature,
          onChanged: notifier.setSamplingDreamingTemperatureLive,
          onChangeEnd: notifier.setSamplingDreamingTemperature,
        ),
        _MaxTokensTile(
          label: l.samplingMaxTokens,
          value: sampling.dreamingMaxTokens,
          onChanged: (v) {
            if (v != null) notifier.setSamplingDreamingMaxTokens(v);
          },
        ),
        const Divider(height: 1),

        // ── Agent execution limits ──────────────────────────────────────
        _SceneHeader(label: l.samplingAgentExecution),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            l.samplingAgentExecutionHint,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
        ),
        _IntSliderTile(
          label: l.samplingMaxToolLoops,
          hint: l.samplingMaxToolLoopsHint,
          value: sampling.maxToolLoops,
          min: 1,
          max: 20,
          onChanged: notifier.setSamplingMaxToolLoops,
        ),
        _IntSliderTile(
          label: l.samplingMaxReactIterations,
          hint: l.samplingMaxReactIterationsHint,
          value: sampling.maxReactIterations,
          min: 1,
          max: 50,
          onChanged: notifier.setSamplingMaxReactIterations,
        ),
      ],
    );
  }
}

class _SceneHeader extends StatelessWidget {
  final String label;
  const _SceneHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

/// Temperature slider. Uses *Live setter on onChanged for instant feedback,
/// persists on onChangeEnd. Wrapped in ExcludeSemantics to avoid AXTree
/// frame storms during drag.
class _TemperatureSlider extends StatelessWidget {
  final String label;
  final String hint;
  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  const _TemperatureSlider({
    required this.label,
    required this.hint,
    required this.value,
    required this.onChanged,
    required this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      subtitle: Text(
        '${value.toStringAsFixed(2)} · $hint',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: SizedBox(
        width: 200,
        child: ExcludeSemantics(
          child: Slider(
            value: value,
            min: 0.0,
            max: 2.0,
            divisions: 20,
            label: value.toStringAsFixed(2),
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ),
      ),
    );
  }
}

/// Max tokens tile. Shows current value or "not set" for chat scene.
/// Uses a simple trailing text + edit dialog for input (avoids Slider's
/// limited range problem — context windows can be 4k to 200k+).
class _MaxTokensTile extends StatelessWidget {
  final String label;
  final int? value;
  final String? unsetLabel;
  final ValueChanged<int?> onChanged;

  const _MaxTokensTile({
    required this.label,
    required this.value,
    required this.onChanged,
    this.unsetLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayValue = value != null ? '$value' : (unsetLabel ?? '—');

    return ListTile(
      title: Text(label),
      subtitle: Text(
        displayValue,
        style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
      ),
      trailing: const Icon(Icons.edit, size: 16),
      onTap: () => _showEditDialog(context),
    );
  }

  void _showEditDialog(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: value?.toString() ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: unsetLabel ?? 'e.g. 4096'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
          if (unsetLabel != null)
            TextButton(
              onPressed: () {
                onChanged(null);
                Navigator.pop(ctx);
              },
              child: Text(l.clear),
            ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) {
                onChanged(null);
              } else {
                final parsed = int.tryParse(text);
                if (parsed != null && parsed > 0) {
                  onChanged(parsed);
                }
              }
              Navigator.pop(ctx);
            },
            child: Text(l.ok),
          ),
        ],
      ),
    );
  }
}

/// Integer slider tile for bounded integer parameters (e.g. loop limits).
/// Shows current value as subtitle, slider as trailing.
/// Wrapped in ExcludeSemantics to avoid AXTree frame storms during drag.
class _IntSliderTile extends StatelessWidget {
  final String label;
  final String hint;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _IntSliderTile({
    required this.label,
    required this.hint,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      subtitle: Text(
        '$value · $hint',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: SizedBox(
        width: 200,
        child: ExcludeSemantics(
          child: Slider(
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            label: '$value',
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
      ),
    );
  }
}
