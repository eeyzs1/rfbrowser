import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/browser_service.dart';
import '../../../services/settings_service.dart';
import '../../../data/models/browser_tab.dart';
import '../../theme/design_tokens.dart';
import '../../../l10n/app_localizations.dart';

class BrowserUrlBar extends ConsumerStatefulWidget {
  final BrowserTab activeTab;
  final AppLocalizations l;
  final TextEditingController urlController;
  final FocusNode urlFocusNode;
  final void Function(String url) onNavigate;

  const BrowserUrlBar({
    super.key,
    required this.activeTab,
    required this.l,
    required this.urlController,
    required this.urlFocusNode,
    required this.onNavigate,
  });

  @override
  ConsumerState<BrowserUrlBar> createState() => _BrowserUrlBarState();
}

class _BrowserUrlBarState extends ConsumerState<BrowserUrlBar> {
  List<String> _suggestions = [];
  bool _showSuggestions = false;
  String? _validationError;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    widget.urlFocusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.urlFocusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (!widget.urlFocusNode.hasFocus) {
      setState(() => _showSuggestions = false);
    }
  }

  void _onChanged(String input) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _updateSuggestions(input);
    });
  }

  void _updateSuggestions(String input) {
    if (input.length < 2) {
      setState(() { _suggestions = []; _showSuggestions = false; });
      return;
    }
    final browserState = ref.read(browserProvider);
    final lower = input.toLowerCase();
    final matches = <String>[];
    for (final tab in browserState.tabs) {
      if (tab.url.toLowerCase().contains(lower) && tab.url != input) {
        matches.add(tab.url);
      }
    }
    for (final bm in browserState.bookmarks) {
      if ((bm.url.toLowerCase().contains(lower) ||
              bm.title.toLowerCase().contains(lower)) &&
          bm.url != input) {
        if (!matches.contains(bm.url)) matches.add(bm.url);
      }
    }
    setState(() {
      _suggestions = matches.take(5).toList();
      _showSuggestions =
          _suggestions.isNotEmpty && widget.urlFocusNode.hasFocus;
    });
  }

  bool _isValidUrl(String input) {
    if (input.startsWith('http://') || input.startsWith('https://')) return true;
    if (input.contains('.') && !input.contains(' ')) {
      final parts = input.split('.');
      return parts.length >= 2 && parts.last.length >= 2;
    }
    return false;
  }

  void _onSubmitted(String input) {
    final isValid = _isValidUrl(input);
    setState(() {
      _validationError = (!isValid && input.contains('.') && input.contains(' '))
          ? widget.l.invalidUrl
          : null;
    });
    widget.onNavigate(input);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = widget.l;
    final activeTab = widget.activeTab;
    final isSecure = activeTab.url.startsWith('https://');
    final isUrl = activeTab.url.isNotEmpty && activeTab.url != 'about:blank';
    final iconSize = ref.watch(settingsProvider).iconSize.toDouble();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: l.urlFieldLabel,
          textField: true,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(DesignRadius.md),
              border: Border.all(
                color: _validationError != null
                    ? DesignColors.semanticError
                    : widget.urlFocusNode.hasFocus
                        ? theme.colorScheme.primary.withValues(alpha: 0.5)
                        : Colors.transparent,
                width: 1,
              ),
              color: widget.urlFocusNode.hasFocus
                  ? theme.colorScheme.surface
                  : Colors.transparent,
            ),
            child: TextField(
              controller: widget.urlController,
              focusNode: widget.urlFocusNode,
              style: theme.textTheme.bodyMedium,
              decoration: InputDecoration(
                hintText: l.searchOrEnterUrl,
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.hintColor,
                ),
                prefixIcon: isUrl
                    ? Tooltip(
                        message: isSecure
                            ? l.secureConnection
                            : l.insecureConnection,
                        child: Icon(
                          isSecure
                              ? Icons.lock_outline
                              : Icons.warning_amber_outlined,
                          size: iconSize,
                          color: isSecure
                              ? DesignColors.semanticSuccess
                              : DesignColors.semanticWarning,
                        ),
                      )
                    : Icon(Icons.search_outlined, size: iconSize, color: theme.hintColor),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorText: _validationError,
                errorStyle: TextStyle(
                  color: DesignColors.semanticError,
                  fontSize: 10,
                  height: 0.8,
                ),
              ),
              onChanged: _onChanged,
              onSubmitted: _onSubmitted,
            ),
          ),
        ),
        if (_showSuggestions && _suggestions.isNotEmpty)
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(DesignRadius.md),
              ),
              border: Border.all(color: theme.dividerColor),
              boxShadow: [DesignShadow.sm],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _suggestions
                  .map((url) => InkWell(
                        onTap: () {
                          widget.urlController.text = url;
                          setState(() => _showSuggestions = false);
                          widget.onNavigate(url);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: DesignSpacing.md,
                            vertical: DesignSpacing.sm,
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.history_outlined,
                                  size: iconSize, color: theme.hintColor),
                              const SizedBox(width: DesignSpacing.sm),
                              Expanded(
                                child: Text(url,
                                    style: theme.textTheme.bodySmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
      ],
    );
  }
}
