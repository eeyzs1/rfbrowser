part of 'plugin_settings_section.dart';

class _PluginCard extends ConsumerStatefulWidget {
  final String pluginId;
  final PluginManifest manifest;
  final bool isRunning;
  final bool isEnabled;
  final bool isBuiltin;
  final List<PluginCommand> commands;
  final bool hasError;

  const _PluginCard({
    required this.pluginId,
    required this.manifest,
    required this.isRunning,
    required this.isEnabled,
    required this.isBuiltin,
    required this.commands,
    required this.hasError,
  });

  @override
  ConsumerState<_PluginCard> createState() => _PluginCardState();
}

class _PluginCardState extends ConsumerState<_PluginCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    final host = ref.read(pluginHostProvider.notifier);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: widget.hasError
            ? BorderSide(color: theme.colorScheme.error, width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildPluginIcon(theme),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.manifest.name,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'v${widget.manifest.version}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                            if (widget.isBuiltin) ...[
                              const SizedBox(width: 6),
                              _buildBadge(l.extrazerodoBuiltin, theme, false),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.manifest.description.isNotEmpty
                              ? widget.manifest.description
                              : widget.manifest.id,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Switch(
                    value: widget.isRunning,
                    onChanged: (value) async {
                      final plugin = PluginRegistry.findById(widget.pluginId);
                      await host.setPluginEnabled(
                        widget.pluginId,
                        value,
                        onEnable: (m, h) {
                          plugin?.onEnable(h);
                        },
                        onDisable: (m, h) {
                          plugin?.onDisable(h);
                        },
                      );
                    },
                  ),
                ],
              ),
              if (widget.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 14,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          l.extrazerodoErrorOccurred,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_expanded) ...[
                const Divider(height: 20),
                _buildDetailSection(theme, l),
              ],
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 16,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPluginIcon(ThemeData theme) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: widget.isRunning
            ? theme.colorScheme.primary.withValues(alpha: 0.12)
            : theme.colorScheme.onSurface.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.extension,
        size: 18,
        color: widget.isRunning
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurface.withValues(alpha: 0.4),
      ),
    );
  }

  Widget _buildDetailSection(ThemeData theme, AppLocalizations l) {
    final perms = widget.manifest.permissions;
    final skills = PluginRegistry.getAllPluginSkills()
        .where((s) => s.pluginId == widget.pluginId)
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.manifest.author.isNotEmpty) ...[
            _detailRow(l.extrazerodoAuthor, widget.manifest.author, theme),
            const SizedBox(height: 4),
          ],
          if (perms.isNotEmpty) ...[
            Text(
              l.extrazerodoPermissions,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: perms.map((p) => _permissionChip(p, theme)).toList(),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            l.extrazerodoCommandsN(widget.commands.length),
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          ...widget.commands.map(
            (cmd) => Padding(
              padding: const EdgeInsets.only(left: 8, top: 2),
              child: Text(
                '• ${cmd.label}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
          if (skills.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              l.extrazerodoSkillsN(skills.length),
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            ...skills.map(
              (s) => Padding(
                padding: const EdgeInsets.only(left: 8, top: 2),
                child: Text(
                  '• ${s.name}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 50,
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
      ],
    );
  }

  Widget _permissionChip(Permission perm, ThemeData theme) {
    final color = _permColor(perm);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        perm.displayName,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Color _permColor(Permission perm) {
    switch (perm) {
      case Permission.knowledgeRead:
        return const Color(0xFF0EA5E9);
      case Permission.knowledgeWrite:
        return const Color(0xFFF59E0B);
      case Permission.browserRead:
        return const Color(0xFF8B5CF6);
      case Permission.browserWrite:
        return const Color(0xFFF43F5E);
      case Permission.aiChat:
        return const Color(0xFF10B981);
      case Permission.uiCommand:
        return const Color(0xFF6366F1);
      case Permission.uiPanel:
        return const Color(0xFFEC4899);
    }
  }

  Widget _buildBadge(String text, ThemeData theme, bool warning) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: warning
            ? Colors.orange.withValues(alpha: 0.12)
            : theme.colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: warning ? Colors.orange : theme.colorScheme.primary,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

extension _PermissionDisplay on Permission {
  String get displayName {
    switch (this) {
      case Permission.knowledgeRead:
        return 'knowledge.read';
      case Permission.knowledgeWrite:
        return 'knowledge.write';
      case Permission.browserRead:
        return 'browser.read';
      case Permission.browserWrite:
        return 'browser.write';
      case Permission.aiChat:
        return 'ai.chat';
      case Permission.uiCommand:
        return 'ui.command';
      case Permission.uiPanel:
        return 'ui.panel';
    }
  }
}
