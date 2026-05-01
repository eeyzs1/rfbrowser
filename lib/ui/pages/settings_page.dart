import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/settings_service.dart';
import '../../services/ai_service.dart';

class _PresetTheme {
  final String id;
  final String label;
  final Color color;
  final IconData icon;
  const _PresetTheme(this.id, this.label, this.color, this.icon);
}

const _presets = [
  _PresetTheme('sky', 'Sky', Color(0xFF0EA5E9), Icons.cloud),
  _PresetTheme('violet', 'Violet', Color(0xFF8B5CF6), Icons.auto_awesome),
  _PresetTheme('rose', 'Rose', Color(0xFFF43F5E), Icons.favorite),
  _PresetTheme('emerald', 'Emerald', Color(0xFF10B981), Icons.eco),
  _PresetTheme('amber', 'Amber', Color(0xFFF59E0B), Icons.wb_sunny),
];

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSection(theme, 'Theme', [
            SwitchListTile(
              title: const Text('Dark Mode'),
              subtitle: const Text('Toggle dark/light theme'),
              value: settings.isDarkMode,
              onChanged: (_) =>
                  ref.read(settingsProvider.notifier).toggleDarkMode(),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'Accent Color',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _buildPresetGrid(context, ref, settings),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: OutlinedButton.icon(
                onPressed: () async {
                  final color = await _showColorPicker(
                    context,
                    settings.accentColor,
                  );
                  if (color != null) {
                    ref.read(settingsProvider.notifier).setAccentColor(color);
                  }
                },
                icon: const Icon(Icons.palette, size: 16),
                label: const Text('Custom Color'),
              ),
            ),
            const SizedBox(height: 4),
          ]),
          const SizedBox(height: 20),
          _buildSection(theme, 'Components', [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Button Shape',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: _buildButtonStyleSelector(context, ref, settings),
            ),
            if (settings.buttonStyle == AppButtonStyle.rounded) ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Text(
                      'Corner Radius',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${settings.borderRadius.toInt()}px',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Slider(
                  value: settings.borderRadius,
                  min: 2,
                  max: 20,
                  divisions: 9,
                  label: '${settings.borderRadius.toInt()}px',
                  onChanged: (v) =>
                      ref.read(settingsProvider.notifier).setBorderRadius(v),
                ),
              ),
            ],
            ListTile(
              title: const Text('Density'),
              subtitle: Text(_densityLabel(settings.density)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showDensityDialog(context, ref, settings.density),
            ),
            ListTile(
              title: const Text('Icon Size'),
              subtitle: Text(_iconSizeLabel(settings.iconSize)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showIconSizeDialog(context, ref, settings.iconSize),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: _buildPreviewButton(theme, settings),
            ),
          ]),
          const SizedBox(height: 20),
          _buildSection(theme, 'Language', [
            ListTile(
              title: const Text('Language'),
              subtitle: Text(settings.locale == 'zh' ? '中文' : 'English'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showLanguageDialog(context, ref, settings.locale),
            ),
          ]),
          const SizedBox(height: 20),
          _buildSection(theme, 'AI Models', [
            ListTile(
              title: const Text('OpenAI API Key'),
              subtitle: Text(
                ref.read(settingsProvider.notifier).apiKey != null
                    ? '${ref.read(settingsProvider.notifier).apiKey!.substring(0, 8)}...'
                    : 'Not set',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showApiKeyDialog(context, ref, 'OpenAI'),
            ),
            ListTile(
              title: const Text('Active Model'),
              subtitle: Text(settings.activeModel),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showModelDialog(context, ref, settings.activeModel),
            ),
            ListTile(
              title: const Text('Local Model (Ollama)'),
              subtitle: const Text('Configure local model endpoint'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showOllamaDialog(context, ref),
            ),
          ]),
          const SizedBox(height: 20),
          _buildSection(theme, 'Editor', [
            ListTile(
              title: const Text('Font Size'),
              subtitle: Text('${settings.editorFontSize.toInt()}px'),
              trailing: SizedBox(
                width: 200,
                child: Slider(
                  value: settings.editorFontSize,
                  min: 10,
                  max: 24,
                  divisions: 14,
                  label: '${settings.editorFontSize.toInt()}px',
                  onChanged: (v) =>
                      ref.read(settingsProvider.notifier).setEditorFontSize(v),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 20),
          _buildSection(theme, 'Sync', [
            ListTile(
              title: const Text('Git Sync'),
              subtitle: const Text('Configure Git remote for vault sync'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showGitConfigDialog(context, ref),
            ),
            ListTile(
              title: const Text('WebDAV Sync'),
              subtitle: const Text('Configure WebDAV server for vault sync'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showWebdavConfigDialog(context, ref),
            ),
          ]),
          const SizedBox(height: 20),
          _buildSection(theme, 'About', [
            ListTile(
              title: const Text('RFBrowser'),
              subtitle: const Text('v0.2.0 - AI-Powered Knowledge Browser'),
            ),
            ListTile(
              title: const Text('License'),
              subtitle: const Text('MIT License'),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildPresetGrid(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _presets.map((preset) {
        final isSelected = settings.themePreset == preset.id;
        return GestureDetector(
          onTap: () =>
              ref.read(settingsProvider.notifier).setThemePreset(preset.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: preset.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(color: preset.color, width: 2)
                  : Border.all(color: Colors.transparent, width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(preset.icon, size: 18, color: preset.color),
                const SizedBox(height: 4),
                Text(
                  preset.label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                    color: isSelected
                        ? preset.color
                        : Theme.of(context).hintColor,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<Color?> _showColorPicker(BuildContext context, Color current) async {
    Color selected = current;
    return showDialog<Color>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Custom Accent Color'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                height: 80,
                decoration: BoxDecoration(
                  color: selected,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    [
                      Colors.red,
                      Colors.pink,
                      Colors.purple,
                      Colors.deepPurple,
                      Colors.indigo,
                      Colors.blue,
                      Colors.lightBlue,
                      Colors.cyan,
                      Colors.teal,
                      Colors.green,
                      Colors.lightGreen,
                      Colors.lime,
                      Colors.yellow,
                      Colors.amber,
                      Colors.orange,
                      Colors.deepOrange,
                      Colors.brown,
                    ].map((color) {
                      final isSelected =
                          selected.toARGB32() == color.toARGB32();
                      return GestureDetector(
                        onTap: () => setState(() => selected = color),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: Colors.white, width: 2)
                                : null,
                            boxShadow: [
                              BoxShadow(
                                color: color.withValues(alpha: 0.4),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  size: 14,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      );
                    }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, selected),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(ThemeData theme, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 16),
          child: Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          child: Column(children: children),
        ),
      ],
    );
  }

  void _showLanguageDialog(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Select Language'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              ref.read(settingsProvider.notifier).setLocale('en');
              Navigator.pop(ctx);
            },
            child: Row(
              children: [
                if (current == 'en') const Icon(Icons.check, size: 16),
                const SizedBox(width: 8),
                const Text('English'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              ref.read(settingsProvider.notifier).setLocale('zh');
              Navigator.pop(ctx);
            },
            child: Row(
              children: [
                if (current == 'zh') const Icon(Icons.check, size: 16),
                const SizedBox(width: 8),
                const Text('中文'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showApiKeyDialog(BuildContext context, WidgetRef ref, String provider) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$provider API Key'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(hintText: 'sk-...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(settingsProvider.notifier).setApiKey(controller.text);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showModelDialog(BuildContext context, WidgetRef ref, String current) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Select Model'),
        children:
            [
                  'gpt-4o',
                  'gpt-4o-mini',
                  'claude-sonnet-4-20250514',
                  'deepseek-chat',
                  'deepseek-reasoner',
                  'llama3 (local)',
                  'qwen2.5 (local)',
                ]
                .map(
                  (model) => SimpleDialogOption(
                    onPressed: () {
                      ref.read(settingsProvider.notifier).setActiveModel(model);
                      ref.read(aiProvider.notifier).setActiveModel(model);
                      Navigator.pop(ctx);
                    },
                    child: Row(
                      children: [
                        if (current == model) const Icon(Icons.check, size: 16),
                        const SizedBox(width: 8),
                        Text(model),
                      ],
                    ),
                  ),
                )
                .toList(),
      ),
    );
  }

  void _showOllamaDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: 'http://localhost:11434');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ollama Configuration'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Ollama Endpoint',
                hintText: 'http://localhost:11434',
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Make sure Ollama is running locally before using local models.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showGitConfigDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Git Sync Configuration'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Remote URL',
                hintText: 'https://github.com/user/vault.git',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showWebdavConfigDialog(BuildContext context, WidgetRef ref) {
    final urlController = TextEditingController();
    final userController = TextEditingController();
    final passController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('WebDAV Configuration'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'Server URL',
                hintText: 'https://dav.example.com/',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: userController,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: passController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildButtonStyleSelector(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    final theme = Theme.of(context);
    return Row(
      children: AppButtonStyle.values.map((style) {
        final isSelected = settings.buttonStyle == style;
        final label = switch (style) {
          AppButtonStyle.rounded => 'Rounded',
          AppButtonStyle.sharp => 'Sharp',
          AppButtonStyle.pill => 'Pill',
        };
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: GestureDetector(
              onTap: () =>
                  ref.read(settingsProvider.notifier).setButtonStyle(style),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: isSelected
                      ? Border.all(color: theme.colorScheme.primary, width: 1.5)
                      : Border.all(color: theme.dividerColor, width: 1),
                ),
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.hintColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPreviewButton(ThemeData theme, AppSettings settings) {
    final br = settings.effectiveBorderRadius;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(br),
      ),
      child: Column(
        children: [
          Text(
            'Preview',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () {},
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(br),
                    ),
                  ),
                  child: const Text('Filled'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(br),
                    ),
                  ),
                  child: const Text('Outlined'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _densityLabel(ComponentDensity d) => switch (d) {
    ComponentDensity.compact => 'Compact',
    ComponentDensity.comfortable => 'Comfortable',
    ComponentDensity.spacious => 'Spacious',
  };

  String _iconSizeLabel(IconSize s) => switch (s) {
    IconSize.small => 'Small (16px)',
    IconSize.medium => 'Medium (18px)',
    IconSize.large => 'Large (22px)',
  };

  void _showDensityDialog(
    BuildContext context,
    WidgetRef ref,
    ComponentDensity current,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Component Density'),
        children: ComponentDensity.values.map((d) {
          return SimpleDialogOption(
            onPressed: () {
              ref.read(settingsProvider.notifier).setDensity(d);
              Navigator.pop(ctx);
            },
            child: Row(
              children: [
                if (current == d) const Icon(Icons.check, size: 16),
                const SizedBox(width: 8),
                Text(_densityLabel(d)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showIconSizeDialog(
    BuildContext context,
    WidgetRef ref,
    IconSize current,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Icon Size'),
        children: IconSize.values.map((s) {
          return SimpleDialogOption(
            onPressed: () {
              ref.read(settingsProvider.notifier).setIconSize(s);
              Navigator.pop(ctx);
            },
            child: Row(
              children: [
                if (current == s) const Icon(Icons.check, size: 16),
                const SizedBox(width: 8),
                Text(_iconSizeLabel(s)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
