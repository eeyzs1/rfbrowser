/// Centralized re-exports for notes / canvas / browser Riverpod providers.
///
/// Consumers can import this file instead of digging through individual
/// service files:
///
/// ```dart
/// import 'package:rfbrowser/providers/notes.dart';
/// ```
///
/// Providers included:
///   - [noteServiceProvider] (NoteNotifier / NoteState)
///   - [noteRepositoryProvider] (NoteRepository?)
///   - [canvasProvider] (CanvasNotifier / CanvasData)
///   - [browserProvider] (BrowserNotifier / BrowserState)
///   - [searchServiceProvider] (SearchNotifier / SearchState)
///   - [knowledgeProvider] (KnowledgeNotifier / KnowledgeState)
///   - [linkServiceProvider] (LinkNotifier / LinkState)
///   - [linkResolverProvider] (LinkResolver?)
///   - [quickMoveProvider] (QuickMoveNotifier / QuickMoveState)
///   - [quickMoveContextProvider] (QuickMoveContextNotifier / QuickMoveContext)
///   - [vaultProvider] (VaultNotifier / VaultState)
library;

export '../services/note_service.dart';
export '../data/repositories/note_repository.dart';
export '../services/canvas_service.dart';
export '../services/browser_service.dart';
export '../services/search_service.dart';
export '../services/knowledge_service.dart';
export '../services/link_service.dart';
export '../core/link/link_resolver.dart';
export '../services/quick_move_service.dart';
export '../data/stores/vault_store.dart';
