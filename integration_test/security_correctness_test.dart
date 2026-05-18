import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rfbrowser/data/models/browser_tab.dart';
import 'package:rfbrowser/data/repositories/note_repository.dart';
import 'package:rfbrowser/l10n/app_localizations.dart';
import 'package:rfbrowser/platform/webview/agent_webview.dart';
import 'package:rfbrowser/platform/webview/headless_manager.dart';
import 'package:rfbrowser/services/browser_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('C-6: Bookmark Folder Cycle Detection', () {
    late BrowserNotifier browserNotifier;

    Future<void> pumpBrowserHarness(WidgetTester tester) async {
      browserNotifier = _TestBrowserNotifier();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            browserProvider.overrideWith(() => browserNotifier),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: SizedBox.shrink()),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('root folder has empty parentId (C-6)', (tester) async {
      await pumpBrowserHarness(tester);

      final root = BookmarkFolder(id: 'bookmarks-bar', name: 'Bookmarks');
      expect(root.parentId, isEmpty);
    });

    testWidgets('fromJson forces root parentId to empty (C-6)', (tester) async {
      await pumpBrowserHarness(tester);

      final json = {
        'id': 'bookmarks-bar',
        'name': 'Bookmarks',
        'parentId': 'bookmarks-bar',
        'isExpanded': true,
      };
      final folder = BookmarkFolder.fromJson(json);
      expect(folder.parentId, isEmpty);
    });

    testWidgets('createBookmarkFolder prevents self-referencing (C-6)', (tester) async {
      await pumpBrowserHarness(tester);

      final folderId = browserNotifier.createBookmarkFolder('Test');
      final folder = browserNotifier.state.bookmarkFolders.firstWhere(
        (f) => f.id == folderId,
      );
      expect(folder.parentId, isNot(equals(folderId)));
    });

    testWidgets('deleteBookmarkFolder handles cycles safely (C-6)', (tester) async {
      await pumpBrowserHarness(tester);

      final folderId1 = browserNotifier.createBookmarkFolder('Folder1');
      browserNotifier.createBookmarkFolder('Folder2');

      expect(browserNotifier.state.bookmarkFolders.length, equals(2));

      browserNotifier.deleteBookmarkFolder(folderId1);
      await tester.pumpAndSettle();

      expect(
        browserNotifier.state.bookmarkFolders.length,
        equals(1),
        reason: 'Should delete one folder without infinite loop',
      );
    });
  });

  group('S-1: WebView URL Filtering (Whitelist)', () {
    group('AgentWebView whitelist approach', () {
      late AgentWebView agentWebView;

      setUp(() {
        final headless = HeadlessWebView(id: 'test-hwv');
        agentWebView = AgentWebView(headless);
      });

      test('blocks javascript: scheme', () {
        expect(agentWebView.shouldOverrideUrlLoading('javascript:alert(1)'), isTrue);
      });

      test('blocks file: scheme', () {
        expect(agentWebView.shouldOverrideUrlLoading('file:///etc/passwd'), isTrue);
      });

      test('blocks data: scheme', () {
        expect(
          agentWebView.shouldOverrideUrlLoading('data:text/html,<script>alert(1)</script>'),
          isTrue,
        );
      });

      test('blocks ftp: scheme', () {
        expect(agentWebView.shouldOverrideUrlLoading('ftp://malicious.com/file'), isTrue);
      });

      test('blocks chrome: scheme', () {
        expect(agentWebView.shouldOverrideUrlLoading('chrome://settings'), isTrue);
      });

      test('blocks vbscript: scheme', () {
        expect(agentWebView.shouldOverrideUrlLoading('vbscript:msgbox("hi")'), isTrue);
      });

      test('allows http: scheme', () {
        expect(agentWebView.shouldOverrideUrlLoading('http://example.com'), isFalse);
      });

      test('allows https: scheme', () {
        expect(agentWebView.shouldOverrideUrlLoading('https://secure.example.com'), isFalse);
      });

      test('allows about:blank', () {
        expect(agentWebView.shouldOverrideUrlLoading('about:blank'), isFalse);
      });

      test('blocks malformed URLs', () {
        expect(agentWebView.shouldOverrideUrlLoading(''), isTrue);
        expect(agentWebView.shouldOverrideUrlLoading('not-a-url'), isTrue);
      });
    });

    group('HeadlessWebView whitelist approach', () {
      test('loadUrl blocks non-HTTP schemes', () async {
        final webView = HeadlessWebView(id: 'test-s1');
        await webView.run();

        expect(() => webView.loadUrl('javascript:alert(1)'), throwsArgumentError);
        expect(() => webView.loadUrl('file:///etc/passwd'), throwsArgumentError);
        expect(() => webView.loadUrl('data:text/html,test'), throwsArgumentError);
      });

      test('loadUrl allows HTTP schemes', () async {
        final webView = HeadlessWebView(id: 'test-s2');
        await webView.run();

        await webView.loadUrl('https://example.com');
        expect(webView.currentUrl, 'https://example.com');
      });
    });
  });

  group('S-3: Path Traversal Prevention', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('rfbrowser_s3_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    group('NoteRepository path validation', () {
      test('_normalizeRelativePath rejects .. paths', () {
        final repo = NoteRepository(tempDir.path);
        expect(
          () => repo.normalizeRelativePath('../../etc/passwd'),
          throwsA(isA<PathTraversalException>()),
        );
      });

      test('_normalizeRelativePath rejects absolute paths', () {
        final repo = NoteRepository(tempDir.path);
        expect(
          () => repo.normalizeRelativePath('/etc/passwd'),
          throwsA(isA<PathTraversalException>()),
        );
      });

      test('_normalizeRelativePath accepts valid relative paths', () {
        final repo = NoteRepository(tempDir.path);
        final result = repo.normalizeRelativePath('notes/my-note.md');
        expect(result, isNot(contains('..')));
      });

      test('_validatePath rejects traversal via embedded ..', () {
        final repo = NoteRepository(tempDir.path);
        expect(
          () => repo.validatePath('foo/../../etc/passwd'),
          throwsA(isA<PathTraversalException>()),
        );
      });
    });

    group('NoteRepository _sanitizeFileName', () {
      test('strips directory components from filename', () {
        final repo = NoteRepository(tempDir.path);
        final result = repo.sanitizeFileName('../../../etc/passwd');
        expect(result, equals('passwd'));
      });

      test('replaces invalid characters', () {
        final repo = NoteRepository(tempDir.path);
        final result = repo.sanitizeFileName('my<note>file.md');
        expect(result, equals('my_note_file.md'));
      });

      test('handles empty result as untitled', () {
        final repo = NoteRepository(tempDir.path);
        final result = repo.sanitizeFileName('...');
        expect(result, equals('untitled'));
      });

      test('truncates long filenames to 100 chars', () {
        final repo = NoteRepository(tempDir.path);
        final longName = 'a' * 200;
        final result = repo.sanitizeFileName(longName);
        expect(result.length, equals(100));
      });
    });
  });
}

class _TestBrowserNotifier extends BrowserNotifier {
  @override
  BrowserState build() => BrowserState();
}
