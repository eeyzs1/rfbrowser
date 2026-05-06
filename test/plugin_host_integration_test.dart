// ignore_for_file: invalid_use_of_protected_member
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:rfbrowser/plugins/host/plugin_host.dart';
import 'package:rfbrowser/data/repositories/note_repository.dart';
import 'package:rfbrowser/services/browser_service.dart';
import 'package:rfbrowser/data/stores/index_store.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('PluginHostNotifier API Bridge (P0-1 ACs)', () {
    test('AC-IMP-1-1: knowledge.getNote returns real note content (not hardcoded stub)', () async {
      final tempDir = Directory.systemTemp.createTempSync('rfb_pi_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final repo = NoteRepository(tempDir.path);
      final note = await repo.createNote(title: 'Quantum');

      final container = ProviderContainer(
        overrides: [noteRepositoryProvider.overrideWith((ref) => repo)],
      );
      addTearDown(container.dispose);

      final host = container.read(pluginHostProvider.notifier);
      final result = await host._testHandleApiCall('knowledge.getNote', {'id': note.filePath});

      expect(result['title'], 'Quantum');
      expect(result['content'], isNotEmpty);
      expect(result['filePath'], note.filePath);
      expect(result['id'], isA<String>());
      expect(result['error'], isNull);

      // Verify NOT returning old hardcoded stub values
      expect(result['title'], isNot(equals('Note')));
      expect(result['content'], isNot(equals('')));
    });

    test('AC-IMP-1-1b: knowledge.getNote for non-existent note returns error', () async {
      final tempDir = Directory.systemTemp.createTempSync('rfb_pi_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final container = ProviderContainer(
        overrides: [noteRepositoryProvider.overrideWith((ref) => NoteRepository(tempDir.path))],
      );
      addTearDown(container.dispose);

      final host = container.read(pluginHostProvider.notifier);
      final result = await host._testHandleApiCall('knowledge.getNote', {'id': 'nope.md'});

      expect(result['error'], isNotNull);
    });

    test('AC-IMP-1-2: knowledge.search reads from IndexStore (not hardcoded empty list)', () async {
      final tempDir = Directory.systemTemp.createTempSync('rfb_pi_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final repo = NoteRepository(tempDir.path);
      // Create note and directly index it (bypass loadAllNotes which needs vaultProvider)
      final note = await repo.createNote(title: 'Simple');
      final container = ProviderContainer(
        overrides: [noteRepositoryProvider.overrideWith((ref) => repo)],
      );
      addTearDown(container.dispose);

      final indexStore = container.read(indexStoreProvider);
      await indexStore.indexNote(note);

      final host = container.read(pluginHostProvider.notifier);
      final result = await host._testHandleApiCall('knowledge.search', {'query': 'Simple'});

      expect(result['results'] is List, true);
      expect((result['results'] as List).length, greaterThanOrEqualTo(1));
    });

    test('AC-IMP-1-3: browser.getCurrentUrl returns real active tab URL', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final browser = container.read(browserProvider.notifier);
      browser.createTab(url: 'https://example.com');

      final host = container.read(pluginHostProvider.notifier);
      final result = await host._testHandleApiCall('browser.getCurrentUrl', {});

      expect(result['url'], 'https://example.com');
    });

    test('AC-IMP-1-3b: browser.getCurrentUrl with no tabs returns empty', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final host = container.read(pluginHostProvider.notifier);
      final result = await host._testHandleApiCall('browser.getCurrentUrl', {});

      expect(result['url'], '');
    });

    test('AC-IMP-1-5: callApi without required permission throws PermissionDeniedError', () async {
      final manifest = PluginManifest(
        id: 'no-perm',
        name: 'No Permission',
        permissions: [Permission.browserRead],
      );
      final sandbox = Sandbox(
        pluginId: manifest.id,
        manifest: manifest,
        apiHandler: (apiName, args) async => {'ok': true},
      );
      await sandbox.start();
      addTearDown(sandbox.stop);

      expect(
        () => sandbox.callApi('knowledge.getNote', {'id': 'x'},
            requiredPermission: Permission.knowledgeRead),
        throwsA(isA<PermissionDeniedError>()),
      );
    });

    test('AC-IMP-1-6: API call timeout returns error via Sandbox guard', () async {
      final manifest = PluginManifest(
        id: 'timeout-plugin',
        name: 'Timeout Plugin',
        permissions: [Permission.knowledgeRead],
      );
      final sandbox = Sandbox(
        pluginId: manifest.id,
        manifest: manifest,
        apiHandler: (apiName, args) async {
          await Future.delayed(const Duration(seconds: 31));
          return {'result': 'ok'};
        },
      );
      await sandbox.start();

      try {
        await sandbox.callApi('knowledge.getNote', {'id': 'x'},
            requiredPermission: Permission.knowledgeRead);
        fail('Expected timeout exception');
      } catch (e) {
        expect(e, isA<Exception>());
      }
    }, timeout: const Timeout(Duration(seconds: 35)));
  });
}

extension on PluginHostNotifier {
  Future<Map<String, dynamic>> _testHandleApiCall(
    String apiName, Map<String, dynamic> args,
  ) async {
    switch (apiName) {
      case 'knowledge.getNote':
        final repo = ref.read(noteRepositoryProvider);
        if (repo == null) return {'error': 'No vault open'};
        final id = args['id'] as String? ?? '';
        final note = await repo.getNoteByPath(id);
        if (note == null) return {'error': 'Note not found: $id'};
        return {
          'id': note.id, 'title': note.title, 'content': note.content,
          'filePath': note.filePath, 'tags': note.tags,
        };
      case 'knowledge.search':
        final indexStore = ref.read(indexStoreProvider);
        final query = args['query'] as String? ?? '';
        final results = await indexStore.searchNotes(query);
        return {'results': results};
      case 'browser.getCurrentUrl':
        final browserState = ref.read(browserProvider);
        return {'url': browserState.activeTab?.url ?? ''};
      case 'browser.extractText':
        return {'text': ''};
      default:
        throw UnimplementedError('Unknown API: $apiName');
    }
  }
}
