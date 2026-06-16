import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/services/git_merge.dart';

void main() {
  group('GitMerger.mergeWithConflict (G14-B)', () {
    test('no changes → identical output', () {
      const text = 'line1\nline2\nline3';
      final r = GitMerger.mergeWithConflict(
        ours: text,
        theirs: text,
        base: text,
      );
      expect(r.hasConflicts, isFalse);
      expect(r.text, text);
    });

    test('local-only edit is taken', () {
      const base = 'a\nb\nc\nd';
      const ours = 'a\nb\nB-local\nc\nd';
      final r = GitMerger.mergeWithConflict(
        ours: ours,
        theirs: base,
        base: base,
      );
      expect(r.hasConflicts, isFalse);
      expect(r.text, ours);
    });

    test('remote-only edit is taken', () {
      const base = 'a\nb\nc\nd';
      const theirs = 'a\nb\nB-remote\nc\nd';
      final r = GitMerger.mergeWithConflict(
        ours: base,
        theirs: theirs,
        base: base,
      );
      expect(r.hasConflicts, isFalse);
      expect(r.text, theirs);
    });

    test('identical edits on both sides → no conflict', () {
      const base = 'a\nb\nc';
      const both = 'a\nB\nc';
      final r = GitMerger.mergeWithConflict(
        ours: both,
        theirs: both,
        base: base,
      );
      expect(r.hasConflicts, isFalse);
      expect(r.text, both);
    });

    test('conflicting edits surface as git markers (default resolution)', () {
      const base = 'a\nb\nc';
      const ours = 'a\nB-ours\nc';
      const theirs = 'a\nB-theirs\nc';
      final r = GitMerger.mergeWithConflict(
        ours: ours,
        theirs: theirs,
        base: base,
      );
      expect(r.hasConflicts, isTrue);
      expect(r.text, contains('<<<<<<< OURS'));
      expect(r.text, contains('======='));
      expect(r.text, contains('>>>>>>> THEIRS'));
      expect(r.text, contains('B-ours'));
      expect(r.text, contains('B-theirs'));
      expect(r.conflicts.length, 1);
    });

    test('keepOurs resolution prefers local version', () {
      const base = 'a\nb\nc';
      const ours = 'a\nB-ours\nc';
      const theirs = 'a\nB-theirs\nc';
      final r = GitMerger.mergeWithConflict(
        ours: ours,
        theirs: theirs,
        base: base,
        resolution: MergeResolution.keepOurs,
      );
      expect(r.hasConflicts, isFalse);
      expect(r.text, contains('B-ours'));
      expect(r.text, isNot(contains('B-theirs')));
    });

    test('keepTheirs resolution prefers remote version', () {
      const base = 'a\nb\nc';
      const ours = 'a\nB-ours\nc';
      const theirs = 'a\nB-theirs\nc';
      final r = GitMerger.mergeWithConflict(
        ours: ours,
        theirs: theirs,
        base: base,
        resolution: MergeResolution.keepTheirs,
      );
      expect(r.hasConflicts, isFalse);
      expect(r.text, contains('B-theirs'));
      expect(r.text, isNot(contains('B-ours')));
    });

    test('addition on both sides of different locations → no conflict', () {
      const base = 'a\nb\nc';
      const ours = 'a\nb\nc\nd-ours';
      const theirs = 'a\nA-theirs\nb\nc';
      final r = GitMerger.mergeWithConflict(
        ours: ours,
        theirs: theirs,
        base: base,
      );
      expect(r.hasConflicts, isFalse);
      expect(r.text, contains('d-ours'));
      expect(r.text, contains('A-theirs'));
    });

    test('deletion on both sides of the same line → no conflict', () {
      const base = 'a\nb\nc';
      const ours = 'a\nc';
      const theirs = 'a\nc';
      final r = GitMerger.mergeWithConflict(
        ours: ours,
        theirs: theirs,
        base: base,
      );
      expect(r.hasConflicts, isFalse);
      expect(r.text, 'a\nc');
    });
  });

  group('GitMerger.mergeFiles (G14-B)', () {
    test('reads three files, writes merged output, returns result', () async {
      final temp = Directory.systemTemp.createTempSync('rfb_merge_');
      addTearDown(() {
        try {
          temp.deleteSync(recursive: true);
        } catch (_) {}
      });
      final base = File('${temp.path}/base.md')
        ..writeAsStringSync('hello\nworld');
      final ours = File('${temp.path}/ours.md')
        ..writeAsStringSync('hello\nWORLD-local');
      final theirs = File('${temp.path}/theirs.md')
        ..writeAsStringSync('hello\nWORLD-remote');
      final out = File('${temp.path}/merged.md');

      final result = await GitMerger.mergeFiles(
        basePath: base.path,
        oursPath: ours.path,
        theirsPath: theirs.path,
        outPath: out.path,
      );

      expect(await out.exists(), isTrue);
      expect(result.hasConflicts, isTrue);
      expect(await out.readAsString(), contains('WORLD-local'));
      expect(await out.readAsString(), contains('WORLD-remote'));
    });

    test('handles missing base file gracefully', () async {
      final temp = Directory.systemTemp.createTempSync('rfb_merge2_');
      addTearDown(() {
        try {
          temp.deleteSync(recursive: true);
        } catch (_) {}
      });
      // No base file. ours + theirs only.
      final ours = File('${temp.path}/ours.md')..writeAsStringSync('a\nb\nc');
      final theirs = File('${temp.path}/theirs.md')
        ..writeAsStringSync('a\nB\nc');
      final out = File('${temp.path}/merged.md');

      final result = await GitMerger.mergeFiles(
        basePath: '${temp.path}/missing.md',
        oursPath: ours.path,
        theirsPath: theirs.path,
        outPath: out.path,
        resolution: MergeResolution.keepOurs,
      );
      expect(result.text, contains('b'));
      expect(await out.exists(), isTrue);
    });
  });
}
