import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/dreaming_service.dart';
import '../../../services/settings_service.dart';
import '../../widgets/settings_section.dart';

/// Settings panel for the memory subsystem (progressive forgetting,
/// Hebbian connections, and auto-export).
///
/// Values are written through to [settingsProvider], which the dreaming
/// service and Hebbian service read on every rebuild — so changes take
/// effect immediately.
class MemorySettingsSection extends ConsumerWidget {
  const MemorySettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return SettingsSection(
      title: 'Memory',
      children: [
        const _SectionHeader(label: 'Ambient context'),
        SwitchListTile(
          title: const Text('Inject request context into AI prompts'),
          subtitle: const Text(
            'Send the current vault, active note, selection, and scene as '
            'part of every AI request. Disable for fully isolated chats.',
          ),
          value: settings.memoryInjectContext,
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
          value: settings.memoryUseLastAccessForRecency,
          onChanged: notifier.setMemoryUseLastAccessForRecency,
        ),
        _ThresholdSlider(
          label: 'Short → Mid threshold',
          value: settings.memoryShortToMidThreshold,
          min: 0.1,
          max: 0.95,
          onChanged: notifier.setMemoryShortToMidThreshold,
        ),
        _ThresholdSlider(
          label: 'Mid → Long threshold',
          value: settings.memoryMidToLongThreshold,
          min: 0.05,
          max: 0.9,
          onChanged: notifier.setMemoryMidToLongThreshold,
        ),
        _IntSlider(
          label: 'Short-tier max age',
          suffix: 'days',
          value: settings.memoryShortMaxAgeDays,
          min: 1,
          max: 30,
          onChanged: notifier.setMemoryShortMaxAgeDays,
        ),
        _IntSlider(
          label: 'Mid-tier max age',
          suffix: 'days',
          value: settings.memoryMidMaxAgeDays,
          min: 7,
          max: 180,
          onChanged: notifier.setMemoryMidMaxAgeDays,
        ),
        _IntSlider(
          label: 'Created recency half-life',
          suffix: 'days',
          value: settings.memoryCreatedRecencyHalfLifeDays,
          min: 30,
          max: 730,
          divisions: 70,
          onChanged: notifier.setMemoryCreatedRecencyHalfLifeDays,
        ),
        _IntSlider(
          label: 'Last-access recency half-life',
          suffix: 'days',
          value: settings.memoryAccessRecencyHalfLifeDays,
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
          value: settings.memoryHebbianCoAccessMinutes,
          min: 1,
          max: 60,
          onChanged: notifier.setMemoryHebbianCoAccessMinutes,
        ),
        _IntSlider(
          label: 'Edge decay constant',
          suffix: 'days',
          value: settings.memoryHebbianDecayDays,
          min: 1,
          max: 365,
          onChanged: notifier.setMemoryHebbianDecayDays,
        ),
        const Divider(height: 1),
        const _SectionHeader(label: 'Auto-export'),
        SwitchListTile(
          title: const Text('Enable background dreaming'),
          subtitle: const Text(
            'If disabled, the engine stops scoring and tier-transitioning '
            'fragments until you re-enable it.',
          ),
          value: settings.memoryDreamingEnabled,
          onChanged: notifier.setMemoryDreamingEnabled,
        ),
        _IntSlider(
          label: 'Export chat to Markdown every',
          suffix: settings.memoryAutoExportEveryNMessages == 0
              ? 'disabled'
              : 'messages',
          value: settings.memoryAutoExportEveryNMessages,
          min: 0,
          max: 64,
          divisions: 16,
          onChanged: notifier.setMemoryAutoExportEveryNMessages,
        ),
        const _ManualExportTile(),
      ],
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
          color: theme.colorScheme.primary,
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
        child: Slider(
          value: value,
          min: min,
          max: max,
          divisions: ((max - min) * 20).round(),
          label: value.toStringAsFixed(2),
          onChanged: onChanged,
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
        child: Slider(
          value: value.toDouble().clamp(min.toDouble(), max.toDouble()),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: divisions ?? (max - min),
          label: '$value $suffix',
          onChanged: (v) => onChanged(v.round()),
        ),
      ),
    );
  }
}

class _ManualExportTile extends ConsumerWidget {
  const _ManualExportTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(Icons.file_download),
      title: const Text('Export current chat to Markdown'),
      subtitle: const Text(
        'Writes the active chat session to <vault>/.rfbrowser/chats/ '
        'with YAML frontmatter. The next dreaming cycle will then keep '
        'it in sync.',
      ),
      onTap: () => _run(context, ref),
    );
  }

  Future<void> _run(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final path = await ref.read(dreamingServiceProvider).exportCurrentSession();
      if (path == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('No active chat session to export')),
        );
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('Exported to $path'),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }
}
