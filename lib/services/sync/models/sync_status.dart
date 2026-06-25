/// Shared sync status enum used by both Git and WebDAV sync services.
///
/// Extracted from `git_sync_service.dart` and `webdav_sync_service.dart`
/// to eliminate the duplicate definition that previously existed in each.
enum SyncStatus { idle, syncing, success, conflict, error }
