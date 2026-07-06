import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/stores/vault_store.dart';
import '../l10n/app_localizations.dart';
import 'browser_service.dart';
import 'knowledge_service.dart';

/// Encapsulates the multi-step vault lifecycle workflows that were
/// previously inlined in `MainLayout`.
///
/// Opening a vault is not a single call: it must open the vault, then load
/// notes and bookmarks, then notify dependent services. Centralising this
/// workflow removes business logic from the UI layer and makes it testable
/// in isolation.
class VaultWorkflowService {
  final Ref _ref;

  VaultWorkflowService(this._ref);

  /// Open [vaultPath] and initialise every dependent service that needs to
  /// react to a new vault (notes index, browser bookmarks, …).
  Future<void> openAndInitialize(String vaultPath) async {
    await _ref.read(vaultProvider.notifier).openVault(vaultPath);
    // Load notes and bookmarks in parallel — they are independent.
    await Future.wait([
      _ref.read(knowledgeProvider.notifier).loadAllNotes(),
      _ref.read(browserProvider.notifier).loadBookmarks(),
    ]);
  }

  /// Prompt the user to pick a vault directory (via the native file
  /// picker), then open and initialise it. Returns the chosen path, or
  /// `null` if the user cancelled.
  Future<String?> promptAndOpenVault(AppLocalizations l) async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: l.selectVaultLocation,
    );
    if (result == null) return null;
    await openAndInitialize(result);
    return result;
  }
}

final vaultWorkflowProvider = Provider<VaultWorkflowService>((ref) {
  return VaultWorkflowService(ref);
});
