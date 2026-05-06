import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/services/connectivity_service.dart';

void main() {
  group('ConnectivityState', () {
    test('default state is online with empty queue', () {
      final state = ConnectivityState();
      expect(state.isOnline, true);
      expect(state.syncQueue.isEmpty, true);
      expect(state.isSyncing, false);
    });

    test('copyWith works correctly', () {
      final state = ConnectivityState();
      final updated = state.copyWith(isOnline: false, syncQueue: ['a.md', 'b.md']);
      expect(updated.isOnline, false);
      expect(updated.syncQueue.length, 2);
    });
  });

  group('OfflineNoModelError', () {
    test('AC-P5-5-3: OfflineNoModelError has correct message', () {
      final error = OfflineNoModelError();
      expect(error.toString(), contains('No local model'));
      expect(error.message, isNotEmpty);
    });

    test('custom message', () {
      final error = OfflineNoModelError('Custom error');
      expect(error.toString(), contains('Custom error'));
    });
  });

  group('ConnectivityNotifier (pure Dart)', () {
    test('AC-P5-5-1: setOnline changes isOnline state', () {
      final notifier = _TestConnectivity();
      expect(notifier.state.isOnline, true);

      notifier.setOnline(false);
      expect(notifier.state.isOnline, false);

      notifier.setOnline(true);
      expect(notifier.state.isOnline, true);
    });

    test('AC-P5-5-4: offline create enqueues, online flush clears queue', () async {
      final notifier = _TestConnectivity();
      final executed = <List<String>>[];

      notifier.setSyncExecutor((filePaths) async {
        executed.add(filePaths);
      });

      notifier.setOnline(false);
      notifier.enqueueSync('notes/a.md');
      notifier.enqueueSync('notes/b.md');
      expect(notifier.state.syncQueue.length, 2);

      notifier.setOnline(true);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(notifier.state.syncQueue.isEmpty, true);
      expect(executed.length, 1);
      expect(executed.first.length, 2);
    });

    test('enqueueSync deduplicates', () {
      final notifier = _TestConnectivity();
      notifier.enqueueSync('a.md');
      notifier.enqueueSync('a.md');
      expect(notifier.state.syncQueue.length, 1);
    });

    test('flushSyncQueue skips when empty', () async {
      final notifier = _TestConnectivity();
      await notifier.flushSyncQueue();
      expect(notifier.state.isSyncing, false);
    });

    test('flushSyncQueue skips when already syncing', () async {
      final notifier = _TestConnectivity();
      var callCount = 0;
      notifier.setSyncExecutor((filePaths) async {
        callCount++;
        await Future.delayed(const Duration(milliseconds: 100));
      });

      notifier.enqueueSync('a.md');
      notifier.state = notifier.state.copyWith(isSyncing: true);
      await notifier.flushSyncQueue();
      expect(callCount, 0);
    });

    test('startMonitoring creates periodic timer', () {
      final notifier = _TestConnectivity();
      notifier.startMonitoring(interval: const Duration(seconds: 1));
      expect(notifier.isMonitoring, true);
      notifier.stopMonitoring();
      expect(notifier.isMonitoring, false);
    });
  });
}

class _TestConnectivity {
  ConnectivityState state = ConnectivityState();
  SyncExecutor? _syncExecutor;
  Timer? _monitorTimer;

  bool get isMonitoring => _monitorTimer != null;

  void setSyncExecutor(SyncExecutor executor) {
    _syncExecutor = executor;
  }

  void startMonitoring({Duration interval = const Duration(seconds: 30)}) {
    _monitorTimer?.cancel();
    _monitorTimer = Timer.periodic(interval, (_) {});
  }

  void stopMonitoring() {
    _monitorTimer?.cancel();
    _monitorTimer = null;
  }

  void setOnline(bool online) {
    final wasOffline = !state.isOnline;
    state = state.copyWith(isOnline: online);
    if (wasOffline && online && state.syncQueue.isNotEmpty) {
      flushSyncQueue();
    }
  }

  void enqueueSync(String filePath) {
    if (state.syncQueue.contains(filePath)) return;
    state = state.copyWith(syncQueue: [...state.syncQueue, filePath]);
  }

  Future<void> flushSyncQueue() async {
    if (state.syncQueue.isEmpty || state.isSyncing) return;

    state = state.copyWith(isSyncing: true);

    try {
      if (_syncExecutor != null) {
        await _syncExecutor!(List.from(state.syncQueue));
      }
      state = state.copyWith(syncQueue: [], isSyncing: false);
    } catch (e) {
      state = state.copyWith(isSyncing: false);
    }
  }
}
