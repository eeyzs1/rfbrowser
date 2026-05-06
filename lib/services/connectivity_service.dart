import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'settings_service.dart';
import '../data/models/ai_provider.dart';

typedef SyncExecutor = Future<void> Function(List<String> filePaths);

class ConnectivityState {
  final bool isOnline;
  final List<String> syncQueue;
  final bool isSyncing;

  ConnectivityState({
    this.isOnline = true,
    this.syncQueue = const [],
    this.isSyncing = false,
  });

  ConnectivityState copyWith({
    bool? isOnline,
    List<String>? syncQueue,
    bool? isSyncing,
  }) =>
      ConnectivityState(
        isOnline: isOnline ?? this.isOnline,
        syncQueue: syncQueue ?? this.syncQueue,
        isSyncing: isSyncing ?? this.isSyncing,
      );
}

class ConnectivityNotifier extends Notifier<ConnectivityState> {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));
  Timer? _monitorTimer;
  SyncExecutor? _syncExecutor;

  @override
  ConnectivityState build() {
    ref.onDispose(() {
      _monitorTimer?.cancel();
    });
    return ConnectivityState();
  }

  void setSyncExecutor(SyncExecutor executor) {
    _syncExecutor = executor;
  }

  void startMonitoring({Duration interval = const Duration(seconds: 30)}) {
    _monitorTimer?.cancel();
    _monitorTimer = Timer.periodic(interval, (_) {
      checkConnectivity();
    });
  }

  void stopMonitoring() {
    _monitorTimer?.cancel();
    _monitorTimer = null;
  }

  Future<void> checkConnectivity() async {
    try {
      final result = await _testConnection();
      setOnline(result);
    } catch (_) {
      setOnline(false);
    }
  }

  Future<bool> _testConnection() async {
    try {
      final aiConfig = ref.read(aiConfigProvider);
      final providers = aiConfig.providers;
      if (providers.isEmpty) {
        try {
          await _dio.head('https://www.bing.com');
          return true;
        } catch (_) {
          return false;
        }
      }
      final activeProvider = providers.where((p) => p.isEnabled).firstOrNull;
      if (activeProvider == null) {
        try {
          await _dio.head('https://www.bing.com');
          return true;
        } catch (_) {
          return false;
        }
      }
      await _dio.head(activeProvider.baseUrl);
      return true;
    } catch (_) {
      return false;
    }
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
    state = state.copyWith(
      syncQueue: [...state.syncQueue, filePath],
    );
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

  AIProvider? getOfflineProvider() {
    final aiConfig = ref.read(aiConfigProvider);
    final providers = aiConfig.providers;
    try {
      return providers.firstWhere(
        (p) => p.protocol == ApiProtocol.ollama,
      );
    } catch (_) {
      return null;
    }
  }

  AIModel? getOfflineModel(AIProvider? provider) {
    if (provider == null) return null;
    final aiConfig = ref.read(aiConfigProvider);
    final models = aiConfig.modelsForProvider(provider.id);
    return models.isNotEmpty ? models.first : null;
  }
}

final connectivityProvider =
    NotifierProvider<ConnectivityNotifier, ConnectivityState>(
  ConnectivityNotifier.new,
);

class OfflineNoModelError implements Exception {
  final String message;

  OfflineNoModelError([this.message = 'No local model configured for offline use']);

  @override
  String toString() => 'OfflineNoModelError: $message';
}
