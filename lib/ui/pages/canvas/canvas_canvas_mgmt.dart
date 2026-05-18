part of '../canvas_page.dart';

mixin _CanvasCanvasMgmtMixin on _CanvasViewStateBase {
    @override
    Widget _buildCanvasSwitcher(ThemeData theme) {
      final notifier = ref.read(canvasProvider.notifier);
      final active = notifier.activeCanvasName;
      return GestureDetector(
        onTap: () => _showCanvasSelector(context, theme),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                active,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_down,
              size: 14,
              color: theme.colorScheme.primary,
            ),
          ],
        ),
      );
    }

    @override
    void _showCanvasSelector(BuildContext context, ThemeData theme) {
      final l = AppLocalizations.of(context)!;
      final notifier = ref.read(canvasProvider.notifier);
      final names = notifier.canvasNames;
      final active = notifier.activeCanvasName;
      showMenu<String>(
        context: context,
        position: const RelativeRect.fromLTRB(40, 36, 200, 400),
        items: [
          ...names.map(
            (name) => PopupMenuItem<String>(
              value: name,
              child: Row(
                children: [
                  Icon(
                    name == active
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: name == active
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (name != active)
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _showRenameDialog(name);
                      },
                      child: Icon(Icons.edit, size: 14, color: theme.hintColor),
                    ),
                  if (name != active && names.length > 1)
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _confirmDeleteCanvas(name);
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(
                          Icons.delete,
                          size: 14,
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem<String>(
            value: '__new__',
            child: Row(
              children: [
                Icon(Icons.add, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  l.newCanvas,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ).then((value) {
        if (value == null) return;
        if (value == '__new__') {
          _showCreateCanvasDialog();
        } else if (value != active) {
          ref.read(canvasProvider.notifier).switchCanvas(value);
          ref.read(canvasProvider.notifier).selectCard(null);
          _connectingFromCardId = null;
          WidgetsBinding.instance.addPostFrameCallback((_) => _centerOrFitView());
        }
      });
    }

    @override
    void _showCreateCanvasDialog() {
      final l = AppLocalizations.of(context)!;
      final controller = TextEditingController();
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l.newCanvas),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: l.canvasName),
            autofocus: true,
            onSubmitted: (name) async {
              if (await ref.read(canvasProvider.notifier).createCanvas(name)) {
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                await ref.read(canvasProvider.notifier).switchCanvas(name);
                if (mounted) {
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _centerOrFitView(),
                  );
                }
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (await ref.read(canvasProvider.notifier).createCanvas(name)) {
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  await ref.read(canvasProvider.notifier).switchCanvas(name);
                  if (mounted) {
                    ref.read(canvasProvider.notifier).selectCard(null);
                    _connectingFromCardId = null;
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => _centerOrFitView(),
                    );
                  }
                }
              },
              child: Text(l.create),
            ),
          ],
        ),
      );
    }

    @override
    void _showRenameDialog(String oldName) {
      final l = AppLocalizations.of(context)!;
      final controller = TextEditingController(text: oldName);
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l.renameCanvas),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: l.newName),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: () async {
                if (await ref
                    .read(canvasProvider.notifier)
                    .renameCanvas(oldName, controller.text.trim())) {
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                }
              },
              child: Text(l.rename),
            ),
          ],
        ),
      );
    }

    @override
    void _confirmDeleteCanvas(String name) {
      final l = AppLocalizations.of(context)!;
      final theme = Theme.of(context);
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l.deleteCanvas),
          content: Text(l.deleteCanvasConfirm(name)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
              ),
              onPressed: () async {
                await ref.read(canvasProvider.notifier).deleteCanvas(name);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (mounted) _centerOrFitView();
              },
              child: Text(l.delete),
            ),
          ],
        ),
      );
    }

    @override
    Widget _toolbarButton(
      ThemeData theme,
      IconData icon,
      String tooltip,
      VoidCallback onTap, {
      bool enabled = true,
      bool highlight = false,
    }) {
      return Tooltip(
        message: tooltip,
        preferBelow: false,
        child: IconButton(
          icon: Icon(
            icon,
            size: 14,
            color: highlight ? theme.colorScheme.primary : null,
          ),
          onPressed: enabled ? onTap : null,
          tooltip: '',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          color: enabled ? theme.hintColor : theme.disabledColor,
        ),
      );
    }


}
