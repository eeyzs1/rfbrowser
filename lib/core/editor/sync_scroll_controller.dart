import 'package:flutter/material.dart';

class ScrollPositionMapping {
  final int editorLine;
  final int previewHeadingIndex;

  ScrollPositionMapping({
    required this.editorLine,
    required this.previewHeadingIndex,
  });
}

class SyncScrollController {
  final ScrollController editorController;
  final ScrollController previewController;

  bool _syncing = false;
  List<int> _headingLineNumbers = [];

  SyncScrollController({
    required this.editorController,
    required this.previewController,
  });

  void attach() {
    editorController.addListener(_onEditorScroll);
    previewController.addListener(_onPreviewScroll);
  }

  void detach() {
    editorController.removeListener(_onEditorScroll);
    previewController.removeListener(_onPreviewScroll);
  }

  void updateHeadingPositions(List<int> headingLineNumbers, List<double> previewHeadingOffsets) {
    _headingLineNumbers = headingLineNumbers;
  }

  int findPreviewHeadingForLine(int line) {
    if (_headingLineNumbers.isEmpty) return 0;
    int result = 0;
    for (int i = 0; i < _headingLineNumbers.length; i++) {
      if (_headingLineNumbers[i] <= line) {
        result = i;
      } else {
        break;
      }
    }
    return result;
  }

  int findEditorLineForPreviewHeading(int headingIndex) {
    if (_headingLineNumbers.isEmpty) return 0;
    if (headingIndex >= _headingLineNumbers.length) {
      return _headingLineNumbers.last;
    }
    return _headingLineNumbers[headingIndex];
  }

  void _onEditorScroll() {
    if (_syncing) return;
    if (!editorController.hasClients || !previewController.hasClients) return;

    _syncing = true;
    try {
      final editorOffset = editorController.offset;
      final editorMax = editorController.position.maxScrollExtent;
      if (editorMax <= 0) return;

      final ratio = editorOffset / editorMax;
      final previewMax = previewController.position.maxScrollExtent;
      final targetOffset = ratio * previewMax;

      previewController.jumpTo(
        targetOffset.clamp(0, previewMax),
      );
    } finally {
      _syncing = false;
    }
  }

  void _onPreviewScroll() {
    if (_syncing) return;
    if (!editorController.hasClients || !previewController.hasClients) return;

    _syncing = true;
    try {
      final previewOffset = previewController.offset;
      final previewMax = previewController.position.maxScrollExtent;
      if (previewMax <= 0) return;

      final ratio = previewOffset / previewMax;
      final editorMax = editorController.position.maxScrollExtent;
      final targetOffset = ratio * editorMax;

      editorController.jumpTo(
        targetOffset.clamp(0, editorMax),
      );
    } finally {
      _syncing = false;
    }
  }

  List<int> extractHeadingLineNumbers(String text) {
    final lines = text.split('\n');
    final headingLines = <int>[];
    for (int i = 0; i < lines.length; i++) {
      if (RegExp(r'^#{1,6}\s+').hasMatch(lines[i])) {
        headingLines.add(i);
      }
    }
    return headingLines;
  }
}
