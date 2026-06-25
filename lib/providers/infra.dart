/// Centralized re-exports for infrastructure Riverpod providers.
///
/// Consumers can import this file instead of digging through individual
/// service files:
///
/// ```dart
/// import 'package:rfbrowser/providers/infra.dart';
/// ```
///
/// Providers included:
///   - [indexStoreProvider] (IndexStore)
///   - [pluginHostProvider] (PluginHostNotifier / PluginState)
///   - [webhookServerProvider] (WebhookServerNotifier / WebhookServerState)
///   - [framePerformanceMonitorProvider] (FramePerformanceMonitor)
///   - [localServiceScannerProvider] (LocalServiceScanner)
///   - [detectedLocalServicesProvider] (`FutureProvider<List<LocalServiceInfo>>`)
///   - [connectivityProvider] (ConnectivityNotifier / ConnectivityState)
///   - [assemblerProvider] (Assembler)
library;

export '../data/stores/index_store.dart';
export '../plugins/host/plugin_host.dart';
export '../services/webhook_server.dart';
export '../performance/frame_performance_monitor.dart';
export '../services/local_service_scanner.dart';
export '../services/connectivity_service.dart';
export '../core/context/assembler.dart';
