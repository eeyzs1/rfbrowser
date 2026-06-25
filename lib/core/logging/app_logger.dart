import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Centralized application logger built on top of `package:logger`.
///
/// Replaces the scattered `debugPrint` / `print` calls across the codebase
/// with structured, level-aware logging. Use the global [appLog] instance:
///
/// ```dart
/// import '../core/logging/app_logger.dart';
///
/// appLog.debug('NoteService: loading notes');
/// appLog.warning('Canvas: unknown shape type', error: shape);
/// appLog.error('AI: streaming failed', error: e, stackTrace: st);
/// ```
///
/// In debug mode (the default for `flutter run`), all levels are printed
/// with colorized, emoji-prefixed output via [PrettyPrinter]. In release
/// mode the underlying [DevelopmentFilter] suppresses everything.
class AppLogger {
  AppLogger({Logger? logger})
    : _logger =
          logger ??
          Logger(
            printer: PrettyPrinter(
              methodCount: 0,
              errorMethodCount: 8,
              lineLength: 100,
              colors: true,
              printEmojis: true,
              dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
            ),
          );

  final Logger _logger;

  /// Debug-level message. Use for high-volume diagnostic output.
  void debug(String message, {Object? error, StackTrace? stackTrace}) {
    _safeLog(() => _logger.d(message, error: error, stackTrace: stackTrace),
        message, error);
  }

  /// Informational message. Use for noteworthy but non-error events.
  void info(String message, {Object? error, StackTrace? stackTrace}) {
    _safeLog(() => _logger.i(message, error: error, stackTrace: stackTrace),
        message, error);
  }

  /// Warning message. Use for recoverable degradations.
  void warning(String message, {Object? error, StackTrace? stackTrace}) {
    _safeLog(() => _logger.w(message, error: error, stackTrace: stackTrace),
        message, error);
  }

  /// Error message. Use for failures that should be visible to developers.
  void error(String message, {Object? error, StackTrace? stackTrace}) {
    _safeLog(() => _logger.e(message, error: error, stackTrace: stackTrace),
        message, error);
  }

  /// Fatal message. Use for unrecoverable failures.
  void fatal(String message, {Object? error, StackTrace? stackTrace}) {
    _safeLog(() => _logger.f(message, error: error, stackTrace: stackTrace),
        message, error);
  }

  /// Wraps a logger call in try/catch so that a formatting error inside
  /// PrettyPrinter (e.g. when processing an unusual error object or stack
  /// trace) never crashes the app. Falls back to debugPrint.
  void _safeLog(
    void Function() logCall,
    String message,
    Object? error,
  ) {
    try {
      logCall();
    } catch (e) {
      debugPrint('AppLogger: internal error while logging: $e');
      debugPrint('AppLogger: original message: $message');
      if (error != null) {
        debugPrint('AppLogger: original error: $error');
      }
    }
  }

  /// Adjusts the minimum visible log level at runtime.
  set level(Level level) => Logger.level = level;
}

/// Global logger instance. Import `app_logger.dart` and call
/// `appLog.debug(...)`, `appLog.error(...)`, etc.
final AppLogger appLog = AppLogger();

/// Convenience function for call sites that previously used `debugPrint`.
///
/// Prefer calling [AppLogger.debug] directly via [appLog]; this helper exists
/// only to ease incremental migration of legacy `debugPrint(msg)` calls.
void logDebug(String message, {Object? error, StackTrace? stackTrace}) {
  appLog.debug(message, error: error, stackTrace: stackTrace);
}
