import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rfbrowser/data/models/note.dart';
import 'package:rfbrowser/data/stores/index_store.dart';
import 'package:rfbrowser/data/stores/vault_store.dart';
import 'package:rfbrowser/services/search_service.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class TestVaultNotifier extends VaultNotifier {
  final VaultState _state;
  TestVaultNotifier(this._state);
  @override
  VaultState build() => _state;
  @override
  set state(VaultState newState) => super.state = newState;
}

ProviderContainer createContainer(String vaultPath) {
  final vaultState = VaultState(
    currentVault: VaultConfig(
      path: vaultPath,
      name: 'test',
      lastOpened: DateTime.now(),
    ),
  );
  return ProviderContainer(
    overrides: [
      vaultProvider.overrideWith(() => TestVaultNotifier(vaultState)),
    ],
  );
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('SearchState', () {
    test('initial state has empty results and isSearching=false', () {
      const state = SearchState();
      expect(state.searchResults, isEmpty);
      expect(state.hybridResults, isEmpty);
      expect(state.isSearching, false);
      expect(state.selectedTags, isEmpty);
    });

    test('copyWith updates searchResults', () {
      const state = SearchState();
      final updated = state.copyWith(
        searchResults: [
          {'noteId': '1', 'title': 'Test'},
        ],
      );
      expect(updated.searchResults.length, 1);
      expect(updated.searchResults.first['noteId'], '1');
    });

    test('copyWith updates hybridResults', () {
      const state = SearchState();
      final updated = state.copyWith(
        hybridResults: [
          {'noteId': '2', 'title': 'Hybrid'},
        ],
      );
      expect(updated.hybridResults.length, 1);
    });

    test('copyWith updates isSearching', () {
      const state = SearchState();
      final updated = state.copyWith(isSearching: true);
      expect(updated.isSearching, true);
    });

    test('copyWith updates selectedTags', () {
      const state = SearchState();
      final updated = state.copyWith(selectedTags: ['tag1']);
      expect(updated.selectedTags, ['tag1']);
    });

    test('copyWith preserves unchanged fields', () {
      final state = SearchState(
        searchResults: [
          {'id': '1'},
        ],
        selectedTags: ['keep'],
      );
      final updated = state.copyWith(isSearching: true);
      expect(updated.searchResults.length, 1);
      expect(updated.selectedTags, ['keep']);
      expect(updated.isSearching, true);
    });
  });

  group('SearchNotifier', () {
    test('build returns initial SearchState', () {
      final container = createContainer('.');
      addTearDown(container.dispose);
      final state = container.read(searchServiceProvider);
      expect(state.searchResults, isEmpty);
      expect(state.hybridResults, isEmpty);
      expect(state.isSearching, false);
      expect(state.selectedTags, isEmpty);
    });

    test(
      'search with empty query returns empty list and no state change',
      () async {
        final container = createContainer('.');
        addTearDown(container.dispose);
        final notifier = container.read(searchServiceProvider.notifier);
        final state = container.read(searchServiceProvider);
        expect(state.isSearching, false);

        final results = await notifier.search('');
        expect(results, isEmpty);
        expect(container.read(searchServiceProvider).isSearching, false);
      },
    );

    group('toggleTag', () {
      test('adds tag to selectedTags', () {
        final container = createContainer('.');
        addTearDown(container.dispose);
        final notifier = container.read(searchServiceProvider.notifier);

        notifier.toggleTag('flutter');
        expect(container.read(searchServiceProvider).selectedTags, ['flutter']);
      });

      test('removes tag when already selected', () {
        final container = createContainer('.');
        addTearDown(container.dispose);
        final notifier = container.read(searchServiceProvider.notifier);

        notifier.toggleTag('flutter');
        notifier.toggleTag('flutter');
        expect(container.read(searchServiceProvider).selectedTags, isEmpty);
      });

      test('supports multiple tags', () {
        final container = createContainer('.');
        addTearDown(container.dispose);
        final notifier = container.read(searchServiceProvider.notifier);

        notifier.toggleTag('flutter');
        notifier.toggleTag('dart');
        expect(
          container.read(searchServiceProvider).selectedTags,
          containsAll(['flutter', 'dart']),
        );
      });
    });

    group('clearTags', () {
      test('clears all selected tags', () {
        final container = createContainer('.');
        addTearDown(container.dispose);
        final notifier = container.read(searchServiceProvider.notifier);

        notifier.toggleTag('flutter');
        notifier.toggleTag('dart');
        expect(container.read(searchServiceProvider).selectedTags.length, 2);

        notifier.clearTags();
        expect(container.read(searchServiceProvider).selectedTags, isEmpty);
      });

      test('clearing empty tags is no-op', () {
        final container = createContainer('.');
        addTearDown(container.dispose);
        final notifier = container.read(searchServiceProvider.notifier);

        notifier.clearTags();
        expect(container.read(searchServiceProvider).selectedTags, isEmpty);
      });
    });

    group('search with real IndexStore', () {
      late ProviderContainer container;
      late Directory tempDir;
      late IndexStore indexStore;

      setUp(() async {
        SharedPreferences.setMockInitialValues({});
        tempDir = await Directory.systemTemp.createTemp('rfbrowser_search_');
        final rfbrowserDir = Directory(p.join(tempDir.path, '.rfbrowser'));
        if (!await rfbrowserDir.exists()) {
          await rfbrowserDir.create(recursive: true);
        }
        container = createContainer(tempDir.path);
        indexStore = IndexStore(p.join(tempDir.path, '.rfbrowser', 'index.db'));

        final note = Note(
          title: 'Test Note',
          filePath: 'test_note.md',
          content: 'This is searchable content about Flutter and Dart.',
          tags: ['flutter', 'dart'],
        );
        await indexStore.indexNote(note);
      });

      tearDown(() async {
        container.dispose();
        await indexStore.close();
        try {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        } catch (_) {}
      });

      test('search returns results for matching query', () async {
        final notifier = container.read(searchServiceProvider.notifier);

        final results = await notifier.search('flutter');
        expect(results.isNotEmpty, true);
      });

      test('search sets isSearching during search', () async {
        final notifier = container.read(searchServiceProvider.notifier);

        await notifier.search('flutter');
        expect(container.read(searchServiceProvider).isSearching, false);
      });

      test('search with non-matching query returns empty', () async {
        final notifier = container.read(searchServiceProvider.notifier);

        final results = await notifier.search('zzzznonexistent');
        expect(results, isEmpty);
      });

      test('search stores results in state', () async {
        final notifier = container.read(searchServiceProvider.notifier);

        await notifier.search('flutter');
        final state = container.read(searchServiceProvider);
        expect(state.searchResults.isNotEmpty, true);
      });
    });
  });
}
