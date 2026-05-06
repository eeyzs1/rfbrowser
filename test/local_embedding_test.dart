import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/services/embedding_service.dart';

void main() {
  late EmbeddingService embeddingService;

  setUp(() {
    embeddingService = EmbeddingService();
  });

  double cosineSimilarity(List<double> a, List<double> b) {
    var dot = 0.0;
    var normA = 0.0;
    var normB = 0.0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    if (normA == 0 || normB == 0) return 0.0;
    return dot / (sqrt(normA) * sqrt(normB));
  }

  test('AC-IMP-4-1: related terms have high similarity (>0.35)', () async {
    final emb1 = await embeddingService.embed('机器学习');
    final emb2 = await embeddingService.embed('深度学习');

    final sim = cosineSimilarity(emb1, emb2);
    expect(sim, greaterThan(0.35));
  });

  test('AC-IMP-4-2: related terms more similar than unrelated terms', () async {
    final ml = await embeddingService.embed('机器学习');
    final dl = await embeddingService.embed('深度学习');
    final qc = await embeddingService.embed('量子计算');

    final simRelated = cosineSimilarity(ml, dl);
    final simUnrelated = cosineSimilarity(ml, qc);

    expect(simRelated, greaterThan(simUnrelated));
  });

  test('AC-IMP-4-3: unrelated terms have low similarity (<0.3)', () async {
    final emb1 = await embeddingService.embed('机器学习');
    final emb2 = await embeddingService.embed('周末计划');

    final sim = cosineSimilarity(emb1, emb2);
    expect(sim, lessThan(0.3));
  });

  test('AC-IMP-4-4: same text produces identical embeddings (deterministic)', () async {
    final emb1 = await embeddingService.embed('机器学习 with some extra words');
    final emb2 = await embeddingService.embed('机器学习 with some extra words');

    final sim = cosineSimilarity(emb1, emb2);
    expect(sim, closeTo(1.0, 1e-15));
  });
}
