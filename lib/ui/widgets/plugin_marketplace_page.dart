import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../plugins/host/plugin_host.dart';
import '../../plugins/marketplace_client.dart';
import '../../plugins/plugin_registry.dart';

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
  final _client = PluginMarketplaceClient();
  List<PluginMarketEntry> _entries = [];
  bool _loading = true;
  String? _error;
  final Set<String> _installing = {};
  final Map<String, String> _installErrors = {};

  @override
  void initState() {
    super.initState();
    _loadIndex();
  }

  Future<void> _loadIndex() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final allEntries = await _client.fetchIndex();
      if (!mounted) return;
      final hostState = ref.read(pluginHostProvider);
      final installedIds = hostState.manifests.keys.toSet();
      setState(() {
        _entries = allEntries
            .where((e) => !installedIds.contains(e.id))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _install(PluginMarketEntry entry) async {
    setState(() {
      _installing.add(entry.id);
      _installErrors.remove(entry.id);
    });

    try {
      final manifest = await PluginRegistry.installFromGit(
        entry.repo,
        widget.vaultPath,
      );
      if (!mounted) return;
      if (manifest != null) {
        await widget.host.registerManifestAndEnable(
          manifest,
          enabledByDefault: false,
        );
      }
      if (!mounted) return;

      setState(() {
        _installing.remove(entry.id);
        _entries.removeWhere((e) => e.id == entry.id);
      });

      final l = AppLocalizations.of(context)!;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.extrazerodoInstalled(manifest?.name ?? entry.name)),
            action: SnackBarAction(
              label: l.settings,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _installing.remove(entry.id);
        _installErrors[entry.id] = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.extrazerodoMarketplaceTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: l.extrazerodoReloadPlugins,
            onPressed: _loading ? null : _loadIndex,
          ),
        ],
      ),
      body: _buildBody(theme, l),
    );
  }

  Widget _buildBody(ThemeData theme, AppLocalizations l) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _error!,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loadIndex,
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(l.extrazerodoReloadPlugins),
            ),
          ],
        ),
      );
    }

    if (_entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.store,
              size: 48,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              l.extrazerodoMarketplaceDesc,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadIndex,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _entries.length,
        itemBuilder: (context, index) => _EntryCard(
          entry: _entries[index],
          isInstalling: _installing.contains(_entries[index].id),
          installError: _installErrors[_entries[index].id],
          onInstall: () => _install(_entries[index]),
          onDismissError: (id) => setState(() => _installErrors.remove(id)),
        ),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  final PluginMarketEntry entry;
  final bool isInstalling;
  final String? installError;
  final VoidCallback onInstall;
  final void Function(String id) onDismissError;

  const _EntryCard({
    required this.entry,
    required this.isInstalling,
    required this.installError,
    required this.onInstall,
    required this.onDismissError,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: installError != null
            ? BorderSide(color: theme.colorScheme.error, width: 1.5)
            : BorderSide.none,
      ),
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
                  child: Icon(
                    Icons.extension,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.name,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
                Text(
                  'v${entry.version}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              entry.description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            if (entry.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                children: entry.tags
                    .map(
                      (t) => Chip(
                        label: Text(t, style: theme.textTheme.labelSmall),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                    )
                    .toList(),
              ),
            ],
            if (installError != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        size: 14, color: theme.colorScheme.error),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        installError!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 14),
                      onPressed: () => onDismissError(entry.id),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: isInstalling ? null : onInstall,
                icon: isInstalling
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.download, size: 16),
                label: Text(isInstalling ? 'Installing...' : 'Install'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(100, 36),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}