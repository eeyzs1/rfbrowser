import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/browser_tab.dart';
import '../../../services/settings_service.dart';
import '../../theme/design_tokens.dart';
import '../../../l10n/app_localizations.dart';

class BrowserNavigationBar extends ConsumerWidget {
  final BrowserTab activeTab;
  final AppLocalizations l;
  final bool canGoBack;
  final bool canGoForward;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onRefresh;
  final VoidCallback onToggleReadingMode;

  const BrowserNavigationBar({
    super.key,
    required this.activeTab,
    required this.l,
    required this.canGoBack,
    required this.canGoForward,
    required this.onBack,
    required this.onForward,
    required this.onRefresh,
    required this.onToggleReadingMode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final iconSize = ref.watch(settingsProvider).iconSize.toDouble();
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignSpacing.sm,
        vertical: DesignSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: theme.appBarTheme.backgroundColor,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          _NavButton(
            icon: Icons.arrow_back_outlined,
            tooltip: l.navBack,
            iconSize: iconSize,
            onPressed: canGoBack ? onBack : null,
          ),
          _NavButton(
            icon: Icons.arrow_forward_outlined,
            tooltip: l.navForward,
            iconSize: iconSize,
            onPressed: canGoForward ? onForward : null,
          ),
          _NavButton(
            icon: Icons.refresh_outlined,
            tooltip: l.refresh,
            iconSize: iconSize,
            onPressed: onRefresh,
          ),
          const SizedBox(width: DesignSpacing.sm),
          const Expanded(child: SizedBox.shrink()),
          const SizedBox(width: DesignSpacing.sm),
          _NavButton(
            icon: Icons.menu_book_outlined,
            tooltip: l.readingMode,
            iconSize: iconSize,
            onPressed: onToggleReadingMode,
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final double iconSize;
  final VoidCallback? onPressed;

  const _NavButton({
    required this.icon,
    required this.tooltip,
    required this.iconSize,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onPressed != null;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: Tooltip(
          message: tooltip,
          child: Semantics(
            button: true,
            enabled: enabled,
            label: tooltip,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                icon,
                size: iconSize,
                color: enabled ? theme.iconTheme.color : theme.disabledColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
