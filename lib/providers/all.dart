/// Master barrel for all centralized Riverpod providers.
///
/// Import this file to access every provider in the application:
///
/// ```dart
/// import 'package:rfbrowser/providers/all.dart';
/// ```
///
/// For finer-grained imports, prefer the category barrels:
///   - [ai.dart] — AI, agents, model discovery
///   - [memory.dart] — memory, dreaming, embeddings
///   - [notes.dart] — notes, canvas, browser, search, links, vault
///   - [sync.dart] — git / WebDAV sync
///   - [settings.dart] — app settings, shortcuts
///   - [infra.dart] — index store, plugins, webhook, performance, connectivity
library;

export 'ai.dart';
export 'memory.dart';
export 'notes.dart';
export 'sync.dart';
export 'settings.dart';
export 'infra.dart';
