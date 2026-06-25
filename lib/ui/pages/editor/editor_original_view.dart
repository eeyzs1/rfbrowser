// ignore_for_file: unused_element, unused_element_parameter

part of '../editor_page.dart';

/// Mixin providing the "original page" view: renders the saved raw HTML,
/// falls back to a placeholder, and shows the screenshot dialog.
mixin _EditorOriginalViewMixin on _EditorViewStateBase {
  @override
  Widget _buildOriginalView(
    ThemeData theme,
    dynamic note,
    Color bgColor,
    AppLocalizations l,
  ) {
    final vault = ref.read(vaultProvider).currentVault;
    if (vault == null) {
      return Center(child: Text(l.noVaultConnected));
    }

    if (note.rawHtmlPath != null) {
      final htmlFile = File(p.join(vault.path, note.rawHtmlPath));
      return FutureBuilder<String>(
        future: htmlFile.exists().then(
          (exists) => exists ? htmlFile.readAsString() : '',
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final htmlContent = snapshot.data ?? '';
          if (htmlContent.isEmpty) {
            return _buildOriginalFallback(note, l, theme);
          }
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(bottom: BorderSide(color: theme.dividerColor)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: theme.hintColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l.originalPageViewHint,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.open_in_browser, size: 14),
                      label: Text(l.openInBrowser),
                      onPressed: () {
                        if (note.sourceUrl != null) {
                          launchUrl(Uri.parse(note.sourceUrl!));
                        }
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ExcludeSemantics(
                  child: InAppWebView(
                    initialData: InAppWebViewInitialData(data: htmlContent),
                    initialSettings: InAppWebViewSettings(
                      useHybridComposition: true,
                      supportZoom: true,
                      javaScriptEnabled: false,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    }

    if (note.sourceUrl != null) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignSpacing.md,
              vertical: DesignSpacing.xs + 2,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: theme.hintColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l.loadingOriginalPage,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ExcludeSemantics(
              child: InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(note.sourceUrl!)),
                initialSettings: InAppWebViewSettings(
                  useHybridComposition: true,
                  supportZoom: true,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return _buildOriginalFallback(note, l, theme);
  }

  Widget _buildOriginalFallback(
    dynamic note,
    AppLocalizations l,
    ThemeData theme,
  ) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.web_asset_off, size: 48, color: theme.hintColor),
          const SizedBox(height: 12),
          Text(l.noOriginalPage, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 8),
          if (note.sourceUrl != null)
            FilledButton.tonal(
              onPressed: () => launchUrl(Uri.parse(note.sourceUrl!)),
              child: Text(l.openInBrowser),
            ),
        ],
      ),
    );
  }

  @override
  void _showScreenshot(dynamic note) {
    final vault = ref.read(vaultProvider).currentVault;
    if (vault == null || note.screenshotPath == null) return;
    final l = AppLocalizations.of(context)!;
    final imgFile = File(p.join(vault.path, note.screenshotPath));
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(DesignSpacing.md),
              child: Row(
                children: [
                  Icon(
                    Icons.screenshot,
                    size: 18,
                    color: Theme.of(ctx).hintColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l.pageScreenshot,
                      style: Theme.of(ctx).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Flexible(
              child: FutureBuilder<bool>(
                future: imgFile.exists(),
                builder: (ctx, snapshot) {
                  if (snapshot.data != true) {
                    return Padding(
                      padding: const EdgeInsets.all(DesignSpacing.xl),
                      child: Text(
                        l.screenshotNotFound,
                        style: Theme.of(ctx).textTheme.bodyMedium,
                      ),
                    );
                  }
                  return InteractiveViewer(
                    child: Image.file(imgFile, fit: BoxFit.contain),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
