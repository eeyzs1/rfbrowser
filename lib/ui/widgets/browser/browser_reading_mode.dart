import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../../data/models/browser_tab.dart';
import '../../theme/design_tokens.dart';
import '../../../l10n/app_localizations.dart';

class BrowserReadingMode extends StatefulWidget {
  final InAppWebViewController controller;
  final BrowserTab tab;
  final AppLocalizations l;
  final VoidCallback onExit;

  const BrowserReadingMode({
    super.key,
    required this.controller,
    required this.tab,
    required this.l,
    required this.onExit,
  });

  @override
  State<BrowserReadingMode> createState() => _BrowserReadingModeState();
}

class _BrowserReadingModeState extends State<BrowserReadingMode> {
  String _content = '';
  String _title = '';
  bool _isLoading = true;
  double _fontSize = 16.0;

  @override
  void initState() {
    super.initState();
    _extractContent();
  }

  Future<void> _extractContent() async {
    try {
      final titleResult = await widget.controller.evaluateJavascript(
        source: 'document.title',
      );
      final contentResult = await widget.controller.evaluateJavascript(
        source: '''
        (function() {
          var article = document.querySelector('article');
          if (article) return article.innerText;
          var main = document.querySelector('main') || document.querySelector('[role="main"]');
          if (main) return main.innerText;
          var content = document.querySelector('.content, .post-content, .article-content, .entry-content, #content, .post-body');
          if (content) return content.innerText;
          return document.body.innerText;
        })()
        ''',
      );
      if (mounted) {
        setState(() {
          _title = titleResult is String ? titleResult : widget.tab.title;
          _content = contentResult is String ? contentResult : '';
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = widget.l;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_content.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_outlined, size: 48, color: theme.hintColor),
            const SizedBox(height: 16),
            Text(l.noOtherTabs, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            FilledButton(onPressed: widget.onExit, child: Text(l.exitReadingMode)),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignSpacing.lg,
            vertical: DesignSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: theme.appBarTheme.backgroundColor,
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close_outlined, size: 18),
                onPressed: widget.onExit,
                tooltip: l.exitReadingMode,
              ),
              const SizedBox(width: DesignSpacing.sm),
              Expanded(
                child: Text(
                  l.readingMode,
                  style: theme.textTheme.labelMedium,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.text_decrease_outlined, size: 16),
                onPressed: () => setState(() {
                  _fontSize = (_fontSize - 2).clamp(12.0, 28.0);
                }),
                tooltip: l.readingModeFontDecrease,
              ),
              IconButton(
                icon: const Icon(Icons.text_increase_outlined, size: 16),
                onPressed: () => setState(() {
                  _fontSize = (_fontSize + 2).clamp(12.0, 28.0);
                }),
                tooltip: l.readingModeFontIncrease,
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignSpacing.xl,
              vertical: DesignSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_title.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: DesignSpacing.lg),
                    child: SelectableText(
                      _title,
                      style: theme.textTheme.headlineMedium,
                    ),
                  ),
                SelectableText(
                  _content,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontSize: _fontSize,
                    height: 1.8,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
