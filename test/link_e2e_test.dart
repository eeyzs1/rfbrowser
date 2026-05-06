import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:rfbrowser/data/models/note.dart';
import 'package:rfbrowser/data/stores/index_store.dart';
import 'package:rfbrowser/core/link/link_extractor.dart';
import 'package:rfbrowser/core/link/link_resolver.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late ProviderContainer container;
  late Directory tempDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('rfbrowser_link_test_');
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Note makeNote(String id, String title, String content, String folder) {
    return Note(
      id: id,
      title: title,
      filePath: folder.isNotEmpty ? '$folder/$title.md' : '$title.md',
      content: content,
      created: DateTime.now(),
      modified: DateTime.now(),
    );
  }

  test('AC-IMP-9-1: wikilink creates backlink from target to source', () async {
    final indexStore = container.read(indexStoreProvider);

    final noteB = makeNote('b-id', 'TargetNote', 'Target content', '');
    final noteA = makeNote('a-id', 'SourceNote', '链接到[[TargetNote]]', '');

    await indexStore.indexNote(noteB);
    await indexStore.indexNote(noteA);

    final extractor = LinkExtractor();
    final links = extractor.extractLinks(noteA.content);
    expect(links.length, greaterThanOrEqualTo(1));
    expect(links.any((l) => l.target == 'TargetNote'), isTrue);

    final resolver = LinkResolver(tempDir.path);
    await resolver.rebuildTitleIndex([noteA, noteB]);
    final resolvedLinks = await resolver.resolveLinksForNote(noteA);
    expect(resolvedLinks.isNotEmpty, isTrue);

    for (final link in resolvedLinks) {
      await indexStore.indexLink(link);
    }

    final targetId = resolvedLinks.first.targetId;
    final backlinks = await indexStore.getBacklinks(targetId);
    expect(backlinks.isNotEmpty, isTrue);
    expect(backlinks.any((l) => l.sourceId == noteA.id), isTrue);
  });

  test('AC-IMP-9-2: bidirectional link resolution', () async {
    final indexStore = container.read(indexStoreProvider);

    final noteB = makeNote('bid-b', 'B', 'Content B', '');
    final noteA = makeNote('bid-a', 'A', 'See [[B]] for more', '');

    await indexStore.indexNote(noteB);
    await indexStore.indexNote(noteA);

    final resolver = LinkResolver(tempDir.path);
    await resolver.rebuildTitleIndex([noteA, noteB]);

    final aLinks = await resolver.resolveLinksForNote(noteA);
    for (final link in aLinks) {
      await indexStore.indexLink(link);
    }

    final targetId = aLinks.first.targetId;
    final bBacklinks = await indexStore.getBacklinks(targetId);
    expect(bBacklinks.length, greaterThanOrEqualTo(1),
        reason: 'B should have backlinks');
    expect(bBacklinks.any((l) => l.sourceId == noteA.id), isTrue);
  });

  test('AC-IMP-9-3: note count and link discovery work together', () async {
    final indexStore = container.read(indexStoreProvider);

    final noteX = makeNote('x-id', 'X', 'X content', '');
    final noteY = makeNote('y-id', 'Y', 'Reference [[X]] here', '');

    await indexStore.indexNote(noteX);
    await indexStore.indexNote(noteY);

    final resolver = LinkResolver(tempDir.path);
    await resolver.rebuildTitleIndex([noteX, noteY]);
    final resolvedLinks = await resolver.resolveLinksForNote(noteY);

    for (final link in resolvedLinks) {
      await indexStore.indexLink(link);
    }

    final targetId = resolvedLinks.first.targetId;
    final xBacklinks = await indexStore.getBacklinks(targetId);
    expect(xBacklinks, isNotEmpty);
    expect(xBacklinks.any((l) => l.sourceId == noteY.id), isTrue);

    expect(resolvedLinks.length, equals(1));
    expect(resolvedLinks.first.targetId, equals('X'));
  });
}
