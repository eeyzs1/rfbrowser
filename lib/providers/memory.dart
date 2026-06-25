/// Centralized re-exports for memory-related Riverpod providers.
///
/// Consumers can import this file instead of digging through individual
/// service files:
///
/// ```dart
/// import 'package:rfbrowser/providers/memory.dart';
/// ```
///
/// Providers included:
///   - [memoryServiceProvider] (MemoryService)
///   - [hebbianServiceProvider] (HebbianService)
///   - [activeMemoryBufferProvider] (ActiveMemoryBuffer)
///   - [memoryStatsProvider] (`FutureProvider<MemoryStats>`)
///   - [memoryInsightsProvider] (`FutureProvider<MemoryInsights>`)
///   - [dreamingServiceProvider] (DreamingService)
///   - [dreamingStatusProvider] (`StreamProvider<DreamingStatus>`)
///   - [embeddingServiceProvider] (EmbeddingService)
///   - [semanticSearchProvider] (SemanticSearch)
///   - [hybridSearchProvider] (HybridSearch)
library;

export '../services/memory_service.dart';
export '../services/hebbian_service.dart';
export '../services/active_memory_buffer.dart';
export '../services/memory_stats_service.dart';
export '../services/dreaming_service.dart';
export '../services/embedding_service.dart';
