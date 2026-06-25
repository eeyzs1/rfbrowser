/// Centralized re-exports for settings / config Riverpod providers.
///
/// Consumers can import this file instead of digging through individual
/// service files:
///
/// ```dart
/// import 'package:rfbrowser/providers/settings.dart';
/// ```
///
/// Providers included:
///   - [settingsProvider] (SettingsNotifier / AppSettings)
///   - [shortcutServiceProvider] (ShortcutService)
library;

export '../services/settings_service.dart';
export '../services/shortcut_service.dart';
