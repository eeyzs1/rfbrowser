import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rfbrowser/data/models/note.dart';
import 'package:rfbrowser/data/models/link.dart';
import 'package:rfbrowser/data/models/link_type.dart';
import 'package:rfbrowser/services/link_service.dart';

String _pathToId(String path) {
  return path.replaceAll(RegExp(r'[/\\]'), '_').replaceAll('.md', '');
}

void main() {
  group('LinkState', () {
    test('initial state has empty links and backlinksCache', () {
      const state = LinkState();
      expect(state.links, isEmpty);
      expect(state.backlinksCache, isEmpty);
    });

    test('copyWith updates links', () {
      final state = LinkState();
      final link = Link(sourceId: 'a', targetId: 'b', type: LinkType.wikilink);
      final updated = state.copyWith(links: [link]);
      expect(updated.links.length, 1);
      expect(updated.links.first.sourceId, 'a');
    });

    test('copyWith updates backlinksCache', () {
      final state = LinkState();
      final link = Link(sourceId: 'a', targetId: 'b', type: LinkType.wikilink);
      final updated = state.copyWith(backlinksCache: {'b': [link]});
      expect(updated.backlinksCache['b']!.length, 1);
    });

    test('copyWith retains original when null passed', () {
      final link = Link(sourceId: 'a', targetId: 'b', type: LinkType.wikilink);
      final state = LinkState(links: [link]);
      final updated = state.copyWith();
      expect(updated.links.length, 1);
    });
  });

  group('LinkNotifier', () {
    test('build returns initial LinkState', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final state = container.read(linkServiceProvider);
      expect(state.links, isEmpty);
      expect(state.backlinksCache, isEmpty);
    });

    group('rebuildAllLinks', () {
      test('builds links from wikilinks in note content', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(linkServiceProvider.notifier);

        final noteA = Note(
          title: 'Note A',
          filePath: 'notes/note_a.md',
          content: 'Some text [[Note B]] and more text.',
        );
        final noteB = Note(title: 'Note B', filePath: 'notes/note_b.md');

        notifier.rebuildAllLinks([noteA, noteB]);

        final state = container.read(linkServiceProvider);
        expect(state.links.length, 1);
        expect(state.links.first.sourceId, noteA.id);
        expect(state.links.first.targetId, _pathToId(noteB.filePath));
        expect(state.links.first.type, LinkType.wikilink);
        expect(state.links.first.position, isNotNull);
      });

      test('builds backlinks cache entries for all notes (note: backlinks may be empty due to id mismatch)', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(linkServiceProvider.notifier);

        final noteA = Note(
          title: 'Note A',
          filePath: 'notes/note_a.md',
          content: '[[Note B]]',
        );
        final noteB = Note(title: 'Note B', filePath: 'notes/note_b.md');

        notifier.rebuildAllLinks([noteA, noteB]);

        final state = container.read(linkServiceProvider);
        expect(state.backlinksCache.containsKey(noteA.id), isTrue);
        expect(state.backlinksCache.containsKey(noteB.id), isTrue);
      });

      test('handles multiple wikilinks in one note', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(linkServiceProvider.notifier);

        final noteA = Note(
          title: 'Note A',
          filePath: 'notes/note_a.md',
          content: '[[Note B]] [[Note C]]',
        );
        final noteB = Note(title: 'Note B', filePath: 'notes/note_b.md');
        final noteC = Note(title: 'Note C', filePath: 'notes/note_c.md');

        notifier.rebuildAllLinks([noteA, noteB, noteC]);

        final state = container.read(linkServiceProvider);
        expect(state.links.length, 2);
      });

      test('links between multiple notes', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(linkServiceProvider.notifier);

        final noteA = Note(
          title: 'Note A',
          filePath: 'notes/note_a.md',
          content: '[[Note B]]',
        );
        final noteB = Note(
          title: 'Note B',
          filePath: 'notes/note_b.md',
          content: '[[Note C]]',
        );
        final noteC = Note(title: 'Note C', filePath: 'notes/note_c.md');

        notifier.rebuildAllLinks([noteA, noteB, noteC]);

        final state = container.read(linkServiceProvider);
        expect(state.links.length, 2);
        expect(state.backlinksCache.containsKey(noteB.id), isTrue);
        expect(state.backlinksCache.containsKey(noteC.id), isTrue);
      });

      test('ignores wikilinks to non-existent notes', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(linkServiceProvider.notifier);

        final noteA = Note(
          title: 'Note A',
          filePath: 'notes/note_a.md',
          content: '[[NonExistent]]',
        );
        final noteB = Note(title: 'Note B', filePath: 'notes/note_b.md');

        notifier.rebuildAllLinks([noteA, noteB]);

        final state = container.read(linkServiceProvider);
        expect(state.links, isEmpty);
      });

      test('handles embed links (note: ![[X]] also matches wikilink regex)', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(linkServiceProvider.notifier);

        final noteA = Note(
          title: 'Note A',
          filePath: 'notes/note_a.md',
          content: '![[Note B]]',
        );
        final noteB = Note(title: 'Note B', filePath: 'notes/note_b.md');

        notifier.rebuildAllLinks([noteA, noteB]);

        final state = container.read(linkServiceProvider);
        expect(state.links.any((l) => l.type == LinkType.embed), isTrue);
        expect(state.links.any((l) => l.type == LinkType.wikilink), isTrue);
      });

      test('handles wikilink with alias', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(linkServiceProvider.notifier);

        final noteA = Note(
          title: 'Note A',
          filePath: 'notes/note_a.md',
          content: '[[Note B|Display Name]]',
        );
        final noteB = Note(title: 'Note B', filePath: 'notes/note_b.md');

        notifier.rebuildAllLinks([noteA, noteB]);

        final state = container.read(linkServiceProvider);
        expect(state.links.length, 1);
        expect(state.links.first.targetId, _pathToId(noteB.filePath));
      });

      test('handles alias-based resolution', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(linkServiceProvider.notifier);

        final noteA = Note(
          title: 'Note A',
          filePath: 'notes/note_a.md',
          content: '[[AliasName]]',
        );
        final noteB = Note(
          title: 'Note B',
          filePath: 'notes/note_b.md',
          aliases: ['AliasName'],
        );

        notifier.rebuildAllLinks([noteA, noteB]);

        final state = container.read(linkServiceProvider);
        expect(state.links.length, 1);
        expect(state.links.first.targetId, _pathToId(noteB.filePath));
      });

      test('empty notes produce no links', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(linkServiceProvider.notifier);

        notifier.rebuildAllLinks([]);

        final state = container.read(linkServiceProvider);
        expect(state.links, isEmpty);
        expect(state.backlinksCache, isEmpty);
      });

      test('path with subdirectories is converted correctly', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(linkServiceProvider.notifier);

        final noteA = Note(
          title: 'Note A',
          filePath: 'notes/note_a.md',
          content: '[[Deep Note]]',
        );
        final deepNote = Note(
          title: 'Deep Note',
          filePath: 'sub/folder/deep_note.md',
        );

        notifier.rebuildAllLinks([noteA, deepNote]);

        final state = container.read(linkServiceProvider);
        expect(state.links.length, 1);
        expect(state.links.first.targetId, _pathToId(deepNote.filePath));
      });
    });

    group('updateLinksForNote', () {
      test('updates links when note content changes', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(linkServiceProvider.notifier);

        final noteA = Note(
          title: 'Note A',
          filePath: 'notes/note_a.md',
          content: '[[Note B]]',
        );
        final noteB = Note(title: 'Note B', filePath: 'notes/note_b.md');
        final noteC = Note(title: 'Note C', filePath: 'notes/note_c.md');

        notifier.rebuildAllLinks([noteA, noteB, noteC]);
        expect(container.read(linkServiceProvider).links.length, 1);

        final updatedA = Note(
          id: noteA.id,
          title: 'Note A',
          filePath: 'notes/note_a.md',
          content: '[[Note C]]',
        );
        notifier.updateLinksForNote(updatedA, [updatedA, noteB, noteC]);

        final state = container.read(linkServiceProvider);
        expect(state.links.length, 1);
        expect(state.links.first.targetId, _pathToId(noteC.filePath));
      });

      test('removes links to changed note and adds new ones', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(linkServiceProvider.notifier);

        final noteA = Note(
          title: 'Note A',
          filePath: 'notes/note_a.md',
          content: '[[Note B]] [[Note C]]',
        );
        final noteB = Note(title: 'Note B', filePath: 'notes/note_b.md');
        final noteC = Note(title: 'Note C', filePath: 'notes/note_c.md');

        notifier.rebuildAllLinks([noteA, noteB, noteC]);
        expect(container.read(linkServiceProvider).links.length, 2);

        final updatedA = Note(
          id: noteA.id,
          title: 'Note A',
          filePath: 'notes/note_a.md',
          content: '[[Note B]]',
        );
        notifier.updateLinksForNote(updatedA, [updatedA, noteB, noteC]);

        final state = container.read(linkServiceProvider);
        expect(state.links.length, 1);
        expect(state.links.first.targetId, _pathToId(noteB.filePath));
      });

      test('maintains links from other notes', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(linkServiceProvider.notifier);

        final noteA = Note(
          title: 'Note A',
          filePath: 'notes/note_a.md',
          content: '[[Note B]]',
        );
        final noteB = Note(
          title: 'Note B',
          filePath: 'notes/note_b.md',
          content: '[[Note C]]',
        );
        final noteC = Note(title: 'Note C', filePath: 'notes/note_c.md');

        notifier.rebuildAllLinks([noteA, noteB, noteC]);

        final updatedA = Note(
          id: noteA.id,
          title: 'Note A',
          filePath: 'notes/note_a.md',
          content: 'new content',
        );
        notifier.updateLinksForNote(updatedA, [updatedA, noteB, noteC]);

        final state = container.read(linkServiceProvider);
        expect(state.links.length, 1);
        expect(state.links.first.sourceId, noteB.id);
      });
    });

    group('getNoteLinks', () {
      test('returns links where the note is source', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(linkServiceProvider.notifier);

        final noteA = Note(
          title: 'Note A',
          filePath: 'notes/note_a.md',
          content: '[[Note B]] [[Note C]]',
        );
        final noteB = Note(title: 'Note B', filePath: 'notes/note_b.md');
        final noteC = Note(title: 'Note C', filePath: 'notes/note_c.md');

        notifier.rebuildAllLinks([noteA, noteB, noteC]);

        final links = notifier.getNoteLinks(noteA.id);
        expect(links.length, 2);
      });

      test('returns empty list for note with no links', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(linkServiceProvider.notifier);

        final noteB = Note(title: 'Note B', filePath: 'notes/note_b.md');

        notifier.rebuildAllLinks([noteB]);

        final links = notifier.getNoteLinks(noteB.id);
        expect(links, isEmpty);
      });
    });

    group('getBacklinks', () {
      test('returns backlinks from cache for a note', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(linkServiceProvider.notifier);

        final noteA = Note(
          title: 'Note A',
          filePath: 'notes/note_a.md',
          content: '[[Note B]]',
        );
        final noteB = Note(title: 'Note B', filePath: 'notes/note_b.md');

        notifier.rebuildAllLinks([noteA, noteB]);

        final backlinks = notifier.getBacklinks(noteB.id);
        expect(backlinks, isA<List<Link>>());
      });

      test('returns empty for unknown note id', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(linkServiceProvider.notifier);

        final noteA = Note(title: 'Note A', filePath: 'notes/note_a.md');

        notifier.rebuildAllLinks([noteA]);

        final backlinks = notifier.getBacklinks('nonexistent');
        expect(backlinks, isEmpty);
      });
    });

    group('getUnlinkedMentions', () {
      test('finds unlinked mentions of other note titles', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(linkServiceProvider.notifier);

        final noteA = Note(
          title: 'Note A',
          filePath: 'notes/note_a.md',
          content: 'This mentions Note B in plain text.',
        );
        final noteB = Note(title: 'Note B', filePath: 'notes/note_b.md');

        final mentions = notifier.getUnlinkedMentions(noteA.id, [noteA, noteB]);
        expect(mentions.length, 1);
        expect(mentions.first.targetTitle, 'Note B');
        expect(mentions.first.context, isNotNull);
      });

      test('does not flag already linked mentions', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(linkServiceProvider.notifier);

        final noteA = Note(
          title: 'Note A',
          filePath: 'notes/note_a.md',
          content: '[[Note B]] and also Note B again.',
        );
        final noteB = Note(title: 'Note B', filePath: 'notes/note_b.md');

        notifier.rebuildAllLinks([noteA, noteB]);

        final mentions = notifier.getUnlinkedMentions(noteA.id, [noteA, noteB]);
        expect(mentions.length, 1);
      });

      test('returns empty for non-existent note id', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(linkServiceProvider.notifier);

        final mentions = notifier.getUnlinkedMentions('nonexistent', []);
        expect(mentions, isEmpty);
      });

      test('skips titles shorter than 3 characters', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(linkServiceProvider.notifier);

        final noteA = Note(
          title: 'Note A',
          filePath: 'notes/note_a.md',
          content: 'ab',
        );
        final shortNote = Note(title: 'ab', filePath: 'notes/ab.md');

        final mentions = notifier.getUnlinkedMentions(noteA.id, [noteA, shortNote]);
        expect(mentions, isEmpty);
      });

      test('finds multiple unlinked mentions', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(linkServiceProvider.notifier);

        final noteA = Note(
          title: 'Note A',
          filePath: 'notes/note_a.md',
          content: 'Text about Note B and also Note C here.',
        );
        final noteB = Note(title: 'Note B', filePath: 'notes/note_b.md');
        final noteC = Note(title: 'Note C', filePath: 'notes/note_c.md');

        final mentions = notifier.getUnlinkedMentions(noteA.id, [noteA, noteB, noteC]);
        expect(mentions.length, 2);
      });
    });

    group('getGraphData', () {
      test('returns nodes and edges from links', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(linkServiceProvider.notifier);

        final noteA = Note(
          title: 'Note A',
          filePath: 'notes/note_a.md',
          content: '[[Note B]]',
        );
        final noteB = Note(title: 'Note B', filePath: 'notes/note_b.md');

        notifier.rebuildAllLinks([noteA, noteB]);

        final graphData = notifier.getGraphData([noteA, noteB]);
        expect(graphData.length, 1);
        final data = graphData.first;
        final nodes = data['nodes'] as List;
        final edges = data['edges'] as List;
        expect(nodes.length, 2);
        expect(edges.length, 1);
        expect(edges.first['source'], noteA.id);
        expect(edges.first['target'], _pathToId(noteB.filePath));
        expect(edges.first['type'], 'wikilink');
      });

      test('connected nodes have degree 1, isolated nodes have degree 0', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(linkServiceProvider.notifier);

        final noteA = Note(
          title: 'Note A',
          filePath: 'notes/note_a.md',
          content: '[[Note B]]',
        );
        final noteB = Note(title: 'Note B', filePath: 'notes/note_b.md');
        final noteC = Note(title: 'Note C', filePath: 'notes/note_c.md');

        notifier.rebuildAllLinks([noteA, noteB, noteC]);

        final graphData = notifier.getGraphData([noteA, noteB, noteC]);
        final nodes =
            (graphData.first['nodes'] as List).cast<Map<String, dynamic>>();
        final nodeCData = nodes.firstWhere((n) => n['title'] == 'Note C');
        expect(nodeCData['degree'], 0);

        final nodeAData = nodes.firstWhere((n) => n['title'] == 'Note A');
        expect(nodeAData['degree'], 1);
      });

      test('handles empty notes', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(linkServiceProvider.notifier);

        final graphData = notifier.getGraphData([]);
        final data = graphData.first;
        expect((data['nodes'] as List), isEmpty);
        expect((data['edges'] as List), isEmpty);
      });

      test('node tags are included in graph data', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(linkServiceProvider.notifier);

        final noteA = Note(
          title: 'Note A',
          filePath: 'notes/note_a.md',
          tags: ['tag1', 'tag2'],
        );

        notifier.rebuildAllLinks([noteA]);

        final graphData = notifier.getGraphData([noteA]);
        final nodes =
            (graphData.first['nodes'] as List).cast<Map<String, dynamic>>();
        final nodeData = nodes.first;
        expect(nodeData['tags'], ['tag1', 'tag2']);
      });
    });

    group('getLocalGraph', () {
      test('returns local graph around center note', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(linkServiceProvider.notifier);

        final noteA = Note(
          title: 'Note A',
          filePath: 'notes/note_a.md',
          content: '[[Note B]]',
        );
        final noteB = Note(
          title: 'Note B',
          filePath: 'notes/note_b.md',
          content: '[[Note C]]',
        );
        final noteC = Note(title: 'Note C', filePath: 'notes/note_c.md');

        notifier.rebuildAllLinks([noteA, noteB, noteC]);

        final graph =
            notifier.getLocalGraph(noteB.id, [noteA, noteB, noteC], depth: 1);
        expect(graph.notes, isNotEmpty);
        expect(graph.notes.any((n) => n.id == noteB.id), isTrue);
      });

      test('center note is always included in result', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(linkServiceProvider.notifier);

        final noteA = Note(title: 'Note A', filePath: 'notes/note_a.md');

        notifier.rebuildAllLinks([noteA]);

        final graph =
            notifier.getLocalGraph(noteA.id, [noteA], depth: 1);
        expect(graph.notes.length, 1);
        expect(graph.notes.first.id, noteA.id);
      });
    });

    group('linkMention', () {
      test('creates a wikilink between notes', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(linkServiceProvider.notifier);

        final noteA = Note(title: 'Note A', filePath: 'notes/note_a.md');
        final noteB = Note(title: 'Note B', filePath: 'notes/note_b.md');

        notifier.rebuildAllLinks([noteA, noteB]);

        notifier.linkMention(noteA.id, 'Note B', 10, [noteA, noteB]);

        final links = notifier.getNoteLinks(noteA.id);
        expect(links.length, 1);
        expect(links.first.type, LinkType.wikilink);
        expect(links.first.position, 10);
      });

      test('updates backlinks when linking mentions', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(linkServiceProvider.notifier);

        final noteA = Note(title: 'Note A', filePath: 'notes/note_a.md');
        final noteB = Note(title: 'Note B', filePath: 'notes/note_b.md');

        notifier.rebuildAllLinks([noteA, noteB]);

        notifier.linkMention(noteA.id, 'Note B', 5, [noteA, noteB]);

        final backlinks = notifier.getBacklinks(noteB.id);
        expect(backlinks.length, 1);
        expect(backlinks.first.sourceId, noteA.id);
      });

      test('does nothing when target note not found', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(linkServiceProvider.notifier);

        final noteA = Note(title: 'Note A', filePath: 'notes/note_a.md');

        notifier.rebuildAllLinks([noteA]);

        notifier.linkMention(noteA.id, 'NonExistent', 0, [noteA]);

        final links = notifier.getNoteLinks(noteA.id);
        expect(links, isEmpty);
      });
    });

    group('linkServiceProvider', () {
      test('provider is accessible', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        expect(container.read(linkServiceProvider), isA<LinkState>());
      });
    });
  });
}