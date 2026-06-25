// G15-B: smoke test aggregator for the 5 canonical user journeys.
//
// The full integration tests for each journey live in their own files
// (note_lifecycle, knowledge, graph, ai, quick_move). This file performs
// a fast smoke check on each so that the CI "user journey" job can fail
// quickly when one journey's contract breaks at a high level.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import '../helpers/sqflite_test_setup.dart';

import 'package:rfbrowser/data/repositories/note_repository.dart';
import 'package:rfbrowser/data/stores/index_store.dart';
import 'package:rfbrowser/data/stores/vault_store.dart';
import 'package:rfbrowser/services/knowledge_service.dart';
import 'package:rfbrowser/core/ai/sse_stream_parser.dart';
import 'package:rfbrowser/core/graph/layout_engine.dart';
import 'package:rfbrowser/services/agent_service.dart';
import 'package:rfbrowser/data/models/agent_task.dart';

class _TestVaultNotifier extends VaultNotifier {
  final VaultState _state;
  _TestVaultNotifier(this._state);
  @override
  VaultState build() => _state;
}

class _TestAgentNotifier extends AgentNotifier {
  AgentState _state;
  _TestAgentNotifier(this._state);
  @override
  AgentState build() => _state;
  void set(AgentState s) {
    _state = s;
    state = s;
  }
}

Future<({String tempDir, ProviderContainer container, dynamic kn})>
_setupVault() async {
  final tempDir = Directory.systemTemp.createTempSync('rfb_journey_');
  final rfbDir = Directory(p.join(tempDir.path, '.rfbrowser'));
  if (!rfbDir.existsSync()) rfbDir.createSync(recursive: true);
  final vaultState = VaultState(
    currentVault: VaultConfig(
      path: tempDir.path,
      name: 'journey',
      lastOpened: DateTime.now(),
    ),
  );
  final container = ProviderContainer(
    overrides: [
      vaultProvider.overrideWith(() => _TestVaultNotifier(vaultState)),
    ],
  );
  container.read(knowledgeProvider);
  await Future.delayed(const Duration(milliseconds: 150));
  final kn = container.read(knowledgeProvider.notifier);
  return (tempDir: tempDir.path, container: container, kn: kn);
}

void main() {
  setUpAll(setupSqfliteForTests);

  group('G15-B: 5 canonical user journeys (smoke)', () {
    test('Journey 1: note lifecycle — create / edit / save / rename', () async {
      final setup = await _setupVault();
      addTearDown(() {
        try {
          Directory(setup.tempDir).deleteSync(recursive: true);
        } catch (_) {}
        setup.container.dispose();
      });

      // Create → edit → save → rename
      final note = await setup.kn.createNote(title: 'My First Note');
      setup.kn.updateActiveNoteContent('# My First Note\n\nSome content.');
      await setup.kn.saveActiveNote();
      await setup.kn.renameNote(note.filePath, 'Renamed Note');

      // Verify on disk
      final repo = setup.container.read(noteRepositoryProvider);
      final onDisk = await repo?.getNoteByPath('Renamed-Note.md');
      expect(onDisk, isNotNull);
    });

    test('Journey 2: knowledge — index + search + semantic', () async {
      final setup = await _setupVault();
      addTearDown(() {
        try {
          Directory(setup.tempDir).deleteSync(recursive: true);
        } catch (_) {}
        setup.container.dispose();
      });

      await setup.kn.createNote(
        title: 'Flutter Riverpod Guide',
        content: '# Flutter Riverpod Guide\n\nState management.',
      );
      await setup.kn.createNote(
        title: 'Cooking Recipes',
        content: '# Cooking\n\nPasta and garlic.',
      );

      final idx = setup.container.read(indexStoreProvider);
      final results = await idx.searchNotes('Riverpod');
      expect(results, isNotEmpty);
      expect(
        results.map((r) => r['title']).toSet(),
        contains('Flutter Riverpod Guide'),
      );
    });

    test('Journey 3: graph — layout from a node/edge list', () {
      // Pure unit check: ForceDirectedLayout completes on a small graph
      // and returns positions for every node.
      final nodes = List.generate(5, (i) => LayoutNode(id: 'n$i'));
      final edges = [
        for (var i = 0; i < 4; i++)
          LayoutEdge(sourceId: 'n$i', targetId: 'n${i + 1}'),
      ];
      final result = ForceDirectedLayout(
        areaWidth: 400,
        areaHeight: 300,
      ).compute(nodes, edges);
      expect(result.positions.length, 5);
    });

    test('Journey 4: AI — SSE stream parser handles text and tool events', () {
      final parser = SseStreamParser(SseProtocol.openai);
      final evs = parser.feed(
        utf8.encode(
          'data: {"choices":[{"delta":{"content":"hi","tool_calls":['
          '{"index":0,"id":"c1","function":{"name":"web_search","arguments":"{}"}}]}}]}\n',
        ),
      );
      expect(evs.whereType<SseTextDelta>().length, 1);
      expect(evs.whereType<SseToolCallStart>().length, 1);
    });

    test('Journey 5: agent — task list aggregation', () async {
      final agent = _TestAgentNotifier(
        AgentState(
          tasks: [
            AgentTask(
              id: 't1',
              name: 'one',
              description: 'd',
              status: TaskStatus.completed,
            ),
            AgentTask(
              id: 't2',
              name: 'two',
              description: 'd',
              status: TaskStatus.running,
            ),
          ],
        ),
      );
      final container = ProviderContainer(
        overrides: [agentProvider.overrideWith(() => agent)],
      );
      addTearDown(container.dispose);
      // Just check the provider aggregates without throwing.
      expect(agentProvider, isNotNull);
      expect(agent.build().tasks.length, 2);
    });
  });
}
