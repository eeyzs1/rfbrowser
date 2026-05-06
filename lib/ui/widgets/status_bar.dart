import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/browser_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/knowledge_service.dart';
import '../../data/stores/vault_store.dart';

class StatusBar extends ConsumerWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final browserState = ref.watch(browserProvider);
    final knowledgeState = ref.watch(knowledgeProvider);
    final vaultState = ref.watch(vaultProvider);
    final connectivityState = ref.watch(connectivityProvider);
    final hasVault = vaultState.currentVault != null;
    final isOffline = !connectivityState.isOnline;

    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.appBarTheme.backgroundColor,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Text(
            'RFBrowser v0.2.0',
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
          ),
          const SizedBox(width: 12),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOffline
                  ? const Color(0xFFEF4444)
                  : hasVault
                      ? const Color(0xFF2DD4BF)
                      : const Color(0xFFFBBF24),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isOffline ? 'Offline' : (hasVault ? 'Ready' : 'No Vault'),
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: isOffline ? const Color(0xFFEF4444) : null,
            ),
          ),
          if (isOffline && connectivityState.syncQueue.isNotEmpty) ...[
            const SizedBox(width: 12),
            Icon(Icons.cloud_upload, size: 10, color: theme.hintColor),
            const SizedBox(width: 4),
            Text(
              '${connectivityState.syncQueue.length} pending',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
            ),
          ],
          if (hasVault && !isOffline) ...[
            const SizedBox(width: 12),
            Icon(Icons.description, size: 10, color: theme.hintColor),
            const SizedBox(width: 4),
            Text(
              '${knowledgeState.notes.length} notes',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
            ),
          ],
          const Spacer(),
          Text(
            '${browserState.tabs.length} tabs',
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
          ),
          if (hasVault) ...[
            const SizedBox(width: 12),
            Icon(Icons.sync, size: 10, color: theme.hintColor),
            const SizedBox(width: 4),
            Text(
              'Git',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}
