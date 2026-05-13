import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/settings_service.dart';
import '../../../data/models/browser_tab.dart';
import '../../../l10n/app_localizations.dart';

class BrowserClipButtons extends ConsumerWidget {
  final BrowserTab activeTab;
  final AppLocalizations l;
  final bool isClipping;
  final VoidCallback onClipPage;
  final VoidCallback onClipSelection;

  const BrowserClipButtons({
    super.key,
    required this.activeTab,
    required this.l,
    required this.isClipping,
    required this.onClipPage,
    required this.onClipSelection,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hasPage =
        activeTab.url.isNotEmpty && activeTab.url != 'about:blank';
    final iconSize = ref.watch(settingsProvider).iconSize.toDouble();

    if (isClipping) {
      return SizedBox(
        width: iconSize + 16,
        height: iconSize + 16,
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: l.clipButtonLabel,
          button: true,
          enabled: hasPage,
          child: Tooltip(
            message: l.clipFullPage,
            child: IconButton(
              icon: Icon(
                Icons.content_copy_outlined,
                size: iconSize,
                color: hasPage ? theme.hintColor : theme.disabledColor,
              ),
              onPressed: hasPage ? onClipPage : null,
              padding: const EdgeInsets.all(4),
              constraints: BoxConstraints(minWidth: iconSize + 16, minHeight: iconSize + 16),
            ),
          ),
        ),
        Semantics(
          label: l.clipSelectionLabel,
          button: true,
          enabled: hasPage,
          child: Tooltip(
            message: l.clipSelection,
            child: IconButton(
              icon: Icon(
                Icons.text_fields_outlined,
                size: iconSize,
                color: hasPage ? theme.hintColor : theme.disabledColor,
              ),
              onPressed: hasPage ? onClipSelection : null,
              padding: const EdgeInsets.all(4),
              constraints: BoxConstraints(minWidth: iconSize + 16, minHeight: iconSize + 16),
            ),
          ),
        ),
      ],
    );
  }
}
