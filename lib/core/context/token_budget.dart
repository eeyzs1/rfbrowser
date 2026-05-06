import '../../data/models/context_assembly.dart';

class TokenBudget {
  final int maxTokens;
  final int charsPerToken;

  TokenBudget({this.maxTokens = 4096, this.charsPerToken = 4});

  int estimateTokens(String text) {
    return (text.length / charsPerToken).ceil();
  }

  int estimateItemTokens(ContextItem item) {
    return estimateTokens(item.content);
  }

  TrimResult trim(List<ContextItem> items) {
    final result = <ContextItem>[];
    var remainingTokens = maxTokens;
    var truncated = false;

    for (final item in items) {
      final itemTokens = estimateItemTokens(item);
      if (item.content.isEmpty) {
        if (item.metadata['error'] != null) {
          result.add(item);
        }
        continue;
      }

      if (remainingTokens >= itemTokens) {
        result.add(item);
        remainingTokens -= itemTokens;
      } else if (remainingTokens > 100) {
        final maxChars = (remainingTokens * charsPerToken * 0.9).floor();
        result.add(
          ContextItem(
            type: item.type,
            id: item.id,
            content: '${item.content.substring(0, maxChars.clamp(0, item.content.length))}\n...(truncated)',
            summary: item.summary,
            metadata: {...item.metadata, 'truncated': true},
          ),
        );
        remainingTokens = 0;
        truncated = true;
      } else {
        truncated = true;
      }
    }

    return TrimResult(items: result, truncated: truncated);
  }
}

class TrimResult {
  final List<ContextItem> items;
  final bool truncated;

  TrimResult({required this.items, required this.truncated});
}
