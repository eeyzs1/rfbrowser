/// Centralized re-exports for AI-related Riverpod providers.
///
/// Consumers can import this file instead of digging through individual
/// service files:
///
/// ```dart
/// import 'package:rfbrowser/providers/ai.dart';
/// ```
///
/// Providers included:
///   - [aiProvider] (AINotifier / AIState)
///   - [aiConfigProvider] (AIConfigNotifier / AIConfigState)
///   - [requestContextProvider] (RequestContextNotifier / RequestContext)
///   - [modelDiscoveryProvider] (ModelDiscovery)
///   - [chatHistoryExporterProvider] (ChatHistoryExporter)
///   - [agentProvider] (AgentNotifier / AgentState)
///   - [agentChatBridgeProvider] (AgentChatBridge)
///   - [agentMonitorProvider] (AgentMonitorNotifier / AgentMonitorSnapshot)
library;

export '../services/ai_service.dart';
export '../services/ai_config_service.dart';
export '../core/ai/request_context.dart';
export '../core/domain/model_discovery.dart';
export '../services/chat_history_exporter.dart';
export '../services/agent_service.dart';
export '../services/agent_chat_bridge.dart';
export '../agents/monitor/agent_monitor_notifier.dart';
