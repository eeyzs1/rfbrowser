import 'dart:io';

/// G14-B: result of a 3-way merge attempt between [ours], [theirs] and
/// [base]. Conflict regions are surfaced as a [MergeConflict] so the caller
/// can prompt the user for a resolution.
class MergeResult {
  /// The merged text. Contains <<<<<<< / ======= / >>>>>>> markers in any
  /// region that could not be resolved automatically.
  final String text;

  /// True iff [text] contains unresolved conflict markers. Callers should
  /// inspect [conflicts] and decide whether to surface them or to perform
  /// an automated resolution (e.g. "keep ours").
  final bool hasConflicts;

  /// Per-region conflict records. Empty when [hasConflicts] is false.
  final List<MergeConflict> conflicts;

  const MergeResult({
    required this.text,
    required this.hasConflicts,
    this.conflicts = const [],
  });
}

/// A single conflict region inside a 3-way merge.
class MergeConflict {
  /// Start line (inclusive, 0-based).
  final int startLine;

  /// End line (inclusive, 0-based).
  final int endLine;

  /// The "ours" / local side of the conflict.
  final String oursText;

  /// The "theirs" / remote side of the conflict.
  final String theirsText;

  /// The common ancestor text (may be empty if the file was newly added).
  final String baseText;

  const MergeConflict({
    required this.startLine,
    required this.endLine,
    required this.oursText,
    required this.theirsText,
    required this.baseText,
  });
}

/// Resolution strategy used when [GitMerger.mergeWithConflict] encounters
/// regions where both sides changed in incompatible ways.
enum MergeResolution {
  /// Surround the region with standard git conflict markers
  /// (`<<<<<<<`, `=======`, `>>>>>>>`) and surface it to the caller.
  keepBoth,

  /// Keep the local ("ours") version of the region.
  keepOurs,

  /// Keep the remote ("theirs") version of the region.
  keepTheirs,

  /// Concatenate ours + separator + theirs (rarely useful but allowed).
  concatenate,
}

/// Git-style 3-way textual merger.
///
/// Minimal implementation: line-level diff via LCS DP, then diff3-style walk.
/// Sufficient for Markdown note sync; not a full git reimplementation.
class GitMerger {
  /// Performs the 3-way merge and returns the merged text.
  static MergeResult mergeWithConflict({
    required String ours,
    required String theirs,
    required String base,
    MergeResolution resolution = MergeResolution.keepBoth,
  }) {
    final oursHunks = _diff(base, ours)
        .map(
          (h) => _Hunk(
            baseStart: h.baseStart,
            baseLen: h.baseLen,
            replStart: h.replStart,
            replLen: h.replLen,
            fromOurs: true,
          ),
        )
        .toList();
    final theirsHunks = _diff(base, theirs)
        .map(
          (h) => _Hunk(
            baseStart: h.baseStart,
            baseLen: h.baseLen,
            replStart: h.replStart,
            replLen: h.replLen,
            fromOurs: false,
          ),
        )
        .toList();

    final oursQueue = List<_Hunk>.from(oursHunks)..sort();
    final theirsQueue = List<_Hunk>.from(theirsHunks)..sort();

    final oursLines = ours.split('\n');
    final theirsLines = theirs.split('\n');
    final baseLines = base.split('\n');

    final out = <String>[];
    final conflicts = <MergeConflict>[];
    var baseCursor = 0;
    var hasConflict = false;

    while (oursQueue.isNotEmpty || theirsQueue.isNotEmpty) {
      _Hunk? pickOurs = oursQueue.isNotEmpty ? oursQueue.first : null;
      _Hunk? pickTheirs = theirsQueue.isNotEmpty ? theirsQueue.first : null;

      _Hunk pick;
      if (pickOurs == null) {
        pick = pickTheirs!;
        theirsQueue.removeAt(0);
      } else if (pickTheirs == null) {
        pick = pickOurs;
        oursQueue.removeAt(0);
      } else if (pickOurs.baseStart <= pickTheirs.baseStart) {
        pick = pickOurs;
        oursQueue.removeAt(0);
      } else {
        pick = pickTheirs;
        theirsQueue.removeAt(0);
      }

      // Emit unchanged base lines up to pick.baseStart.
      while (baseCursor < pick.baseStart && baseCursor < baseLines.length) {
        out.add(baseLines[baseCursor]);
        baseCursor++;
      }

      // Look for a competing hunk from the other queue at the same base range.
      _Hunk? other;
      if (pickOurs != null &&
          pickTheirs != null &&
          pickOurs.baseStart == pick.baseStart &&
          pickTheirs.baseStart == pick.baseStart) {
        // We already dequeued ours above; pull theirs as the "other".
        other = pickTheirs;
        theirsQueue.removeAt(0);
      } else if (pick == pickOurs &&
          pickTheirs != null &&
          pickTheirs.baseStart == pick.baseStart) {
        other = pickTheirs;
        theirsQueue.removeAt(0);
      } else if (pick == pickTheirs &&
          pickOurs != null &&
          pickOurs.baseStart == pick.baseStart) {
        other = pickOurs;
        oursQueue.removeAt(0);
      }

      if (other == null) {
        // No competing hunk → take the chosen side's replacement.
        if (pick.replLen > 0) {
          final source = pick.fromOurs ? oursLines : theirsLines;
          out.addAll(
            source.sublist(pick.replStart, pick.replStart + pick.replLen),
          );
        }
        // Pure deletion (replLen == 0) → don't emit anything; the missing
        // base lines are simply skipped below.
        baseCursor += pick.baseLen;
        continue;
      }

      // Two competing hunks on the same base range.
      final oursText = oursLines
          .sublist(pick.replStart, pick.replStart + pick.replLen)
          .join('\n');
      final theirsText = theirsLines
          .sublist(other.replStart, other.replStart + other.replLen)
          .join('\n');
      final baseText = baseLines
          .sublist(pick.baseStart, pick.baseStart + pick.baseLen)
          .join('\n');

      if (oursText == theirsText) {
        // Both sides made the same change.
        if (oursText.isNotEmpty) {
          out.addAll(oursText.split('\n'));
        }
        baseCursor += pick.baseLen;
        continue;
      }
      if (oursText == baseText && theirsText != baseText) {
        // Only remote changed.
        if (theirsText.isNotEmpty) {
          out.addAll(theirsText.split('\n'));
        }
        baseCursor += pick.baseLen;
        continue;
      }
      if (theirsText == baseText && oursText != baseText) {
        // Only local changed.
        if (oursText.isNotEmpty) {
          out.addAll(oursText.split('\n'));
        }
        baseCursor += pick.baseLen;
        continue;
      }

      // Genuine conflict.
      switch (resolution) {
        case MergeResolution.keepBoth:
          out.add('<<<<<<< OURS');
          out.add(oursText);
          out.add('=======');
          out.add(theirsText);
          out.add('>>>>>>> THEIRS');
          hasConflict = true;
          break;
        case MergeResolution.keepOurs:
          out.addAll(oursText.split('\n'));
          break;
        case MergeResolution.keepTheirs:
          out.addAll(theirsText.split('\n'));
          break;
        case MergeResolution.concatenate:
          out.add(oursText);
          out.add('---');
          out.add(theirsText);
          break;
      }
      conflicts.add(
        MergeConflict(
          startLine: out.length - 1,
          endLine: out.length - 1,
          oursText: oursText,
          theirsText: theirsText,
          baseText: baseText,
        ),
      );
      baseCursor += pick.baseLen;
    }

    // Tail of base.
    while (baseCursor < baseLines.length) {
      out.add(baseLines[baseCursor]);
      baseCursor++;
    }

    return MergeResult(
      text: out.join('\n'),
      hasConflicts: hasConflict,
      conflicts: conflicts,
    );
  }

  /// High-level helper: read two files + base from disk, write the merge to
  /// [outPath]. Returns the [MergeResult].
  static Future<MergeResult> mergeFiles({
    required String basePath,
    required String oursPath,
    required String theirsPath,
    required String outPath,
    MergeResolution resolution = MergeResolution.keepBoth,
  }) async {
    final base = await _readIfExists(basePath);
    final ours = await _readIfExists(oursPath);
    final theirs = await _readIfExists(theirsPath);

    final result = mergeWithConflict(
      ours: ours,
      theirs: theirs,
      base: base,
      resolution: resolution,
    );

    await File(outPath).writeAsString(result.text);
    return result;
  }

  static Future<String> _readIfExists(String path) async {
    final f = File(path);
    if (!await f.exists()) return '';
    return f.readAsString();
  }

  /// Line-level LCS diff producing a list of replace-hunks.
  static List<_Hunk> _diff(String base, String modified) {
    final a = base.split('\n');
    final b = modified.split('\n');
    final n = a.length;
    final m = b.length;

    // Standard LCS DP, table of longest-common-subsequence lengths.
    final dp = List.generate(
      n + 1,
      (_) => List<int>.filled(m + 1, 0),
      growable: false,
    );
    for (var i = n - 1; i >= 0; i--) {
      for (var j = m - 1; j >= 0; j--) {
        if (a[i] == b[j]) {
          dp[i][j] = dp[i + 1][j + 1] + 1;
        } else if (dp[i + 1][j] >= dp[i][j + 1]) {
          dp[i][j] = dp[i + 1][j];
        } else {
          dp[i][j] = dp[i][j + 1];
        }
      }
    }

    // Walk to produce a sequence of operations.
    final ops = <_DiffOp>[];
    var i = 0;
    var j = 0;
    while (i < n && j < m) {
      if (a[i] == b[j]) {
        ops.add(_DiffOp.keep(i, j));
        i++;
        j++;
      } else if (dp[i + 1][j] >= dp[i][j + 1]) {
        ops.add(_DiffOp.delete(i, j));
        i++;
      } else {
        ops.add(_DiffOp.insert(i, j));
        j++;
      }
    }
    while (i < n) {
      ops.add(_DiffOp.delete(i, j));
      i++;
    }
    while (j < m) {
      ops.add(_DiffOp.insert(i, j));
      j++;
    }

    // Coalesce consecutive deletes+inserts into single replace hunks.
    final hunks = <_Hunk>[];
    var k = 0;
    while (k < ops.length) {
      final op = ops[k];
      if (op.kind == _DiffOpKind.keep) {
        k++;
        continue;
      }
      final baseStart = op.baseIdx;
      final replStart = op.modIdx;
      var baseLen = 0;
      var replLen = 0;
      while (k < ops.length && ops[k].kind == _DiffOpKind.delete) {
        baseLen++;
        k++;
      }
      while (k < ops.length && ops[k].kind == _DiffOpKind.insert) {
        replLen++;
        k++;
      }
      hunks.add(
        _Hunk(
          baseStart: baseStart,
          baseLen: baseLen,
          replStart: replStart,
          replLen: replLen,
          fromOurs: false,
        ),
      );
    }
    return hunks;
  }
}

class _Hunk implements Comparable<_Hunk> {
  final int baseStart;
  final int baseLen;
  final int replStart;
  final int replLen;
  final bool fromOurs;

  const _Hunk({
    required this.baseStart,
    required this.baseLen,
    required this.replStart,
    required this.replLen,
    required this.fromOurs,
  });

  @override
  int compareTo(_Hunk other) => baseStart.compareTo(other.baseStart);
}

enum _DiffOpKind { keep, delete, insert }

class _DiffOp {
  final _DiffOpKind kind;
  final int baseIdx;
  final int modIdx;
  const _DiffOp.keep(this.baseIdx, this.modIdx) : kind = _DiffOpKind.keep;
  const _DiffOp.delete(this.baseIdx, this.modIdx) : kind = _DiffOpKind.delete;
  const _DiffOp.insert(this.baseIdx, this.modIdx) : kind = _DiffOpKind.insert;
}
