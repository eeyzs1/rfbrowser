import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../plugins/host/plugin_host.dart';
import '../../plugins/marketplace_client.dart';

class PluginMarketplacePage extends ConsumerStatefulWidget {
  final String vaultPath;
  final PluginHostNotifier host;

  const PluginMarketplacePage({
    super.key,
    required this.vaultPath,
    required this.host,
  });

  @override
  ConsumerState<PluginMarketplacePage> createState() =>
      _PluginMarketplacePageState();
}

class _PluginMarketplacePageState extends ConsumerState<PluginMarketplacePage> {
  List<PluginMarketEntry> _entries = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadIndex();
  }

  Future<void> _loadIndex() async {
    setState(() { _loading = true; _error = null; });

    final installedIds = ref.read(pluginHostProvider).manifests.keys.toSet();

    final sampleEntries = [
      PluginMarketEntry(
        id: 'com.rfbrowser.dataview',
        name: 'Dataview',
        description: 'SQL-like queries over your notes.',
        author: 'RFBrowser Team',
        version: '1.0.0',
        repo: 'https://github.com/rfbrowser/plugin-dataview',
        tags: ['query', 'dataview'],
        downloads: 1024,
      ),
      PluginMarketEntry(
        id: 'com.rfbrowser.markdown-enhancer',
        name: 'Markdown Enhancer',
        description: 'Extended Markdown features: mermaid, footnotes, math.',
        author: 'Community',
        version: '0.2.0',
        repo: 'https://github.com/rfbrowser/plugin-markdown-enhancer',
        tags: ['editor', 'markdown'],
        downloads: 768,
      ),
      PluginMarketEntry(
        id: 'com.rfbrowser.canvas-tools',
        name: 'Canvas Tools',
        description: 'Extra tools for the infinite canvas: shapes, arrows, grouping.',
        author: 'Community',
        version: '0.1.5',
        repo: 'https://github.com/rfbrowser/plugin-canvas-tools',
        tags: ['canvas', 'tools'],
        downloads: 512,
      ),
    ];

    _entries = sampleEntries.where((e) => !installedIds.contains(e.id)).toList();

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l.extrazerodoMarketplaceTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_off, size: 48,
                          color: theme.colorScheme.error),
                      const SizedBox(height: 12),
                      Text(_error!, style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _loadIndex,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: Text(l.extrazerodoReloadPlugins),
                      ),
                    ],
                  ),
                )
              : _entries.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.store, size: 48,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.3)),
                          const SizedBox(height: 12),
                          Text(
                            l.extrazerodoMarketplaceDesc,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _entries.length,
                      itemBuilder: (context, index) =>
                          _EntryCard(entry: _entries[index]),
                    ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  final PluginMarketEntry entry;

  const _EntryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.extension, size: 18,
                      color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.name,
                          style: theme.textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      Text(
                        entry.author,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Text('v${entry.version}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.5),
                    )),
              ],
            ),
            const SizedBox(height: 8),
            Text(entry.description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                )),
            if (entry.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                children: entry.tags.map((t) => Chip(
                  label: Text(t, style: theme.textTheme.labelSmall),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                )).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}