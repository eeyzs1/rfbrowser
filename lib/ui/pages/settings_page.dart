import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/settings_service.dart';
import '../../services/ai_service.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildSection(theme, 'Appearance', [
            SwitchListTile(
              title: const Text('Dark Mode'),
              subtitle: const Text('Toggle dark/light theme'),
              value: settings.isDarkMode,
              onChanged: (_) => ref.read(settingsProvider.notifier).toggleDarkMode(),
            ),
            ListTile(
              title: const Text('Language'),
              subtitle: Text(settings.locale == 'zh' ? '中文' : 'English'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showLanguageDialog(context, ref, settings.locale),
            ),
          ]),
          const SizedBox(height: 24),
          _buildSection(theme, 'AI Models', [
            ListTile(
              title: const Text('OpenAI API Key'),
              subtitle: Text(
                ref.read(settingsProvider.notifier).apiKey != null ? '${ref.read(settingsProvider.notifier).apiKey!.substring(0, 8)}...' : 'Not set',
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
          const SizedBox(height: 24),
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
                  onChanged: (v) => ref.read(settingsProvider.notifier).setEditorFontSize(v),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 24),
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
          const SizedBox(height: 24),
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

  void _showLanguageDialog(BuildContext context, WidgetRef ref, String current) {
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
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
        children: [
          'gpt-4o',
          'gpt-4o-mini',
          'claude-sonnet-4-20250514',
          'deepseek-chat',
          'deepseek-reasoner',
          'llama3 (local)',
          'qwen2.5 (local)',
        ].map((model) => SimpleDialogOption(
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
        )).toList(),
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
            const Text('Make sure Ollama is running locally before using local models.'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
